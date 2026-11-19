# Records the UGC kit's B-roll into store/ugc/clips/: vertical 720 x 1280,
# 30 fps, with the game's sound, and no captions or end card (--clean), so a
# creator can talk over them. Gameplay levels are played by tools/video_game.gd's
# bot; the camp, Collection and parade clips are tools/make_video.gd's own.
# The script and shot list are store/ugc/README.md.
#   powershell -ExecutionPolicy Bypass -File tools/make_ugc.ps1 [-Godot <exe>] [-Snaps <dir>] [-Only <name>]
param(
	[string]$Godot = "$env:USERPROFILE\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe",
	[string]$Snaps = "",
	[string]$Only = ""
)
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root "store\ugc\clips"
New-Item -ItemType Directory -Force $out | Out-Null
# name, then what make_video.tscn plays
$clips = @(
	@("01_gameplay_rescue", @("--level=8")),
	@("02_gameplay_chains", @("--level=33")),
	@("03_gameplay_vines",  @("--level=50")),
	@("04_gameplay_locks",  @("--level=100")),
	@("05_gameplay_prisms", @("--level=150")),
	@("06_gameplay_fog",    @("--level=200")),
	@("07_camp_build",      @("--clip=camp")),
	@("08_critters",        @("--clip=critters")),
	@("09_critter_parade",  @("--parade"))
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
	foreach ($c in $clips) {
		$name, $play = $c
		if ($Only -ne "" -and -not $name.StartsWith($Only)) { continue }
		$file = Join-Path $out "egg_escape_ugc_$name.avi"
		$a = @("--path", $root, "--write-movie", $file, "--fixed-fps", "30", "res://tools/make_video.tscn", "--",
			"--shape=portrait", "--clean") + $play
		if ($Snaps -ne "") { $a += "--snaps=$Snaps/$name"; New-Item -ItemType Directory -Force "$Snaps/$name" | Out-Null }
		& $Godot @a 2>&1 | Out-Null
		Write-Output "CLIP $file $((Get-Item $file).Length) bytes"
	}
} finally {
	Remove-Item -Force -ErrorAction SilentlyContinue $override
}
