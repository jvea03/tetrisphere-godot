#!/usr/bin/env bash
# One-shot Mac setup for the iOS build. Idempotent: re-run after fixing
# whatever it complains about. Companion to docs/ios.md.
#
#   ./tools/ios-setup.sh          # everything; exports a DEBUG project (test ads)
#   ./tools/ios-setup.sh release  # same, but exports the RELEASE project (real ads)
#   ./tools/ios-setup.sh check    # only report what is missing
#
# What it does, in order (each step skips itself when already done):
#   1. Preflight: disk space, Xcode + its licence, Homebrew.
#   2. Godot editor (version pinned below) into ~/Applications, export
#      templates into ~/Library/Application Support/Godot/export_templates/.
#   3. Build the InAppStore plugin from godot-ios-plugins (no 4.x prebuilts
#      exist) and drop it into ios/plugins/ so the iOS preset can tick it.
#   4. Export the Xcode project to build/ios/ (headless).
#
# Things it will NOT do because they need your Apple ID or a password:
# install Xcode, sign in to a Team, archive/upload. Those are the "Xcode"
# steps in docs/ios.md.

set -euo pipefail

# Must match the AdMob addon's prebuilt iOS binary (addons/admob/downloads/ios/
# ios-template-v<ver>.zip) exactly, or the link fails on Godot-internal symbols.
GODOT_VER="4.7.2"
GODOT_TAG="${GODOT_VER}-stable"
GODOT_APP="$HOME/Applications/Godot.app"
GODOT_BIN="$GODOT_APP/Contents/MacOS/Godot"
TEMPLATES_DIR="$HOME/Library/Application Support/Godot/export_templates/${GODOT_VER}.stable"
PLUGINS_SRC="$HOME/src/godot-ios-plugins"
REPO="$(cd "$(dirname "$0")/.." && pwd)"
MODE="${1:-all}"

ok()   { printf '  \033[32m✔\033[0m %s\n' "$*"; }
warn() { printf '  \033[33m!\033[0m %s\n' "$*"; }
die()  { printf '  \033[31m✘\033[0m %s\n' "$*"; exit 1; }
step() { printf '\n\033[1m%s\033[0m\n' "$*"; }

# ---------------------------------------------------------------- 1. preflight
step "1. Preflight"

FREE_GB=$(df -g / | awk 'NR==2 {print $4}')
if [ "$FREE_GB" -lt 10 ]; then   # 25+ for a first Xcode install; an export and archive need a few GB
	warn "Only ${FREE_GB} GB free on /. Xcode needs ~40 GB to install and ~15 GB after;"
	warn "the plugin build needs another ~6 GB. Free space first (Storage settings)."
	[ "$MODE" = "check" ] || die "not enough disk space"
else
	ok "${FREE_GB} GB free"
fi

if [ -d /Applications/Xcode.app ] && xcode-select -p >/dev/null 2>&1; then
	ok "Xcode at $(xcode-select -p)"
	if ! xcodebuild -version >/dev/null 2>&1; then
		warn "Xcode licence not accepted -- run:  sudo xcodebuild -license accept"
		[ "$MODE" = "check" ] || die "accept the Xcode licence, then re-run"
	else
		ok "$(xcodebuild -version | head -1)"
	fi
	if [ "$(xcode-select -p)" = "/Library/Developer/CommandLineTools" ]; then
		warn "xcode-select points at Command Line Tools, not Xcode -- run:"
		warn "  sudo xcode-select --switch /Applications/Xcode.app"
		[ "$MODE" = "check" ] || die "point xcode-select at Xcode, then re-run"
	fi
	if ! xcodebuild -showsdks 2>/dev/null | grep -q iphoneos; then
		warn "iOS platform not installed -- Xcode > Settings > Components > iOS, or:"
		warn "  xcodebuild -downloadPlatform iOS"
		[ "$MODE" = "check" ] || die "install the iOS platform, then re-run"
	fi
else
	warn "Xcode is not installed. Install it from the Mac App Store (Apple ID needed),"
	warn "open it once, then:  sudo xcode-select --switch /Applications/Xcode.app"
	[ "$MODE" = "check" ] || die "install Xcode first"
fi

if command -v brew >/dev/null 2>&1; then
	ok "Homebrew $(brew --version | head -1 | awk '{print $2}')"
else
	warn "Homebrew missing -- needed for scons. Install (asks for your password):"
	warn '  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
	[ "$MODE" = "check" ] || die "install Homebrew first"
fi

# ------------------------------------------------------------ 2. godot editor
step "2. Godot ${GODOT_VER} editor + export templates"

if [ -x "$GODOT_BIN" ] && "$GODOT_BIN" --version 2>/dev/null | grep -q "^${GODOT_VER}\."; then
	ok "Godot $("$GODOT_BIN" --version 2>/dev/null) at $GODOT_APP"
elif [ "$MODE" = "check" ]; then
	warn "Godot ${GODOT_VER} not at $GODOT_APP"
else
	mkdir -p "$HOME/Applications"
	TMP=$(mktemp -d)
	echo "  downloading Godot ${GODOT_TAG} editor..."
	curl -fL --progress-bar -o "$TMP/godot.zip" \
		"https://github.com/godotengine/godot/releases/download/${GODOT_TAG}/Godot_v${GODOT_TAG}_macos.universal.zip"
	rm -rf "$GODOT_APP"
	unzip -q "$TMP/godot.zip" -d "$HOME/Applications"
	xattr -dr com.apple.quarantine "$GODOT_APP" || true
	rm -rf "$TMP"
	ok "installed $GODOT_APP"
