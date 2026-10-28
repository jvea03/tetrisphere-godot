# Builds one of Egg Escape's own Android plugins (android_plugins/<Name>,
# Java) into addons/<Name>/bin/{debug,release}/: EggNotify (the default) or
# EggReview. Uses the Gradle wrapper and godot-lib of the installed Android
# build template, so install that first (tools/release_aab.ps1 does). Run with:
#   powershell -ExecutionPolicy Bypass -File tools/build_notify_plugin.ps1 [-Name EggReview]
param([string]$Name = "EggNotify")
$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root "android_plugins\$Name"
$out = Join-Path $root "addons\$Name\bin"
$sdk = "$env:LOCALAPPDATA\Android\Sdk"
Set-Content -Encoding ascii (Join-Path $src "local.properties") ("sdk.dir=" + $sdk.Replace("\", "/"))
& (Join-Path $root "android\build\gradlew.bat") -p $src assembleDebug assembleRelease --console=plain
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
foreach ($kind in "debug", "release") {
	New-Item -ItemType Directory -Force (Join-Path $out $kind) | Out-Null
	Copy-Item -Force (Join-Path $src "build\outputs\aar\$Name-$kind.aar") (Join-Path $out "$kind\$Name-$kind.aar")
}
Write-Output "$Name built into $out"
