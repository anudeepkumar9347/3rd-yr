# Voice PD Detector - Ultimate Windows PowerShell Script
# This script handles setup, dependencies, and running the Voice PD Detector project
# Usage: powershell -ExecutionPolicy Bypass -File start.ps1 [setup|run|help]

param(
    [string]$Action = "run",
    [switch]$Help,
    [switch]$Setup,
    [switch]$Run,
    [switch]$Force
)

$ErrorActionPreference = 'Stop'

# Configuration
$ROOT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Definition
$VENV_DIR = Join-Path $ROOT_DIR '.venv'
$BACKEND_PORT = if ($env:BACKEND_PORT) { $env:BACKEND_PORT } else { 8000 }
$FRONTEND_PORT = if ($env:FRONTEND_PORT) { $env:FRONTEND_PORT } else { 5173 }
$APP_HOST = if ($env:HOST) { $env:HOST } else { '0.0.0.0' }
$BACKEND_LOG = Join-Path $ROOT_DIR 'backend_server.log'

# Color functions
function Write-Header { param($Text) Write-Host $Text -ForegroundColor Cyan }
function Write-Success { param($Text) Write-Host $Text -ForegroundColor Green }
function Write-Warning { param($Text) Write-Host $Text -ForegroundColor Yellow }
function Write-Info { param($Text) Write-Host $Text -ForegroundColor DarkGray }

function Show-Help {
    Write-Header "=== Voice PD Detector - Ultimate Windows Script ==="
    Write-Host ""
    Write-Host "USAGE:"
    Write-Host "  powershell -ExecutionPolicy Bypass -File start.ps1 [options]"
    Write-Host ""
    Write-Host "OPTIONS:"
    Write-Host "  setup       Run setup only (install dependencies, download ffmpeg)"
    Write-Host "  run         Run the application (default)"
    Write-Host "  -Setup      Same as 'setup'"
    Write-Host "  -Run        Same as 'run'" 
    Write-Host "  -Force      Force re-setup even if already configured"
    Write-Host "  -Help       Show this help message"
    Write-Host ""
    Write-Host "EXAMPLES:"
    Write-Host "  start.ps1                    # Run the application"
    Write-Host "  start.ps1 setup              # Setup only"
    Write-Host "  start.ps1 -Setup -Force     # Force re-setup"
    Write-Host ""
    Write-Host "ENVIRONMENT VARIABLES:"
    Write-Host "  BACKEND_PORT=8000           # Backend server port"
    Write-Host "  FRONTEND_PORT=5173          # Frontend server port"
    Write-Host "  HOST=0.0.0.0               # Server host"
    Write-Host "  PYTHON=python               # Python executable path"
    Write-Host ""
}

function Find-Python {
    $candidates = @()
    
    # Try environment variable first
    if ($env:PYTHON) { $candidates += $env:PYTHON }
    
    # Try common Python commands
    $candidates += @('py', 'python', 'python3')
    
    foreach ($candidate in $candidates) {
        try {
            $cmd = Get-Command $candidate -ErrorAction SilentlyContinue
            if ($cmd) {
                # Test if it actually works
                $result = & $candidate --version 2>&1
                if ($LASTEXITCODE -eq 0) {
                    # Detect Microsoft Store alias stub
                    if ($cmd.Source -match 'WindowsApps') {
                        Write-Warning "Detected WindowsApps alias for $candidate. Trying 'py' launcher..."
                        continue
                    }
                    Write-Info "Found Python: $($cmd.Source)"
                    return $candidate
                }
            }
        } catch {
            continue
        }
    }
    
    throw "Python not found. Install Python 3.x from https://www.python.org/downloads/ (check 'Add to PATH') or set `$env:PYTHON to full path."
}

function Setup-VirtualEnvironment {
    param($PythonCmd)
    
    if ((Test-Path $VENV_DIR) -and -not $Force) {
        Write-Success "Virtual environment already exists: $VENV_DIR"
        return
    }
    
    if ($Force -and (Test-Path $VENV_DIR)) {
        Write-Warning "Removing existing virtual environment..."
        Remove-Item $VENV_DIR -Recurse -Force
    }
    
    Write-Header "Creating virtual environment..."
    & $PythonCmd -m venv $VENV_DIR
    
    if ($LASTEXITCODE -ne 0 -or -not (Test-Path (Join-Path $VENV_DIR 'Scripts\python.exe'))) {
        throw "Failed to create virtual environment. Try: $PythonCmd -m venv .venv (run manually)"
    }
    
    Write-Success "Virtual environment created successfully"
}

