# The binaryTargets in a Swift package manifest, as name|url|checksum lines, for
# tools/ios-upload.sh (xcodebuild leaves their zips unfetched).
import re, sys
src = open(sys.argv[1]).read()
for m in re.finditer(r'binaryTarget\(\s*name:\s*"([^"]+)"\s*,\s*url:\s*"([^"]+)"\s*,\s*checksum:\s*"([^"]+)"', src, re.S):
    print("|".join(m.groups()))
# facebook-ios-sdk builds its URLs in code: binaryTarget(name: .Prefixed.core,
# remoteChecksum: "...") with the names in `enum Prefixed { static let core =
# "FBSDKCoreKit" }` and the URL from remoteBinaryURLString's "...\(targetName)...".
tpl = re.search(r'remoteBinaryURLString\(for targetName: String\) -> String \{\s*"([^"]+)"', src)
if tpl:
    names = dict(re.findall(r'static let (\w+) = "(FB\w+)"', src))
    for key, sum_ in re.findall(r'binaryTarget\(\s*name:\s*\.Prefixed\.(\w+)\s*,\s*remoteChecksum:\s*"([^"]+)"', src, re.S):
        if key in names:
            print("|".join([names[key], tpl.group(1).replace("\\(targetName)", names[key]), sum_]))
