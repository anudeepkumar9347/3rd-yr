# Voice PD Detector - Windows Guide

## Quick Start

### Option 1: Double-click to run
- Double-click `start.bat` to run the application

### Option 2: PowerShell (Recommended)
```powershell
powershell -ExecutionPolicy Bypass -File start.ps1
```

### Option 3: Command Prompt
```cmd
start.bat
```

## Commands

### Setup Only
```powershell
# Install dependencies and download FFmpeg
powershell -ExecutionPolicy Bypass -File start.ps1 setup
```

### Run Application
```powershell
# Start both backend and frontend servers
powershell -ExecutionPolicy Bypass -File start.ps1 run
```

### Force Re-setup
```powershell
# Force reinstall everything
powershell -ExecutionPolicy Bypass -File start.ps1 setup -Force
```

### Help
```powershell
powershell -ExecutionPolicy Bypass -File start.ps1 help
```

## Configuration

Set environment variables to customize:

```powershell
$env:BACKEND_PORT = 8000        # Backend API port
$env:FRONTEND_PORT = 5173       # Frontend server port  
$env:HOST = "0.0.0.0"          # Server host
$env:PYTHON = "python"         # Python executable path
```

## Requirements

- Windows 10/11 with PowerShell
- Python 3.7+ (with pip)
- Internet connection (for initial setup)

## What the script does

1. **Finds Python** - Detects Python installation automatically
2. **Creates Virtual Environment** - Isolates project dependencies
3. **Installs Dependencies** - Installs FastAPI, uvicorn, numpy, etc.
4. **Downloads FFmpeg** - For audio processing (if not in system PATH)
5. **Starts Backend** - FastAPI server on port 8000
6. **Starts Frontend** - Static file server on port 5173

## Access URLs

After running:
- **Frontend**: http://127.0.0.1:5173
- **API**: http://127.0.0.1:8000
- **LAN Access**: Also available on your local network IP

## Troubleshooting

### Python not found
```powershell
# Set Python path manually
$env:PYTHON = "C:\Python39\python.exe"
powershell -ExecutionPolicy Bypass -File start.ps1
```

### PowerShell execution policy
```powershell
# Enable script execution (run as Administrator)
Set-ExecutionPolicy RemoteSigned -Scope CurrentUser
```

### Port conflicts
```powershell
# Use different ports
$env:BACKEND_PORT = 8080
$env:FRONTEND_PORT = 3000
powershell -ExecutionPolicy Bypass -File start.ps1
```

### Force clean setup
```powershell
# Remove virtual environment and reinstall
powershell -ExecutionPolicy Bypass -File start.ps1 setup -Force
```
