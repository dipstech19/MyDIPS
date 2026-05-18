# Extracts the Firebase C++ SDK Windows ZIP into .firebase_cpp_sdk/ so CMake can use
# the SDK without contacting dl.google.com (offline / flaky CMake downloads).
# Usage (from repo root):
#   .\scripts\setup_firebase_cpp_sdk.ps1 -Download
#   .\scripts\setup_firebase_cpp_sdk.ps1 [-ZipPath <path>]
# -Download: fetch the ZIP with curl.exe -4 (IPv4 only; avoids "Network unreachable" on IPv6).
# If -ZipPath is omitted and -Download not used, looks for firebase_cpp_sdk_windows_*.zip
# under .firebase_cpp_sdk/ or repo root.

param(
    [string] $ZipPath,
    [switch] $Download
)

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $ProjectRoot "pubspec.yaml"))) {
    Write-Error "Could not find pubspec.yaml; expected project root: $ProjectRoot"
}

$expectedVersion = $null
$pluginCmake = Join-Path $ProjectRoot "windows\flutter\ephemeral\.plugin_symlinks\firebase_core\windows\CMakeLists.txt"
if (Test-Path $pluginCmake) {
    $m = Select-String -Path $pluginCmake -Pattern 'set\(FIREBASE_SDK_VERSION "([0-9.]+)"\)' | Select-Object -First 1
    if ($m) { $expectedVersion = $m.Matches[0].Groups[1].Value }
}
if (-not $expectedVersion) {
    Write-Error "Could not read FIREBASE_SDK_VERSION from firebase_core. Run 'flutter pub get' first."
}

$destRoot = Join-Path $ProjectRoot ".firebase_cpp_sdk"
$destSdk = Join-Path $destRoot "firebase_cpp_sdk_windows"
$versionH = Join-Path $destSdk "include\firebase\version.h"

if (Test-Path $versionH) {
    $raw = Get-Content -Raw $versionH
    $maj = if ($raw -match "FIREBASE_VERSION_MAJOR\s+(\d+)") { $Matches[1] } else { $null }
    $min = if ($raw -match "FIREBASE_VERSION_MINOR\s+(\d+)") { $Matches[1] } else { $null }
    $rev = if ($raw -match "FIREBASE_VERSION_REVISION\s+(\d+)") { $Matches[1] } else { $null }
    if ($maj -and $min -and $rev) {
        $have = "$maj.$min.$rev"
        if ($have -eq $expectedVersion) {
            Write-Host "SDK already present ($have): $destSdk"
            exit 0
        }
        Write-Warning "Existing SDK is $have but firebase_core expects $expectedVersion. Remove .firebase_cpp_sdk or replace the ZIP."
    }
}

if ($Download -and [string]::IsNullOrEmpty($ZipPath)) {
    $url = "https://dl.google.com/firebase/sdk/cpp/firebase_cpp_sdk_windows_$expectedVersion.zip"
    $outZip = Join-Path $destRoot "firebase_cpp_sdk_windows_$expectedVersion.zip"
    New-Item -ItemType Directory -Path $destRoot -Force | Out-Null
    if (Test-Path $outZip) {
        $sz = (Get-Item $outZip).Length
        $minBytes = 150MB
        if ($sz -ge $minBytes) {
            Write-Host "Using existing ZIP ($sz bytes): $outZip"
            $ZipPath = $outZip
        } else {
            Write-Warning "Removing too-small ZIP ($sz bytes): $outZip"
            Remove-Item -Force $outZip
        }
    }
    if (-not $ZipPath) {
        $curl = Get-Command curl.exe -ErrorAction SilentlyContinue
        if (-not $curl) {
            Write-Error "curl.exe not found (Windows 10+ includes it). Install curl or download the ZIP manually from: $url"
        }
        Write-Host "Downloading (IPv4 only): $url"
        $curlArgs = @(
            "-4", "-L", "--fail", "--retry", "3", "--retry-delay", "5",
            "--connect-timeout", "60",
            "-o", $outZip,
            $url
        )
        & curl.exe @curlArgs
        if ($LASTEXITCODE -ne 0) {
            Write-Error "curl download failed (exit $LASTEXITCODE). Try another network, VPN, or download the ZIP in a browser from:`n  $url"
        }
        $got = (Get-Item $outZip).Length
        $minBytes = 150MB
        if ($got -lt $minBytes) {
            Remove-Item -Force $outZip -ErrorAction SilentlyContinue
            Write-Error "Download too small ($got bytes); expected a full SDK ZIP (~150+ MB). Remove partial file and retry."
        }
        Write-Host "Download OK ($got bytes): $outZip"
        $ZipPath = $outZip
    }
}