function Install-Dependencies {
    Write-Header "Installing backend dependencies..."
    
    # Activate virtual environment
    $activateScript = Join-Path $VENV_DIR 'Scripts\Activate.ps1'
    if (-not (Test-Path $activateScript)) {
        throw "Could not find activate script in $VENV_DIR"
    }
    
    . $activateScript
    Write-Success "Activated virtual environment"
    
    try {
        # Upgrade pip
        $pipPath = Join-Path $VENV_DIR 'Scripts\pip.exe'
        if (-not (Test-Path $pipPath)) { $pipPath = 'pip' }
        
        Write-Info "Upgrading pip..."
        & $pipPath install --upgrade pip --quiet
        
        Write-Info "Installing requirements..."
        & $pipPath install -r (Join-Path $ROOT_DIR 'backend\requirements.txt')
        
        Write-Success "Dependencies installed successfully"
    } catch {
        throw "Failed to install backend requirements: $_"
    }
}

function Setup-FFmpeg {
    $FF_DIR = Join-Path $ROOT_DIR 'tools\ffmpeg'
    $FF_BIN = Join-Path $FF_DIR 'bin'
    $FF_EXE = Join-Path $FF_BIN 'ffmpeg.exe'
    
    if ((Test-Path $FF_EXE) -and -not $Force) {
        $ffVersion = & $FF_EXE -version 2>$null | Select-Object -First 1
        Write-Success "FFmpeg already available: $ffVersion"
        return
    }
    
    Write-Header "Setting up FFmpeg..."
    
    # Check if ffmpeg is available in PATH
    if (Get-Command ffmpeg -ErrorAction SilentlyContinue) {
        Write-Success "FFmpeg found in system PATH"
        return
    }
    
    if ($Force -and (Test-Path $FF_DIR)) {
        Write-Warning "Removing existing FFmpeg installation..."
        Remove-Item $FF_DIR -Recurse -Force
    }
    
    try {
        Write-Info "Downloading FFmpeg essentials build..."
        $zipUrl = 'https://www.gyan.dev/ffmpeg/builds/ffmpeg-release-essentials.zip'
        $tmpZip = Join-Path $env:TEMP 'ffmpeg_essentials.zip'
        
        # Create tools directory if it doesn't exist
        $toolsDir = Join-Path $ROOT_DIR 'tools'
        if (-not (Test-Path $toolsDir)) {
            New-Item -ItemType Directory -Path $toolsDir -Force | Out-Null
        }
        
        Invoke-WebRequest -Uri $zipUrl -OutFile $tmpZip -UseBasicParsing
        
        Write-Info "Extracting FFmpeg..."
        Expand-Archive -Path $tmpZip -DestinationPath $toolsDir -Force
        Remove-Item $tmpZip -Force
        
        # Find extracted directory (has version in name)
        $extracted = Get-ChildItem $toolsDir -Directory | Where-Object { $_.Name -like 'ffmpeg-*' } | Select-Object -First 1
        if (-not $extracted) {
            throw 'Failed to locate extracted ffmpeg directory'
        }
        
        # Rename to standard name
        if (Test-Path $FF_DIR) { Remove-Item $FF_DIR -Recurse -Force }
        Rename-Item $extracted.FullName $FF_DIR
        
        # Verify installation
        $ffVersion = & $FF_EXE -version | Select-Object -First 1
        Write-Success "FFmpeg installed: $ffVersion"
        
    } catch {
        Write-Warning "Failed to download FFmpeg: $_"
        Write-Info "You can install FFmpeg manually or use system-wide installation"
    }
}

function Start-Backend {
    param($PythonCmd)
    
    Write-Header "Starting backend server..."
    
    # Activate virtual environment
    $activateScript = Join-Path $VENV_DIR 'Scripts\Activate.ps1'
    . $activateScript
    
    # Clean up old log
    if (Test-Path $BACKEND_LOG) { Remove-Item $BACKEND_LOG -Force }
    
    # Start uvicorn server
    $uvicornArgs = @('-m', 'uvicorn', 'backend.app:app', '--host', $APP_HOST, '--port', $BACKEND_PORT, '--reload')
    Write-Info "Command: python $($uvicornArgs -join ' ')"
    
    $startInfo = New-Object System.Diagnostics.ProcessStartInfo
    $startInfo.FileName = (Get-Command python).Source
    $startInfo.Arguments = ($uvicornArgs -join ' ')
    $startInfo.RedirectStandardOutput = $true
    $startInfo.RedirectStandardError = $true
    $startInfo.UseShellExecute = $false
    $startInfo.CreateNoWindow = $true
    $startInfo.WorkingDirectory = $ROOT_DIR
    
    $proc = New-Object System.Diagnostics.Process
    $proc.StartInfo = $startInfo
    $null = $proc.Start()
    
    Write-Success "Backend process started (PID: $($proc.Id))"
    return $proc
}

