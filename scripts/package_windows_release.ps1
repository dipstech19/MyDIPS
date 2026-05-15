param(
    [switch] $SkipBuild
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
Set-Location $ProjectRoot

if (-not $SkipBuild) {
    flutter build windows --release --obfuscate --split-debug-info=build/symbols --tree-shake-icons
}

$src = Join-Path $ProjectRoot "build\windows\x64\runner\Release"
if (-not (Test-Path $src)) {
    throw "Release build folder not found: $src"
}

$outRoot = Join-Path $ProjectRoot "dist\windows"
$stage = Join-Path $outRoot "dipsmanagment"
$zip = Join-Path $outRoot "dipsmanagment-windows-release.zip"

if (Test-Path $stage) { Remove-Item -Recurse -Force $stage }
New-Item -ItemType Directory -Path $outRoot -Force | Out-Null
Copy-Item -Recurse -Force $src $stage

# Runtime-safe trimming: keep only files needed to run.
Get-ChildItem $stage -Recurse -File -Include *.lib,*.exp,*.ilk,*.pdb | Remove-Item -Force -ErrorAction SilentlyContinue

if (Test-Path $zip) { Remove-Item -Force $zip }
Compress-Archive -Path (Join-Path $stage "*") -DestinationPath $zip -CompressionLevel Optimal

$rawSize = (Get-ChildItem $src -Recurse -File | Measure-Object Length -Sum).Sum
$trimSize = (Get-ChildItem $stage -Recurse -File | Measure-Object Length -Sum).Sum
$zipSize = (Get-Item $zip).Length

Write-Host ("Raw folder : {0} MB" -f [math]::Round($rawSize / 1MB, 2))
Write-Host ("Trim folder: {0} MB" -f [math]::Round($trimSize / 1MB, 2))
Write-Host ("Zip output : {0} MB" -f [math]::Round($zipSize / 1MB, 2))
Write-Host ("Package ready: {0}" -f $zip)
