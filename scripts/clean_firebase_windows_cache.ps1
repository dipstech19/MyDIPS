# Deletes cached Firebase C++ SDK under build/windows so the next CMake run
# re-downloads / re-extracts a clean SDK (fixes LNK1127 corrupt firebase_*.lib).
# Usage (repo root): .\scripts\clean_firebase_windows_cache.ps1
# Close Flutter/VS and any process locking build\ first.

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$X64 = Join-Path $ProjectRoot "build\windows\x64"
if (-not (Test-Path $X64)) {
    Write-Host "Nothing to clean: $X64 does not exist."
    exit 0
}

$removed = $false
$extracted = Join-Path $X64 "extracted"
if (Test-Path $extracted) {
    Remove-Item -Recurse -Force $extracted
    Write-Host "Removed: $extracted"
    $removed = $true
}

Get-ChildItem -Path $X64 -Filter "firebase_cpp_sdk_windows_*.zip" -ErrorAction SilentlyContinue | ForEach-Object {
    Remove-Item -Force $_.FullName
    Write-Host "Removed: $($_.FullName)"
    $removed = $true
}

if (-not $removed) {
    Write-Host "No Firebase cache found under $X64"
}

Write-Host "Done. Run: flutter pub get ; flutter run -d windows"
Write-Host "If CMake fails to download Firebase SDK, run: .\scripts\setup_firebase_cpp_sdk.ps1 -Download"
Write-Host "If LNK1127 persists, set FIREBASE_FORCE_SDK_REDOWNLOAD=1 for one build, or run setup_firebase_cpp_sdk.ps1 with a full ZIP from dl.google.com."
