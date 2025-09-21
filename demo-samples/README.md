# Demo Sample Files

This directory should contain sample audio files for demonstration purposes.

## Recommended Demo Files

1. **normal_speech.wav** - Clear, normal speech sample (5-10 seconds)
2. **test_recording.mp3** - Different format to show transcoding
3. **sample_voice.m4a** - Another format example

## Creating Demo Samples

### Option 1: Record your own
- Record 5-10 seconds of clear speech
- Say something like: "Hello, this is a test recording for the voice analysis demonstration."
- Save in different formats (WAV, MP3, M4A)

### Option 2: Generate synthetic samples
```python
import numpy as np
import scipy.io.wavfile as wavfile

# Generate a simple synthetic audio signal
duration = 5  # seconds
sample_rate = 16000
t = np.linspace(0, duration, duration * sample_rate)

# Simple sine wave with some noise (placeholder)
frequency = 200  # Hz
audio = np.sin(2 * np.pi * frequency * t) + 0.1 * np.random.randn(len(t))
audio = (audio * 32767).astype(np.int16)

wavfile.write('demo_sample.wav', sample_rate, audio)
```

### Option 3: Use text-to-speech
Many online TTS services can generate sample audio files.

## File Requirements

- **Duration**: 5-10 seconds (optimal for demo)
- **Size**: Under 10MB (application limit)
- **Formats**: WAV, MP3, M4A, MP4 (to show format support)
- **Content**: Clear speech, not music or noise

## Demo Notes

- Test files before demo to ensure they work
- Have backup files in case of issues
- Consider having files with different characteristics to show varied results