function Wait-ForBackend {
    param($Process)
    
    Write-Info "Waiting for backend to be ready..."
    $attempts = 0
    $maxAttempts = 100
    
    while ($attempts -lt $maxAttempts) {
        Start-Sleep -Milliseconds 100
        $attempts++
        
        try {
            $response = Invoke-WebRequest -Uri "http://127.0.0.1:$BACKEND_PORT/" -UseBasicParsing -TimeoutSec 1
            if ($response.StatusCode -eq 200) {
                Write-Success "Backend is ready!"
                return $true
            }
        } catch {
            # Continue waiting
        }
        
        # Check if process is still running
        if ($Process.HasExited) {
            throw "Backend process exited early. Check $BACKEND_LOG for details."
        }
    }
    
    throw "Backend failed to start within timeout. Check $BACKEND_LOG for details."
}

function Start-Frontend {
    Write-Header "Starting frontend server..."
    
    # Get local IP for LAN access
    try {
        $lanIP = (Get-NetIPAddress -AddressFamily IPv4 | 
                 Where-Object { $_.IPAddress -ne '127.0.0.1' -and $_.PrefixOrigin -ne 'WellKnown' } | 
                 Select-Object -First 1 -ExpandProperty IPAddress)
    } catch {
        $lanIP = '127.0.0.1'
    }
    
    if (-not $lanIP) { $lanIP = '127.0.0.1' }
    
    # Print live links
    Write-Host ""
    Write-Host "========================================"
    Write-Success "Voice PD Detector is live!"
    Write-Host "Frontend:  http://127.0.0.1:$FRONTEND_PORT"
    Write-Host "           http://$lanIP:$FRONTEND_PORT (LAN)"
    Write-Host "API:       http://127.0.0.1:$BACKEND_PORT"
    Write-Host "           http://$lanIP:$BACKEND_PORT (LAN)"
    Write-Warning "Press Ctrl+C to stop both servers"
    Write-Host "========================================"
    Write-Host ""
    
    # Change to frontend directory and start HTTP server
    Set-Location (Join-Path $ROOT_DIR 'frontend')
    
    # Activate venv for python command
    $activateScript = Join-Path $VENV_DIR 'Scripts\Activate.ps1'
    . $activateScript
    
    python -m http.server $FRONTEND_PORT
}

function Main {
    Set-Location $ROOT_DIR
    
    # Parse arguments
    if ($Help -or $Action -eq "help") {
        Show-Help
        return
    }
    
    if ($Setup -or $Action -eq "setup") {
        $Action = "setup"
    } elseif ($Run -or $Action -eq "run") {
        $Action = "run"
    }
    
    Write-Header "=== Voice PD Detector - Windows Setup & Runner ==="
    Write-Info "Action: $Action"
    Write-Info "Root Directory: $ROOT_DIR"
    Write-Host ""
    
    try {
        # Find Python
        $pythonCmd = Find-Python
        Write-Success "Using Python: $pythonCmd"
        
        # Setup phase
        if ($Action -eq "setup" -or $Action -eq "run") {
            Setup-VirtualEnvironment -PythonCmd $pythonCmd
            Install-Dependencies
            Setup-FFmpeg
            
            if ($Action -eq "setup") {
                Write-Success "Setup completed successfully!"
                Write-Info "To run the application: powershell -ExecutionPolicy Bypass -File start.ps1"
                return
            }
        }
        
        # Run phase
        if ($Action -eq "run") {
            # Verify setup is complete
            if (-not (Test-Path $VENV_DIR)) {
                Write-Warning "Virtual environment not found. Running setup first..."
                Setup-VirtualEnvironment -PythonCmd $pythonCmd
                Install-Dependencies
                Setup-FFmpeg
            }
            
            $backendProcess = Start-Backend -PythonCmd $pythonCmd
            
            try {
                Wait-ForBackend -Process $backendProcess
                Start-Frontend
            } finally {
                # Cleanup
                if (-not $backendProcess.HasExited) {
                    Write-Info "Stopping backend process..."
                    $backendProcess.Kill()
                }
            }
        }
        
    } catch {
        Write-Host "Error: $_" -ForegroundColor Red
        exit 1
    }
}

# Run main function
Main
