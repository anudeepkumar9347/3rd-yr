from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import numpy as np
import wave
import io
import subprocess
import tempfile
import os
from pathlib import Path

MAX_FILE_BYTES = 10 * 1024 * 1024  # 10 MB limit

app = FastAPI(title="Voice PD Detector (Minimal)")

# Allow local frontend access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


def read_wav_bytes(file_bytes: bytes):
    # Basic length check
    if len(file_bytes) < 44:
        raise HTTPException(status_code=400, detail="File too small to be a valid WAV (must include 44-byte header).")

    # Quick RIFF/WAVE signature check
    header = file_bytes[:12]
    if not (header[0:4] == b'RIFF' and header[8:12] == b'WAVE'):
        raise HTTPException(status_code=400, detail="Not a RIFF/WAVE header. Provide an uncompressed PCM .wav file.")
    try:
        with wave.open(io.BytesIO(file_bytes), 'rb') as wf:
            framerate = wf.getframerate()
            n_channels = wf.getnchannels()
            sampwidth = wf.getsampwidth()
            if framerate <= 0 or framerate > 192000:
                raise HTTPException(status_code=400, detail="Unreasonable sample rate in WAV header.")
            if n_channels < 1 or n_channels > 8:
                raise HTTPException(status_code=400, detail="Unsupported channel count in WAV header.")
            frames = wf.readframes(wf.getnframes())
            if not frames:
                raise HTTPException(status_code=400, detail="No audio frames found in WAV file.")
            # Convert bytes to numpy array based on sample width
            if sampwidth == 1:
                dtype = np.uint8  # 8-bit PCM unsigned
            elif sampwidth == 2:
                dtype = np.int16  # 16-bit PCM
            elif sampwidth == 3:
                a = np.frombuffer(frames, dtype=np.uint8)
                a = a.reshape(-1, 3)
                b = (a[:,0].astype(np.int32) |
                     (a[:,1].astype(np.int32) << 8) |
                     (a[:,2].astype(np.int32) << 16))
                b = np.where(b & 0x800000, b | ~0xFFFFFF, b)
                data = b.astype(np.int32)
                return data, framerate, n_channels
            elif sampwidth == 4:
                dtype = np.int32
            else:
                raise HTTPException(status_code=400, detail="Unsupported sample width (only 8/16/24/32-bit PCM).")
            data = np.frombuffer(frames, dtype=dtype)
            return data, framerate, n_channels
    except HTTPException:
        raise
    except wave.Error:
        raise HTTPException(status_code=400, detail="wave module could not parse file (likely compressed or corrupt). Use PCM .wav.")
    except Exception:
        raise HTTPException(status_code=400, detail="Failed to parse WAV (unexpected error). Ensure PCM .wav format.")