fi

if [ -f "$TEMPLATES_DIR/ios.zip" ]; then
	ok "export templates at $TEMPLATES_DIR"
elif [ "$MODE" = "check" ]; then
	warn "export templates missing ($TEMPLATES_DIR)"
else
	TMP=$(mktemp -d)
	echo "  downloading export templates (~1 GB)..."
	curl -fL --progress-bar -o "$TMP/templates.tpz" \
		"https://github.com/godotengine/godot/releases/download/${GODOT_TAG}/Godot_v${GODOT_TAG}_export_templates.tpz"
	mkdir -p "$TEMPLATES_DIR"
	unzip -q -o "$TMP/templates.tpz" -d "$TMP/tpz"
	cp -R "$TMP/tpz/templates/." "$TEMPLATES_DIR/"
	rm -rf "$TMP"
	ok "installed export templates"
fi

# ----------------------------------------------------- 3. InAppStore plugin
step "3. InAppStore plugin (godot-ios-plugins, built for 4.x)"

PLUG_OUT="$REPO/ios/plugins"
if [ -f "$PLUG_OUT/inappstore.gdip" ] && [ -d "$PLUG_OUT/inappstore.release.xcframework" ]; then
	ok "plugin already in ios/plugins/"
elif [ "$MODE" = "check" ]; then
	warn "ios/plugins/inappstore.* missing (Billing will run in simulated mode)"
else
	command -v scons >/dev/null 2>&1 || brew install scons
	if [ ! -d "$PLUGINS_SRC/.git" ]; then
		mkdir -p "$(dirname "$PLUGINS_SRC")"
		git clone --recursive https://github.com/godot-sdk-integrations/godot-ios-plugins.git "$PLUGINS_SRC"
	fi
	cd "$PLUGINS_SRC/godot"
	git fetch --tags -q origin
	git checkout -q "$GODOT_TAG"
	cd "$PLUGINS_SRC"
	# Only the engine's generated headers are needed, and scons emits them in
	# its first seconds, so run it under upstream's 90 s timeout helper rather
	# than a full engine build. (Upstream's generate_headers.sh still passes
	# the 3.x target name "release_debug", which 4.x rejects -- hence inline.)
	if [ ! -f godot/core/version_generated.gen.h ]; then
		echo "  generating Godot ${GODOT_TAG} headers (~90 s)..."
		( cd godot && ../scripts/timeout scons platform=ios target=template_release arch=arm64 >/dev/null 2>&1 ) || true
		[ -f godot/core/version_generated.gen.h ] || die "header generation failed; run scons in $PLUGINS_SRC/godot by hand"
	fi
	mkdir -p bin # scons wants its output dir to already exist
	echo "  building inappstore xcframeworks (device + simulator slices)..."
	./scripts/generate_xcframework.sh inappstore release 4.0
	./scripts/generate_xcframework.sh inappstore release_debug 4.0
	mkdir -p "$PLUG_OUT"
	rm -rf "$PLUG_OUT"/inappstore.*
	# The .gdip names "inappstore.xcframework"; Godot picks the .release /
	# .debug variant sitting next to it per build type.
	cp -R bin/inappstore.release.xcframework "$PLUG_OUT/"
	cp -R bin/inappstore.release_debug.xcframework "$PLUG_OUT/inappstore.debug.xcframework"
	cp plugins/inappstore/inappstore.gdip "$PLUG_OUT/"
	cd "$REPO"
	ok "plugin copied to ios/plugins/"
fi

# ----------------------------------------------------------------- 4. export
step "4. Export Xcode project"

if [ "$MODE" = "check" ]; then
	[ -d "$REPO/build/ios/EggEscape.xcodeproj" ] && ok "build/ios/EggEscape.xcodeproj exists" \
		|| warn "not exported yet"
	echo; echo "check complete."
	exit 0
fi

mkdir -p "$REPO/build/ios" && touch "$REPO/build/.gdignore" # keep the editor from importing exports
# --import first so a fresh clone has its .godot/ cache before exporting.
"$GODOT_BIN" --headless --path "$REPO" --import >/dev/null 2>&1 || true
EXPORT_FLAG="--export-debug"; [ "$MODE" = "release" ] && EXPORT_FLAG="--export-release"
"$GODOT_BIN" --headless --path "$REPO" $EXPORT_FLAG "iOS" "$REPO/build/ios/EggEscape.xcodeproj"
ok "exported (${EXPORT_FLAG#--export-}) to build/ios/EggEscape.xcodeproj"

cat <<EOF

Done. Next, in Xcode (needs your Apple Developer account):
  open "$REPO/build/ios/EggEscape.xcodeproj"
  1. Signing & Capabilities > Team, "Automatically manage signing"
  2. + Capability > In-App Purchase
  3. Wait for SPM to resolve GoogleMobileAds / UMP (first time: minutes)
  4. Run on a plugged-in iPhone; then Product > Archive > Upload
See docs/ios.md for the App Store Connect side.
EOF
