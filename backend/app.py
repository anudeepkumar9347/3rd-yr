from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import JSONResponse
import numpy as np
import wave
import io

app = FastAPI(title="Voice PD Detector (Minimal)")

# Allow local frontend access
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)


def read_wav_bytes(file_bytes: bytes):
    try:
        with wave.open(io.BytesIO(file_bytes), 'rb') as wf:
            framerate = wf.getframerate()
            n_channels = wf.getnchannels()
            sampwidth = wf.getsampwidth()
            frames = wf.readframes(wf.getnframes())
            # Convert bytes to numpy array based on sample width
            if sampwidth == 1:
                dtype = np.uint8  # 8-bit PCM unsigned
            elif sampwidth == 2:
                dtype = np.int16  # 16-bit PCM
            elif sampwidth == 3:
                # 24-bit: convert manually
                a = np.frombuffer(frames, dtype=np.uint8)
                a = a.reshape(-1, 3)
                # combine little-endian bytes into signed 32-bit then scale
                b = (a[:,0].astype(np.int32) |
                     (a[:,1].astype(np.int32) << 8) |
                     (a[:,2].astype(np.int32) << 16))
                # sign correction for 24-bit
                b = np.where(b & 0x800000, b | ~0xFFFFFF, b)
                data = b.astype(np.int32)
                return data, framerate, n_channels
            elif sampwidth == 4:
                dtype = np.int32
            else:
                raise ValueError("Unsupported sample width")
            data = np.frombuffer(frames, dtype=dtype)
            return data, framerate, n_channels
    except wave.Error:
        raise HTTPException(status_code=400, detail="Invalid WAV file. Please upload a PCM .wav audio.")


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
    if not file.filename.lower().endswith('.wav'):
        raise HTTPException(status_code=400, detail="Please upload a .wav file")
    content = await file.read()
    data, sr, ch = read_wav_bytes(content)
    x = mono_signal(data, ch)
    feats = extract_features(x, sr)
    score = simple_pd_score(feats)
    label = "possible_parkinson_signal" if score > 0.5 else "non_parkinson_like"
    return JSONResponse({
        "label": label,
        "score": round(score, 3),
        "features": feats
    })


@app.get("/")
async def root():
    return {"message": "Voice PD Detector backend running"}