def resolve_ffmpeg() -> str | None:
    """Return ffmpeg executable path if found in local tools folder or PATH."""
    candidates = []
    root = Path(__file__).resolve().parents[1]
    local_bin = root / 'tools' / 'ffmpeg' / 'bin'
    if local_bin.exists():
        # common executable names
        for name in ('ffmpeg.exe','ffmpeg'):
            p = local_bin / name
            if p.exists():
                candidates.append(str(p))
    # fallback to just 'ffmpeg'
    candidates.append('ffmpeg')
    for c in candidates:
        try:
            subprocess.run([c, '-version'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, check=False)
            return c
        except FileNotFoundError:
            continue
    return None

def ffmpeg_available() -> bool:
    return resolve_ffmpeg() is not None


def transcode_to_pcm_wav(file_bytes: bytes, orig_name: str):
    exe = resolve_ffmpeg()
    if not exe:
        raise HTTPException(status_code=400, detail="Transcoding requested but ffmpeg not available. Use setup script or install ffmpeg.")
    with tempfile.TemporaryDirectory() as td:
        in_path = os.path.join(td, f"input_{orig_name}")
        out_path = os.path.join(td, "out.wav")
        with open(in_path, 'wb') as f:
            f.write(file_bytes)
        # Convert using ffmpeg to 16-bit mono 16k PCM wav
        cmd = [
            exe, "-y", "-i", in_path,
            "-ac", "1",  # mono
            "-ar", "16000",  # 16 kHz
            "-sample_fmt", "s16",
            out_path
        ]
        proc = subprocess.run(cmd, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True)
        if proc.returncode != 0 or not os.path.exists(out_path):
            raise HTTPException(status_code=400, detail="ffmpeg failed to transcode file to PCM WAV.")
        with open(out_path, 'rb') as f:
            wav_bytes = f.read()
        return read_wav_bytes(wav_bytes)


def load_audio_any(file_bytes: bytes, filename: str):
    """Attempt WAV parse; if MP3 and decoder available decode MP3; else ffmpeg; else error."""
    lower = filename.lower()
    # First try WAV
    try:
        data, sr, ch = read_wav_bytes(file_bytes)
        return data, sr, ch, 'wav'
    except HTTPException:
        pass

    # MP3 path requires ffmpeg (no pure-Python decoder bundled)
    if (lower.endswith('.mp3') or file_bytes[:3] == b'ID3'):
        if ffmpeg_available():
            data, sr, ch = transcode_to_pcm_wav(file_bytes, filename)
            return data, sr, ch, 'transcoded'
        raise HTTPException(status_code=400, detail="MP3 provided but ffmpeg not installed. Install ffmpeg or upload WAV.")

    # ffmpeg fallback (if available and not mp3 or mp3 failed)
    try:
        data, sr, ch = transcode_to_pcm_wav(file_bytes, filename)
        return data, sr, ch, 'transcoded'
    except HTTPException as e:
        raise e


def mono_signal(data: np.ndarray, n_channels: int) -> np.ndarray:
    if n_channels > 1:
        return data.reshape(-1, n_channels).mean(axis=1)
    return data


def extract_features(x: np.ndarray, sr: int) -> dict:
    x = x.astype(np.float64)
    if x.size == 0:
        return {"rms": 0.0, "zcr": 0.0, "pitch_var": 0.0}

    # Normalize to [-1, 1] range when possible
    max_abs = np.max(np.abs(x)) if np.max(np.abs(x)) > 0 else 1.0
    x = x / max_abs

    # RMS energy
    rms = float(np.sqrt(np.mean(x**2)))

    # Zero crossing rate
    zcr = float(((x[:-1] * x[1:]) < 0).mean()) if x.size > 1 else 0.0

    # Very rough pitch estimate via autocorrelation peak location
    # Limit to plausible speech F0 range ~60-350 Hz
    min_lag = max(1, int(sr / 350))
    max_lag = max(min_lag + 1, int(sr / 60))
    if x.size > max_lag + 1:
        x0 = x - np.mean(x)
        ac = np.correlate(x0, x0, mode='full')[x0.size-1:]
        ac = ac / (np.max(ac) + 1e-9)
        segment = ac[min_lag:max_lag]
        peak_lag = int(np.argmax(segment)) + min_lag
        # crude pitch track over frames
        frame = max(sr // 50, 1)
        steps = max(1, x.size // frame)
        lags = []
        for i in range(steps):
            s = i * frame
            e = min(x.size, s + frame)
            xi = x0[s:e]
            if xi.size < max_lag + 1:
                continue
            aci = np.correlate(xi, xi, mode='full')[xi.size-1:]
            aci = aci / (np.max(aci) + 1e-9)
            seg = aci[min_lag:max_lag]
            lags.append(int(np.argmax(seg)) + min_lag)
        pitch_hz = [sr / lag for lag in lags if lag > 0]
        pitch_var = float(np.var(pitch_hz)) if pitch_hz else 0.0
    else:
        pitch_var = 0.0

    return {"rms": rms, "zcr": zcr, "pitch_var": pitch_var}


def simple_pd_score(feats: dict) -> float:
    # Heuristic, NOT a medical model. Higher zcr with low rms and high pitch variance increased score.
    rms = feats["rms"]
    zcr = feats["zcr"]
    pv = feats["pitch_var"]
    score = 0.0
    score += 1.5 * zcr
    score += 0.5 * min(pv / 1000.0, 1.0)
    score += 0.3 * (0.1 - rms)  # lower rms slightly increases score
    return float(np.clip(score, 0.0, 1.0))


@app.post("/predict")
async def predict(file: UploadFile = File(...)):
    content = await file.read()
    if len(content) == 0:
        raise HTTPException(status_code=400, detail="Empty file uploaded.")
    if len(content) > MAX_FILE_BYTES:
        raise HTTPException(status_code=400, detail=f"File exceeds {MAX_FILE_BYTES//(1024*1024)}MB limit.")
    try:
        data, sr, ch, src_type = load_audio_any(content, file.filename or "uploaded")
    except HTTPException:
        raise
    except Exception:
        raise HTTPException(status_code=400, detail="Failed to decode audio file.")
    x = mono_signal(data, ch)
    feats = extract_features(x, sr)
    score = simple_pd_score(feats)
    label = "possible_parkinson_signal" if score > 0.5 else "non_parkinson_like"
    return JSONResponse({
        "label": label,
        "score": round(score, 3),
        "features": feats,
        "sample_rate": sr,
        "channels": ch,
        "source_type": src_type
    })


@app.get("/")
async def root():
    return {"message": "Voice PD Detector backend running"}

@app.get("/health")
async def health_check():
    """Health check endpoint for monitoring and demo purposes"""
    return {
        "status": "healthy",
        "service": "Voice PD Detector API",
        "version": "1.0.0",
        "timestamp": "2025-09-21",
        "features": {
            "audio_formats": ["WAV", "MP3", "MP4", "FLAC", "AAC", "OGG"],
            "max_file_size_mb": MAX_FILE_BYTES // (1024 * 1024),
            "ffmpeg_available": ffmpeg_available()
        }
    }
