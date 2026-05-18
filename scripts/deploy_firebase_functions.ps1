# Deploy Cloud Functions (notifications stock / logistique / pointage)
# Usage (from repo root):
#   .\scripts\deploy_firebase_functions.ps1
# First time: opens browser for `firebase login`

$ErrorActionPreference = "Stop"
$ProjectRoot = Split-Path -Parent $PSScriptRoot
$FunctionsDir = Join-Path $ProjectRoot "functions"
$FirebaseCmd = Join-Path $env:APPDATA "npm\firebase.cmd"

if (-not (Test-Path $FirebaseCmd)) {
    Write-Host "Firebase CLI not found. Installing..."
    npm install -g firebase-tools
    if (-not (Test-Path $FirebaseCmd)) {
        Write-Error "firebase.cmd still missing at $FirebaseCmd. Restart PowerShell or add %APPDATA%\npm to PATH."
    }
}

$projectId = "dips-management"
Set-Location $ProjectRoot

if (-not (Test-Path (Join-Path $ProjectRoot "firebase.json"))) {
    Write-Error "firebase.json missing in project root."
}

Write-Host "npm install (functions)..."
Set-Location $FunctionsDir
npm install

Set-Location $ProjectRoot
Write-Host "Firebase project: $projectId"
& $FirebaseCmd use $projectId

Write-Host "Deploying functions (login in browser if asked)..."
& $FirebaseCmd deploy --only functions --project $projectId

Write-Host "Done. Check Firebase Console > Functions for onOpsEventCreated, onPointageEventCreated, dailyOpsDigest."
