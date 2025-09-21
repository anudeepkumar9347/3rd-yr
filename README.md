# Voice PD Detector

A web-based demonstration tool for analyzing voice patterns potentially associated with Parkinson's Disease using basic audio signal processing heuristics.

## ⚠️ Important Disclaimer

**This is a demonstration tool for educational purposes only.** 
- Results are based on simple heuristic algorithms
- **NOT a medical diagnostic tool**
- **NOT a substitute for professional medical consultation**
- Do not make medical decisions based on these results

## Features

- 🎤 **Audio Upload**: Supports multiple formats (WAV, MP3, MP4, etc.)
- 🔬 **Signal Analysis**: Extracts RMS energy, zero-crossing rate, and pitch variance
- 📊 **Visual Results**: Modern UI with confidence indicators and detailed feedback
- 🌐 **Cross-Platform**: Works on Windows, macOS, and Linux
- ⚡ **Real-time Processing**: Fast analysis with progress feedback

## Quick Start

### Linux/macOS
```bash
bash run.sh
```

### Windows
```cmd
start.bat
```
Or:
```powershell
powershell -ExecutionPolicy Bypass -File start.ps1
```

## What It Does

1. **Audio Processing**: Converts uploaded audio to standardized format
2. **Feature Extraction**: Calculates basic voice pattern metrics
3. **Heuristic Analysis**: Applies simple algorithms to generate confidence scores
4. **Results Display**: Shows analysis with explanatory information

## Technology Stack

- **Backend**: FastAPI (Python) with uvicorn
- **Frontend**: Vanilla HTML/CSS/JavaScript
- **Audio Processing**: FFmpeg + NumPy
- **Dependencies**: See `backend/requirements.txt`

## Development

### Setup
```bash
# Create virtual environment
python -m venv .venv
source .venv/bin/activate  # Linux/macOS
# .venv\Scripts\activate   # Windows

# Install dependencies
pip install -r backend/requirements.txt
```

### Run Development Server
```bash
# Backend only
uvicorn backend.app:app --host 0.0.0.0 --port 8000 --reload

# Frontend only
cd frontend && python -m http.server 5173
```

## API Documentation

Once running, visit:
- **API Docs**: http://127.0.0.1:8000/docs
- **Frontend**: http://127.0.0.1:5173

## Contributing

This is a demonstration project. For production use, consider:
- Implementing proper machine learning models
- Adding comprehensive validation
- Including medical professional oversight
- Following healthcare data regulations

## License

Educational/demonstration use only.

---

**Remember**: Always consult healthcare professionals for medical concerns.