if (-not $ZipPath) {
    $candidates = @()
    $candidates += Get-ChildItem -Path (Join-Path $destRoot "firebase_cpp_sdk_windows_*.zip") -ErrorAction SilentlyContinue
    $candidates += Get-ChildItem -Path (Join-Path $ProjectRoot "firebase_cpp_sdk_windows_*.zip") -ErrorAction SilentlyContinue
    if ($candidates.Count -eq 0) {
        Write-Error @"
No ZIP found. Either run:
  .\scripts\setup_firebase_cpp_sdk.ps1 -Download
or download firebase_cpp_sdk_windows_$expectedVersion.zip (Firebase C++ SDK for Windows),
place it under:
  $destRoot\
or the repo root, then run this script again.
"@
    }
    $exact = $candidates | Where-Object { $_.Name -eq "firebase_cpp_sdk_windows_$expectedVersion.zip" }
    if ($exact) {
        $ZipPath = ($exact | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
    } else {
        Write-Warning "No firebase_cpp_sdk_windows_$expectedVersion.zip found; using newest matching firebase_cpp_sdk_windows_*.zip (version must match firebase_core)."
        $ZipPath = ($candidates | Sort-Object LastWriteTime -Descending | Select-Object -First 1).FullName
    }
}

if (-not (Test-Path $ZipPath)) {
    Write-Error "ZIP not found: $ZipPath"
}

Write-Host "Extracting: $ZipPath"
New-Item -ItemType Directory -Path $destRoot -Force | Out-Null
$temp = Join-Path $destRoot "_extract_tmp"
if (Test-Path $temp) { Remove-Item -Recurse -Force $temp }
New-Item -ItemType Directory -Path $temp -Force | Out-Null
$tempZip = Join-Path $env:TEMP ("firebase_cpp_sdk_extract_" + [Guid]::NewGuid().ToString("N") + ".zip")
try {
    Copy-Item -Path $ZipPath -Destination $tempZip -Force
    Expand-Archive -Path $tempZip -DestinationPath $temp -Force
    $inner = Get-ChildItem -Path $temp -Directory | Select-Object -First 1
    if (-not $inner) {
        Write-Error "ZIP did not contain a top-level folder."
    }
    if ($inner.Name -ne "firebase_cpp_sdk_windows") {
        Write-Error "Expected top-level folder firebase_cpp_sdk_windows, found $($inner.Name)"
    }
    if (Test-Path $destSdk) {
        Remove-Item -Recurse -Force $destSdk
    }
    Move-Item -Path $inner.FullName -Destination $destSdk
    $vh = Join-Path $destSdk "include\firebase\version.h"
    if (-not (Test-Path $vh)) { Write-Error "Extracted SDK missing include\firebase\version.h" }
    $raw = Get-Content -Raw $vh
    $maj = if ($raw -match "FIREBASE_VERSION_MAJOR\s+(\d+)") { $Matches[1] } else { $null }
    $min = if ($raw -match "FIREBASE_VERSION_MINOR\s+(\d+)") { $Matches[1] } else { $null }
    $rev = if ($raw -match "FIREBASE_VERSION_REVISION\s+(\d+)") { $Matches[1] } else { $null }
    $got = "$maj.$min.$rev"
    if ($got -ne $expectedVersion) {
        Remove-Item -Recurse -Force $destSdk
        Write-Error "ZIP contained SDK $got but firebase_core expects $expectedVersion. Use firebase_cpp_sdk_windows_$expectedVersion.zip."
    }
}
finally {
    if (Test-Path $tempZip) { Remove-Item -Force $tempZip -ErrorAction SilentlyContinue }
    if (Test-Path $temp) { Remove-Item -Recurse -Force $temp }
}

Write-Host "Done. Local SDK: $destSdk"
Write-Host "Run: flutter build windows --release"
