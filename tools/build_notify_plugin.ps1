# Builds the EggNotify Android plugin (android_plugins/EggNotify, Java) into
# addons/EggNotify/bin/{debug,release}/. Uses the Gradle wrapper and godot-lib
# of the installed Android build template, so install that first
# (tools/release_aab.ps1 does). Run with:
#   powershell -ExecutionPolicy Bypass -File tools/build_notify_plugin.ps1
$root = Split-Path -Parent $PSScriptRoot
$src = Join-Path $root "android_plugins\EggNotify"
$out = Join-Path $root "addons\EggNotify\bin"
$sdk = "$env:LOCALAPPDATA\Android\Sdk"
Set-Content -Encoding ascii (Join-Path $src "local.properties") ("sdk.dir=" + $sdk.Replace("\", "/"))
& (Join-Path $root "android\build\gradlew.bat") -p $src assembleDebug assembleRelease --console=plain
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
foreach ($kind in "debug", "release") {
	New-Item -ItemType Directory -Force (Join-Path $out $kind) | Out-Null
	Copy-Item -Force (Join-Path $src "build\outputs\aar\EggNotify-$kind.aar") (Join-Path $out "$kind\EggNotify-$kind.aar")
}
Write-Output "EggNotify built into $out"
