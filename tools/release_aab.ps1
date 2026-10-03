# Builds the signed Play Store App Bundle: build/egg-escape-<version>.aab.
#
# Run it yourself in PowerShell, from the project folder:
#   powershell -ExecutionPolicy Bypass -File tools\release_aab.ps1
#
# It asks for the upload key's password here, in your terminal, and hands it
# to Godot through environment variables for this one export only -- nothing
# is written to disk or to the repo.
#
# First time only: make the upload key (keep the file and its password safe
# and backed up -- Play needs the same key for every update):
#   & "C:\Program Files\Eclipse Adoptium\jdk-17.0.20.101-hotspot\bin\keytool.exe" -genkeypair -v -keystore "$HOME\egg-escape-upload.keystore" -alias upload -keyalg RSA -keysize 2048 -validity 10000
#
# Bump version/code (and version/name) under [preset.1.options] in
# export_presets.cfg before every new upload: Play refuses a code it has seen.

param(
    [string]$Keystore = "$HOME\egg-escape-upload.keystore",
    [string]$Alias = "upload"
)

$ErrorActionPreference = "Stop"
$godot = "$HOME\Downloads\Godot_v4.7.1-stable_win64.exe\Godot_v4.7.1-stable_win64_console.exe"
$project = Split-Path -Parent $PSScriptRoot

if (-not (Test-Path $Keystore)) {
    Write-Host "No upload key at $Keystore -- make one first (see the top of this script)." -ForegroundColor Red
    exit 1
}

# The version, from the AAB preset.
$preset = Get-Content "$project\export_presets.cfg" -Raw
$options = $preset.Substring($preset.IndexOf("[preset.1.options]"))
$code = [regex]::Match($options, 'version/code=(\d+)').Groups[1].Value
$name = [regex]::Match($options, 'version/name="([^"]+)"').Groups[1].Value
$out = "build/egg-escape-$name-$code.aab"
Write-Host "Building Egg Escape $name (version code $code) -> $out"

$secure = Read-Host "Upload key password" -AsSecureString
$plain = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($secure))

$env:GODOT_ANDROID_KEYSTORE_RELEASE_PATH = $Keystore
$env:GODOT_ANDROID_KEYSTORE_RELEASE_USER = $Alias
$env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD = $plain
try {
    New-Item -ItemType Directory -Force "$project\build" | Out-Null
    # The Gradle build template, installed on the first run.
    $template = @()
    if (-not (Test-Path (Join-Path $project "android\build"))) { $template = @("--install-android-build-template") }
    & $godot --headless --path $project @template --export-release "Android AAB" $out
} finally {
    Remove-Item Env:GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD -ErrorAction SilentlyContinue
    $plain = $null
}

if (Test-Path "$project\$out") {
    Write-Host "Done: $project\$out" -ForegroundColor Green
} else {
    Write-Host "The export failed -- see the messages above." -ForegroundColor Red
    exit 1
}
