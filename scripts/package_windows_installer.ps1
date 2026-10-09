# Build the Windows installer (.exe) with Inno Setup.
#
# Assumes scripts/package_windows.ps1 has already produced
# build\windows\x64\runner\Release (it is what copies rust_core.dll and the
# models into the bundle), so this script only wraps that directory.
#
# Inno Setup comes from `choco install innosetup`; the compiler is `iscc`.
#
# Usage:
#   powershell -ExecutionPolicy Bypass -File scripts/package_windows_installer.ps1 -Version 1.0.0
#
# Output:
#   dist/TrareonTranscribe-<version>-windows-setup.exe

param(
    [string]$Version = ""
)

$ErrorActionPreference = "Stop"
Set-Location (Join-Path $PSScriptRoot "..")

if ([string]::IsNullOrEmpty($Version)) {
    $pubspec = Get-Content "pubspec.yaml" | Select-String "^version:"
    $Version = ($pubspec -split ":\s*")[1].Split("+")[0]
}

$BuildDir = "build\windows\x64\runner\Release"
$DistDir = "dist"
$Iss = "windows\installer\trareon.iss"

if (-not (Test-Path $BuildDir)) {
    Write-Error "$BuildDir not found. Run scripts/package_windows.ps1 first."
    exit 1
}

# `iscc` is not on PATH after a fresh choco install in the same shell session,
# so fall back to the standard install locations rather than failing.
# NB: `?.` (null-conditional) is PowerShell 7+ only, and GitHub's `powershell`
# is Windows PowerShell 5.1 — it aborts the whole script with a parse error
# before any of our fallback logic can run. Keep this 5.1-compatible.
$IsccCmd = Get-Command iscc -ErrorAction SilentlyContinue
if ($IsccCmd) { $Iscc = $IsccCmd.Source } else { $Iscc = $null }
if (-not $Iscc) {
    foreach ($candidate in @(
        "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe",
        "${env:ProgramFiles}\Inno Setup 6\ISCC.exe"
    )) {
        if (Test-Path $candidate) { $Iscc = $candidate; break }
    }
}
if (-not $Iscc) {
    Write-Error "Inno Setup (iscc) not found. Install it with: choco install innosetup -y"
    exit 1
}

New-Item -ItemType Directory -Force -Path $DistDir | Out-Null

$AbsSource = (Resolve-Path $BuildDir).Path
$AbsOutput = (Resolve-Path $DistDir).Path

Write-Host "==> Compiling $Iss with $Iscc"
& $Iscc "/DMyAppVersion=$Version" "/DSourceDir=$AbsSource" "/DOutputDir=$AbsOutput" $Iss
if ($LASTEXITCODE -ne 0) {
    Write-Error "iscc failed with exit code $LASTEXITCODE"
    exit $LASTEXITCODE
}

$SetupPath = Join-Path $DistDir "TrareonTranscribe-$Version-windows-setup.exe"
if (-not (Test-Path $SetupPath)) {
    Write-Error "expected $SetupPath after a successful iscc run"
    exit 1
}

Write-Host "==> Generating checksum"
$hash = Get-FileHash -Path $SetupPath -Algorithm SHA256
"$($hash.Hash.ToLower())  $(Split-Path $SetupPath -Leaf)" |
    Out-File -Encoding ascii "$SetupPath.sha256"

Write-Host "Done: $SetupPath"
