#!/usr/bin/env bash
# Release export -> archive -> upload to App Store Connect, headless.
#
#   tools/ios-upload.sh
#
# Needs (set up for Duckdoku; Egg Escape still needs its own profile, see docs/ios.md):
#   - ~/.appstoreconnect/config.env + AuthKey_*.p8 (App Manager API key)
#   - "Apple Distribution: Jeffrey Vea" identity in the login keychain
#     (made with tools/asc.py-style CSR + POST /certificates; the API key
#     is not allowed to cloud-sign, so xcodebuild's automatic distribution
#     signing fails -- hence manual signing at export time)
#   - App Store profile "Egg Escape App Store" in
#     ~/Library/Developer/Xcode/UserData/Provisioning Profiles
# Bump application/version (the build number) in export_presets.cfg first;
# App Store Connect rejects a build number it has seen.
set -euo pipefail
cd "$(dirname "$0")/.."
source ~/.appstoreconnect/config.env
AUTH=(-authenticationKeyPath "$ASC_KEY_PATH" -authenticationKeyID "$ASC_KEY_ID" -authenticationKeyIssuerID "$ASC_ISSUER_ID")

echo "== export (release) =="
./tools/ios-setup.sh release | tail -2

# The Swift packages' binary zips (GoogleMobileAds, UMP) are only fetched by
# the Xcode GUI; xcodebuild's resolver leaves the artifact dirs empty. So:
# resolve the checkouts, then download each binaryTarget ourselves from the
# URL in its Package.swift and verify the manifest's checksum.
echo "== swift packages =="
( cd build/ios && xcodebuild -resolvePackageDependencies -project EggEscape.xcodeproj -scheme EggEscape >/dev/null 2>&1 )
SP=$(ls -d ~/Library/Developer/Xcode/DerivedData/EggEscape-*/SourcePackages | head -1)
for pkg in "$SP"/checkouts/*; do
	name=$(basename "$pkg")
	while IFS='|' read -r target url sum; do
		dest="$SP/artifacts/$name/$target"
		[ -d "$dest/$target.xcframework" ] && { echo "  have $target"; continue; }
		tmp=$(mktemp -d)
		curl -fsSL -o "$tmp/a.zip" "$url"
		got=$(shasum -a 256 "$tmp/a.zip" | cut -d' ' -f1)
		[ "$got" = "$sum" ] || { echo "checksum mismatch for $target"; exit 1; }
		mkdir -p "$dest" && unzip -q "$tmp/a.zip" -d "$dest" && rm -rf "$tmp"
		echo "  fetched $target"
	done < <(python3 - "$pkg/Package.swift" <<'PY'
import re, sys
src = open(sys.argv[1]).read()
for m in re.finditer(r'binaryTarget\(\s*name:\s*"([^"]+)"\s*,\s*url:\s*"([^"]+)"\s*,\s*checksum:\s*"([^"]+)"', src, re.S):
    print("|".join(m.groups()))
PY
)
done

echo "== archive =="
rm -rf build/EggEscape.xcarchive
( cd build/ios && xcodebuild -project EggEscape.xcodeproj -scheme EggEscape -configuration Release \
	-destination "generic/platform=iOS" -archivePath "$PWD/../EggEscape.xcarchive" \
	CODE_SIGN_IDENTITY="Apple Development" -allowProvisioningUpdates "${AUTH[@]}" archive 2>&1 \
	| grep -E "error:|ARCHIVE (SUCCEEDED|FAILED)" | grep -v DVTPlugIn | sort -u )

echo "== export + upload =="
cat > build/ExportOptions.plist <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
	<key>method</key><string>app-store-connect</string>
	<key>destination</key><string>upload</string>
	<key>teamID</key><string>75DDPXBG45</string>
	<key>signingStyle</key><string>manual</string>
	<key>signingCertificate</key><string>Apple Distribution</string>
	<key>provisioningProfiles</key><dict>
		<key>com.jvea.eggescape</key><string>Egg Escape App Store</string>
	</dict>
	<key>uploadSymbols</key><true/>
	<key>manageAppVersionAndBuildNumber</key><false/>
</dict></plist>
EOF
rm -rf build/ios-export
( cd build && xcodebuild -exportArchive -archivePath "$PWD/EggEscape.xcarchive" \
	-exportOptionsPlist ExportOptions.plist -exportPath "$PWD/ios-export" "${AUTH[@]}" 2>&1 \
	| grep -E "error|EXPORT (SUCCEEDED|FAILED)|is complete" | grep -v DVTPlugIn | sort -u )
echo "Uploaded. Processing takes 5-15 min; then: tools/asc.py builds <apple-id-of-the-app>"
