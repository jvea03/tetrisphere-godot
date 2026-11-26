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
# It can sit for ever on facebook-ios-sdk's zips once the checkouts are done, so
# it gets 5 minutes (perl's alarm: macOS has no timeout(1)).
( cd build/ios && perl -e 'alarm 300; exec @ARGV' xcodebuild -resolvePackageDependencies -project EggEscape.xcodeproj -scheme EggEscape >/dev/null 2>&1 ) || echo "  (resolver stopped; using the checkouts it made)"
SP=$(ls -d ~/Library/Developer/Xcode/DerivedData/EggEscape-*/SourcePackages | head -1)
CACHE=~/Library/Caches/org.swift.swiftpm/artifacts
mkdir -p "$CACHE"
for pkg in "$SP"/checkouts/*; do
	name=$(basename "$pkg")
	while IFS='|' read -r target url sum; do
		dest="$SP/artifacts/$name/$target"
		# SwiftPM's own download cache too (the URL with every other character
		# made "_"): the archive step downloads again unless the zip is there,
		# and xcodebuild's downloader stalls on GitHub release files (Meta's).
		cached="$CACHE/$(printf '%s' "$url" | sed 's/[^A-Za-z0-9]/_/g')"
		if [ -d "$dest/$target.xcframework" ] && [ -f "$cached" ]; then echo "  have $target"; continue; fi
		if [ ! -f "$cached" ] || [ "$(shasum -a 256 "$cached" | cut -d' ' -f1)" != "$sum" ]; then
			curl -fsSL -o "$cached.part" "$url"
			got=$(shasum -a 256 "$cached.part" | cut -d' ' -f1)
			[ "$got" = "$sum" ] || { echo "checksum mismatch for $target"; exit 1; }
			mv "$cached.part" "$cached"
		fi
		rm -rf "$dest" && mkdir -p "$dest" && unzip -q "$cached" -d "$dest"
		echo "  fetched $target"
	done < <(python3 tools/spm_binaries.py "$pkg/Package.swift")
done

# The team for every target, the Swift packages' resource bundles included
# (Firebase's GoogleUtilities, nanopb, Promises...): without it their signing
# fails with "requires a development team".
TEAM=$(sed -n 's/^application\/app_store_team_id="\(.*\)"/\1/p' export_presets.cfg | head -1)
echo "== archive =="
rm -rf build/EggEscape.xcarchive
( cd build/ios && xcodebuild -project EggEscape.xcodeproj -scheme EggEscape -configuration Release \
	-destination "generic/platform=iOS" -archivePath "$PWD/../EggEscape.xcarchive" \
	CODE_SIGN_IDENTITY="Apple Development" DEVELOPMENT_TEAM="$TEAM" -allowProvisioningUpdates "${AUTH[@]}" archive 2>&1 \
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
echo "Uploaded. Processing takes 5-15 min; then: tools/asc.py builds 6819941762"
