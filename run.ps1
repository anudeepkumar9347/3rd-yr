# PowerShell script to run the project (Windows equivalent of run.sh)

$ErrorActionPreference = 'Stop'

# Get root directory
$ROOT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Definition
Set-Location $ROOT_DIR

$PY = $env:PYTHON
if (-not $PY) { $PY = 'python' }

<<<<<<< HEAD
=======
# Resolve full path if possible
$pyCmd = Get-Command $PY -ErrorAction SilentlyContinue
if (-not $pyCmd -and (Get-Command py -ErrorAction SilentlyContinue)) {
    $PY = 'py'
    $pyCmd = Get-Command $PY -ErrorAction SilentlyContinue
}

if (-not $pyCmd) {
    Write-Error "Python not found. Install Python 3.x from https://www.python.org/downloads/ (check 'Add to PATH') or set $env:PYTHON to full path (e.g. C:/Python312/python.exe)."; exit 1
}

# Detect Microsoft Store alias stub (WindowsApps) which triggers store popup
if ($pyCmd.Source -match 'WindowsApps') {
    Write-Host "Detected WindowsApps alias rather than a real Python install. Trying 'py' launcher..." -ForegroundColor Yellow
    if (Get-Command py -ErrorAction SilentlyContinue) {
        $PY = 'py'
        $pyCmd = Get-Command $PY
    } else {
        Write-Error "Only WindowsApps app-execution alias found. Please install real Python from python.org or Microsoft Store (disable alias) and retry."; exit 1
    }
}

Write-Host "Using Python: $($pyCmd.Source)" -ForegroundColor Cyan

>>>>>>> f6f89c0 (chore: initial commit)
$VENV_DIR = Join-Path $ROOT_DIR '.venv'
$BACKEND_PORT = $env:BACKEND_PORT
if (-not $BACKEND_PORT) { $BACKEND_PORT = 8000 }
$FRONTEND_PORT = $env:FRONTEND_PORT
if (-not $FRONTEND_PORT) { $FRONTEND_PORT = 5173 }
$APP_HOST = $env:HOST
if (-not $APP_HOST) { $APP_HOST = '0.0.0.0' }

# Create venv if needed
if (-not (Test-Path $VENV_DIR)) {
<<<<<<< HEAD
    & $PY -m venv $VENV_DIR
=======
    Write-Host "Creating virtual environment in $VENV_DIR" -ForegroundColor Cyan
    & $PY -m venv $VENV_DIR
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $VENV_DIR 'Scripts\python.exe'))) {
        Write-Error "Failed to create virtual environment. Try: $PY -m venv .venv (run manually)"; exit 1
    }
} else {
    Write-Host "Virtual environment already exists: $VENV_DIR" -ForegroundColor DarkGray
>>>>>>> f6f89c0 (chore: initial commit)
}

# Activate venv
$activateScript = Join-Path $VENV_DIR 'Scripts\Activate.ps1'
<<<<<<< HEAD
if (-not (Test-Path $activateScript)) {
    Write-Error "Could not find activate script in $VENV_DIR."
    exit 1
}
. $activateScript
=======
if (-not (Test-Path $activateScript)) { Write-Error "Could not find activate script in $VENV_DIR."; exit 1 }
. $activateScript
Write-Host "Activated venv. Python in venv: $(Get-Command python | Select-Object -ExpandProperty Source)" -ForegroundColor Green
>>>>>>> f6f89c0 (chore: initial commit)

# Install backend deps
Write-Host "Installing backend dependencies..."
try {
<<<<<<< HEAD
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
=======
    # Ensure we reference pip from venv explicitly
    $pipPath = Join-Path $VENV_DIR 'Scripts\pip.exe'
    if (-not (Test-Path $pipPath)) { $pipPath = 'pip' }
    Write-Host "Using pip: $pipPath" -ForegroundColor DarkGray
    & $pipPath install --upgrade pip
    & $pipPath install -r (Join-Path $ROOT_DIR 'backend\requirements.txt')
} catch {
    Write-Error "Failed to install backend requirements. $_"
    exit 1
}

# Start backend (run uvicorn directly; tee output to log)
$UVICORN_ARGS = @('-m','uvicorn','backend.app:app','--host', $APP_HOST,'--port', $BACKEND_PORT)
$BACKEND_LOG = Join-Path $ROOT_DIR 'backend_server.log'
if (Test-Path $BACKEND_LOG) { Remove-Item $BACKEND_LOG -Force }
Write-Host "Starting backend: python $($UVICORN_ARGS -join ' ')"
$startInfo = New-Object System.Diagnostics.ProcessStartInfo
$startInfo.FileName = (Get-Command python).Source
$startInfo.Arguments = ($UVICORN_ARGS -join ' ')
$startInfo.RedirectStandardOutput = $true
$startInfo.RedirectStandardError = $true
$startInfo.UseShellExecute = $false
$startInfo.CreateNoWindow = $true
$proc = New-Object System.Diagnostics.Process
$proc.StartInfo = $startInfo
$null = $proc.Start()
$BACK_PID = $proc.Id
Start-Job -ScriptBlock {
    param($p,$log)
    while (-not $p.HasExited) {
        if ($p.StandardOutput.Peek() -ge 0) { $p.StandardOutput.ReadLine() }
        if ($p.StandardError.Peek() -ge 0) { $p.StandardError.ReadLine() }
        Start-Sleep -Milliseconds 10
    }
} -ArgumentList $proc, $BACKEND_LOG | Out-Null
# Simple concurrent logging tailer
Start-Job -ScriptBlock {
    param($p,$log)
    $fs = [System.IO.File]::Open($log,'OpenOrCreate','Read','ReadWrite')
    $fs.Close()
    while (-not $p.HasExited) {
        Start-Sleep -Milliseconds 200
    }
} -ArgumentList $proc, $BACKEND_LOG | Out-Null
>>>>>>> f6f89c0 (chore: initial commit)

# Wait for backend to be ready (10s timeout)
$ATTEMPTS = 0
while ($true) {
    Start-Sleep -Milliseconds 100
    $ATTEMPTS++
    try {
        $response = Invoke-WebRequest -Uri "http://127.0.0.1:$BACKEND_PORT/" -UseBasicParsing -TimeoutSec 1
        if ($response.StatusCode -eq 200) { break }
<<<<<<< HEAD
    } catch {}
=======
    } catch {
        # ignore
    }
>>>>>>> f6f89c0 (chore: initial commit)
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
