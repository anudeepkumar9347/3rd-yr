# PowerShell script to run the project (Windows equivalent of run.sh)

$ErrorActionPreference = 'Stop'

# Get root directory
$ROOT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ROOT_DIR

$PY = $env:PYTHON
if (-not $PY) { $PY = 'python' }

$VENV_DIR = Join-Path $ROOT_DIR '.venv'
$BACKEND_PORT = $env:BACKEND_PORT
if (-not $BACKEND_PORT) { $BACKEND_PORT = 8000 }
$FRONTEND_PORT = $env:FRONTEND_PORT
if (-not $FRONTEND_PORT) { $FRONTEND_PORT = 5173 }
$APP_HOST = $env:HOST
if (-not $APP_HOST) { $APP_HOST = '0.0.0.0' }

# Create venv if needed
if (-not (Test-Path $VENV_DIR)) {
    & $PY -m venv $VENV_DIR
}

# Activate venv
$activateScript = Join-Path $VENV_DIR 'Scripts\Activate.ps1'
if (-not (Test-Path $activateScript)) {
    Write-Error "Could not find activate script in $VENV_DIR."
    exit 1
}
. $activateScript

# Install backend deps
Write-Host "Installing backend dependencies..."
try {
    pip install --upgrade pip
    pip install -r (Join-Path $ROOT_DIR 'backend\requirements.txt')
} catch {
    Write-Error "Failed to install backend requirements."
    exit 1
}

# Start backend
$UVICORN_CMD = "python -m uvicorn backend.app:app --host $APP_HOST --port $BACKEND_PORT"
$BACKEND_LOG = Join-Path $ROOT_DIR 'backend_server.log'
Write-Host "Starting backend: $UVICORN_CMD"
Start-Process powershell -ArgumentList "-NoProfile -Command `$ErrorActionPreference='Stop'; $UVICORN_CMD *>&1 | Tee-Object -FilePath '$BACKEND_LOG'" -NoNewWindow -PassThru | ForEach-Object { $BACK_PID = $_.Id }

# Wait for backend to be ready (10s timeout)
$ATTEMPTS = 0
while ($true) {
    Start-Sleep -Milliseconds 100
    $ATTEMPTS++
    try {
        $response = Invoke-WebRequest -Uri "http://127.0.0.1:$BACKEND_PORT/" -UseBasicParsing -TimeoutSec 1
        if ($response.StatusCode -eq 200) { break }
    } catch {}
    if ($ATTEMPTS -gt 100) {
        Write-Error "Backend failed to start on port $BACKEND_PORT. See $BACKEND_LOG for details."
        Get-Content $BACKEND_LOG
        exit 1
    }
    # Check if backend process is still running
    if (-not (Get-Process -Id $BACK_PID -ErrorAction SilentlyContinue)) {
        Write-Error "Backend process exited early. See $BACKEND_LOG for details."
        Get-Content $BACKEND_LOG
        exit 1
    }
}

# Determine local IP (best-effort)
$LAN_IP = (Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -ne '127.0.0.1' -and $_.PrefixOrigin -ne 'WellKnown' } | Select-Object -First 1 -ExpandProperty IPAddress)
if (-not $LAN_IP) { $LAN_IP = '127.0.0.1' }

# Print live links
Write-Host ""
Write-Host "========================================"
Write-Host "Voice PD Detector is live!"
Write-Host "Frontend:  http://127.0.0.1:${FRONTEND_PORT}"
Write-Host "           http://${LAN_IP}:${FRONTEND_PORT} (LAN)"
Write-Host "API:       http://127.0.0.1:${BACKEND_PORT}"
Write-Host "           http://${LAN_IP}:${BACKEND_PORT} (LAN)"
Write-Host "Press Ctrl+C to stop."
Write-Host "========================================"
Write-Host ""

# Serve the frontend directory
Set-Location (Join-Path $ROOT_DIR 'frontend')
python -m http.server $FRONTEND_PORT
