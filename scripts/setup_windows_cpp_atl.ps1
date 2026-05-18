# Installs the Visual Studio C++ ATL component required by flutter_local_notifications_windows (atlbase.h).
# Usage (from repo root, in an elevated PowerShell, or let the script request elevation):
#   .\scripts\setup_windows_cpp_atl.ps1
#
# After success: flutter clean && flutter pub get && flutter run -d windows

param(
    [switch] $SkipElevate
)

$ErrorActionPreference = "Stop"

function Test-AtlInstalled {
    $vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
    if (-not (Test-Path $vswhere)) { return $false }
    $path = & $vswhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.ATL -property installationPath 2>$null
    if (-not $path) { return $false }
    $header = Get-ChildItem -Path $path -Filter "atlbase.h" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 1
    return [bool]$header
}

function Request-AdminRelaunch {
    if ($SkipElevate) {
        Write-Error @"
ATL is not installed. Re-run this script in PowerShell started with 'Run as administrator', or omit -SkipElevate to auto-elevate.
"@
    }
    Write-Host "Requesting administrator privileges..."
    $argList = @(
        "-NoProfile"
        "-ExecutionPolicy", "Bypass"
        "-File", "`"$PSCommandPath`""
        "-SkipElevate"
    )
    Start-Process -FilePath "powershell.exe" -Verb RunAs -ArgumentList $argList -Wait
    if (Test-AtlInstalled) {
        Write-Host "ATL is installed. You can run: flutter clean; flutter run -d windows"
        exit 0
    }
    Write-Error "ATL installation did not complete. Open Visual Studio Installer manually and add 'C++ ATL for latest v143 build tools (x86 & x64)'."
}

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator
)
if (-not $isAdmin) {
    Request-AdminRelaunch
    exit $LASTEXITCODE
}

if (Test-AtlInstalled) {
    Write-Host "ATL is already installed (atlbase.h found). Nothing to do."
    exit 0
}

$setup = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\setup.exe"
if (-not (Test-Path $setup)) {
    Write-Error "Visual Studio Installer not found at: $setup"
}

$vswhere = Join-Path ${env:ProgramFiles(x86)} "Microsoft Visual Studio\Installer\vswhere.exe"
$installPath = & $vswhere -latest -products * -property installationPath 2>$null
if (-not $installPath) {
    Write-Error "No Visual Studio installation found. Install 'Desktop development with C++' (Build Tools 2022) first."
}

Write-Host "Installing Microsoft.VisualStudio.Component.VC.ATL into:"
Write-Host "  $installPath"
Write-Host "(This may take several minutes.)"

& $setup modify `
    --installPath $installPath `
    --add Microsoft.VisualStudio.Component.VC.ATL `
    --passive `
    --norestart `
    --wait

if ($LASTEXITCODE -ne 0) {
    Write-Error "setup.exe modify failed with exit code $LASTEXITCODE. Use Visual Studio Installer > Modify > Individual components > 'C++ ATL for latest v143 build tools (x86 & x64)'."
}

if (-not (Test-AtlInstalled)) {
    Write-Error "setup.exe reported success but atlbase.h was not found. Retry from Visual Studio Installer."
}

Write-Host "Done. ATL installed."
Write-Host "Next: flutter clean"
Write-Host "      flutter pub get"
Write-Host "      flutter run -d windows"
