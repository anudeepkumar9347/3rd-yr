# Automated setup script: creates venv, installs deps, bundles local ffmpeg (Windows)
$ErrorActionPreference = 'Stop'

Write-Host '== Voice PD Detector Setup ==' -ForegroundColor Cyan
$ROOT = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ROOT

$PY = 'py'
if (-not (Get-Command $PY -ErrorAction SilentlyContinue)) { $PY = 'python' }
if (-not (Get-Command $PY -ErrorAction SilentlyContinue)) { throw 'Python launcher not found. Install Python 3.x first.' }

$VENV = Join-Path $ROOT '.venv'
if (-not (Test-Path $VENV)) {
  Write-Host 'Creating virtual environment...' -ForegroundColor Yellow
  & $PY -3 -m venv $VENV
}

$PIP = Join-Path $VENV 'Scripts/pip.exe'
if (-not (Test-Path $PIP)) { throw 'pip not found inside venv.' }

Write-Host 'Installing/Updating backend dependencies...' -ForegroundColor Yellow
& $PIP install --upgrade pip > $null
& $PIP install -r (Join-Path $ROOT 'backend/requirements.txt')

# FFmpeg local bundle
$FF_DIR = Join-Path $ROOT 'tools/ffmpeg'
$FF_BIN = Join-Path $FF_DIR 'bin'
$FF_EXE = Join-Path $FF_BIN 'ffmpeg.exe'
if (-not (Test-Path $FF_EXE)) {
  Write-Host 'Downloading ffmpeg essentials build...' -ForegroundColor Yellow
  $zipUrl = 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip'
  $tmpZip = Join-Path $env:TEMP 'ffmpeg_essentials.zip'
  Invoke-WebRequest -Uri $zipUrl -OutFile $tmpZip
  Write-Host 'Extracting ffmpeg...' -ForegroundColor Yellow
  Expand-Archive -Path $tmpZip -DestinationPath (Join-Path $ROOT 'tools') -Force
  Remove-Item $tmpZip -Force
  # The extracted folder has versioned name starting with ffmpeg-*
  $extracted = Get-ChildItem (Join-Path $ROOT 'tools') -Directory | Where-Object { $_.Name -like 'ffmpeg-*' } | Select-Object -First 1
  if (-not $extracted) { throw 'Failed to locate extracted ffmpeg directory.' }
  if (Test-Path $FF_DIR) { Remove-Item $FF_DIR -Recurse -Force }
  Rename-Item $extracted.FullName $FF_DIR
}

Write-Host 'Verifying ffmpeg...' -ForegroundColor Yellow
$ffVersion = & $FF_EXE -version | Select-Object -First 1
Write-Host "ffmpeg ready: $ffVersion" -ForegroundColor Green

Write-Host 'Setup complete. To run:' -ForegroundColor Cyan
Write-Host '  powershell -ExecutionPolicy Bypass -File run.ps1' -ForegroundColor DarkCyan
