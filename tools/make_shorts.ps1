# Records the YouTube Shorts into store/youtube/shorts/: vertical 720 x 1280,
# 30 fps, with sound -- one level each, played by tools/video_game.gd's bot,
# under its own two captions and end-card headline (tools/make_video.gd).
# Titles and descriptions for each are in store/youtube/README.md.
#   powershell -ExecutionPolicy Bypass -File tools/make_shorts.ps1 [-Godot <exe>] [-Snaps <dir>] [-Only <name>]
param(
	[string]$Godot = "$env:USERPROFILE\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe",
	[string]$Snaps = "",
	[string]$Only = ""
)
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root "store\youtube\shorts"
New-Item -ItemType Directory -Force $out | Out-Null
# name, level ("parade": the critter parade; "episode": a Crash Course
# episode, tools/make_episode.tscn), first caption, second
# caption, end headline ("|" breaks a line)
$shorts = @(
	@("01_rescue",  8,   "Can you free|the critter?",   "Spin. Match.|Escape!",          "Can you save|them all?"),
	@("02_chains",  33,  "Wait for the|chain reaction...", "Pop! Pop! Pop!",           "So satisfying!"),
	@("03_vines",   50,  "Vines are|creeping in!",      "Cut them before|they spread",   "Can you keep|up?"),
	@("04_locks",   100, "Locked in?",                  "Find the key|to break free!",   "Can you crack|every lock?"),
	@("05_prisms",  150, "Prism stones only|break one way...", "Match their color!",     "Can you solve|it faster?"),
	@("06_fog",     200, "What's hiding|in the fog?",   "Clear it to|find out!",         "Brave the fog!"),
	@("07_parade",  "parade", "",                 "",                              "How many can|you collect?"),
	@("ep01_crash", "episode", "",                 "",                              "")
)
$override = Join-Path $root "override.cfg"
try {
	@"
[display]
window/size/window_width_override=720
window/size/window_height_override=1280
window/stretch/mode="disabled"

[editor]
movie_writer/mjpeg_quality=0.92
"@ | Set-Content -Encoding ascii $override
	foreach ($s in $shorts) {
		$name, $level, $cap1, $cap2, $end = $s
		if ($Only -ne "" -and -not $name.StartsWith($Only)) { continue }
		$file = Join-Path $out "egg_escape_short_$name.avi"
		if ($level -eq "episode") {   # a Crash Course episode: its own scene
			$a = @("--path", $root, "--write-movie", $file, "--fixed-fps", "30", "res://tools/make_episode.tscn", "--")
		} else {
			$a = @("--path", $root, "--write-movie", $file, "--fixed-fps", "30", "res://tools/make_video.tscn", "--",
				"--shape=portrait", "--end=$end")
			if ($level -eq "parade") { $a += "--parade" } else { $a += @("--level=$level", "--cap1=$cap1", "--cap2=$cap2") }
		}
		if ($Snaps -ne "") { $a += "--snaps=$Snaps/$name" ; New-Item -ItemType Directory -Force "$Snaps/$name" | Out-Null }
		& $Godot @a 2>&1 | Out-Null
		Write-Output "SHORT $file $((Get-Item $file).Length) bytes"
	}
} finally {
	Remove-Item -Force -ErrorAction SilentlyContinue $override
}
