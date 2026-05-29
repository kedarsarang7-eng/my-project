# DukanX Voice Backend

FastAPI + Whisper + edge-tts speech-to-text / TTS service for the DukanX desktop app.

## Architecture

See `docs/ARCHITECTURE.md §4.8` for context.

- **Speech-to-Text (STT):** OpenAI Whisper via `main.py`
- **Text-to-Speech (TTS):** edge-tts + pyttsx3 fallback
- **NLU:** `nlu_engine.py` — intent classification for voice billing commands
- **Voice Agent:** `voice_agent.py` — orchestrates STT → NLU → action → TTS

## Setup

```bash
# Create virtualenv
python -m venv venv
venv\Scripts\activate  # Windows

# Install deps
pip install -r requirements.txt

# Run locally
uvicorn main:app --reload --port 8000
```

## Deploy to EC2

Use `scripts/backend-ec2/` — run `ec2-setup.sh` then `deploy.sh`.

## Flutter integration

Set `STT_BASE_URL=http://<EC2_IP>:8000` in `Dukan_x/.env`.
The Flutter app reads this via `AppConfig.sttBaseUrl`.
