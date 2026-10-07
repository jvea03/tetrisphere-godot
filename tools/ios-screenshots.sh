#!/usr/bin/env bash
# App Store screenshots, rendered from the game at Apple's exact sizes.
#
#   tools/ios-screenshots.sh [output-dir]      default: build/store/ios
#
# Sizes: iPhone 6.7" (1290x2796), iPhone 6.5" (1284x2778), iPad 12.9"
# (2048x2732). Each shot is tools/store_shot.tscn rendering one screen into an
# off-screen SubViewport of that size, with a throwaway profile (never saved).
set -u
cd "$(dirname "$0")/.."
OUT="${1:-build/store/ios}"
GODOT="${GODOT:-$HOME/Applications/Godot.app/Contents/MacOS/Godot}"
LOG=$(mktemp)

shoot() { # $1=size $2=scene $3=name $4=seconds to settle (default 1.5) $5=drops
	mkdir -p "$OUT/$1"
	[ -f "$OUT/$1/$3.png" ] && { printf '%s %-12s have\n' "$1" "$3"; return; }   # delete a file to redo it
	# Godot does not always exit after the capture; wait for the SHOT_OK
	# line, then kill it.
	("$GODOT" --path . --resolution 480x854 res://tools/store_shot.tscn -- \
		--scene="$2" --wait="${4:-1.5}" --drops="${5:-6}" --size="$1" --out="$PWD/$OUT/$1/$3.png" >"$LOG" 2>&1 &)
	for _ in $(seq 1 240); do grep -q "SHOT_OK\|FAILED" "$LOG" 2>/dev/null && break; sleep 0.5; done
	pkill -f "store_shot.tscn" 2>/dev/null; sleep 0.5
	printf '%s %-12s %s\n' "$1" "$3" "$(grep -oE 'SHOT_OK|FAILED_[A-Z]+' "$LOG" | head -1)"
}


for size in 1290x2796 1284x2778 2048x2732; do
	shoot "$size" home         1_home
	shoot "$size" game         2_board 5 3
	shoot "$size" win          3_win 5 1
	shoot "$size" shop         4_shop
	shoot "$size" collection   5_collection
	shoot "$size" battle_pass  6_battlepass
done
rm -f "$LOG"
echo "screenshots in $OUT/"
