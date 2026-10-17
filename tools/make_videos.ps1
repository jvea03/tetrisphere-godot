# Records the three Google Ads videos into store/ads/video/ with Godot's
# Movie Maker (tools/make_video.gd): portrait 720 x 1280, landscape
# 1920 x 1080 and square 1080 x 1080, 30 fps MJPEG AVI with sound, which
# YouTube takes as it is. Each run's window size comes from a temporary
# override.cfg (Movie Maker records the window); it is removed afterwards.
#   powershell -ExecutionPolicy Bypass -File tools/make_videos.ps1 [-Godot <exe>] [-Snaps <dir>]
param(
	[string]$Godot = "$env:USERPROFILE\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe",
	[string]$Snaps = ""
)
$root = Split-Path -Parent $PSScriptRoot
$out = Join-Path $root "store\ads\video"
New-Item -ItemType Directory -Force $out | Out-Null
$shapes = @{ portrait = @(720, 1280); landscape = @(1920, 1080); square = @(1080, 1080) }
$override = Join-Path $root "override.cfg"
try {
	foreach ($shape in "portrait", "landscape", "square") {
		$w, $h = $shapes[$shape]
		@"
[display]
window/size/window_width_override=$w
window/size/window_height_override=$h
window/stretch/mode="disabled"

[editor]
movie_writer/mjpeg_quality=0.92
"@ | Set-Content -Encoding ascii $override
		$file = Join-Path $out "egg_escape_${shape}_${w}x${h}.avi"
		$args = @("--path", $root, "--write-movie", $file, "--fixed-fps", "30", "res://tools/make_video.tscn", "--", "--shape=$shape")
		if ($Snaps -ne "") { $args += "--snaps=$Snaps" }
		& $Godot @args 2>&1 | Out-Null
		Write-Output "VIDEO $file $((Get-Item $file).Length) bytes"
	}
} finally {
	Remove-Item -Force -ErrorAction SilentlyContinue $override
}
