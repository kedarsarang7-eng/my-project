import os
import shutil
import uuid
import logging
import base64
import time
import torch
import whisper
import numpy as np
import pyttsx3 # Keep as fallback if needed, or remove. Let's keep for now but not use.
import librosa
import edge_tts # Added edge-tts
from pathlib import Path
from typing import Optional

from fastapi import FastAPI, UploadFile, File, Form, HTTPException, Depends
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

# Import Logic
from voice_agent import VoiceAgent
# from api import customers, bills # Keeping existing imports if they exist in the workspace

# Initialize Logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger("DukanX-Brain")

app = FastAPI(title="DukanX Brain (Voice Enabled)", version="3.1.0")

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- GLOBALS ---
STT_MODEL = None
VOICE_AGENT = VoiceAgent()

# Detect Device (GPU support)
DEVICE = "cuda" if torch.cuda.is_available() else "cpu"
logger.info(f"🚀 Running on Device: {DEVICE}")

MODELS_DIR = Path("ai_models")
MODELS_DIR.mkdir(exist_ok=True)
TEMP_DIR = Path("temp_audio")
TEMP_DIR.mkdir(exist_ok=True)

# --- LOAD MODELS ---
def load_models():
    global STT_MODEL
    
    if STT_MODEL is None:
        logger.info(f"⏳ Loading Whisper 'small' model on {DEVICE}...")
        try:
            # Using "small" model as requested (better for Indian accents than base)
            STT_MODEL = whisper.load_model("small", device=DEVICE)
            logger.info("✅ Whisper Loaded Successfully.")
        except Exception as e:
            logger.error(f"❌ Failed to load Whisper: {e}")
            raise e

@app.on_event("startup")
async def startup_event():
    load_models()

# --- HELPER: AUDIO GENERATION ---
VOICE_MAP = {
    "hi": "hi-IN-SwaraNeural",
    "mr": "mr-IN-AarohiNeural",
    "bn": "bn-IN-TanishaaNeural",
    "gu": "gu-IN-DhwaniNeural",
    "kn": "kn-IN-SapnaNeural",
    "ml": "ml-IN-SobhanaNeural",
    "ta": "ta-IN-PallaviNeural",
    "te": "te-IN-ShrutiNeural",
    "ur": "ur-IN-GulshanNeural",
    "en": "en-IN-NeerjaNeural",
}

async def generate_audio_edge(text: str, lang: str = "en") -> Optional[str]:
    """Generates audio for text using Edge TTS (High Quality, Natural)"""
    filename = f"resp_{uuid.uuid4()}.mp3"
    filepath = TEMP_DIR / filename
    
    voice = VOICE_MAP.get(lang, VOICE_MAP["en"])
    logger.info(f"🔊 Generating TTS for lang '{lang}' using voice '{voice}'")
    
    try:
        communicate = edge_tts.Communicate(text, voice)
        await communicate.save(str(filepath))
        
        if filepath.exists():
            with open(filepath, "rb") as audio_file:
                encoded_string = base64.b64encode(audio_file.read()).decode('utf-8')
            os.remove(filepath)
            return encoded_string
        return None
        
    except Exception as e:
        logger.error(f"TTS Generation failed: {e}")
        return None

# --- NEW CHAT ENDPOINT (TEXT ONLY) ---
# --- RATE LIMITER ---
RATE_LIMIT_STORE = {}
RATE_LIMIT_DURATION = 60 # seconds
RATE_LIMIT_MAX = 60 # max requests per minute

middleware_logger = logging.getLogger("RateLimiter")

def check_rate_limit(user_uid: str):
    """
    Simple in-memory rate limiter logic.
    """
    now = time.time()
    user_data = RATE_LIMIT_STORE.get(user_uid, {"count": 0, "reset_time": now + RATE_LIMIT_DURATION})
    
    if now > user_data["reset_time"]:
        # Reset
        user_data = {"count": 1, "reset_time": now + RATE_LIMIT_DURATION}
    else:
        user_data["count"] += 1
        
    RATE_LIMIT_STORE[user_uid] = user_data
    
    if user_data["count"] > RATE_LIMIT_MAX:
        middleware_logger.warning(f"Rate limit exceeded for {user_uid}")
        raise HTTPException(status_code=429, detail="Rate limit exceeded. Please slow down.")

# --- NEW CHAT ENDPOINT (TEXT ONLY) ---
class ChatRequest(BaseModel):
    user_uid: str
    text: str

@app.post("/chat")
async def chat_endpoint(req: ChatRequest):
    """
    Direct Text-to-Text Endpoint using Groq.
    """
    check_rate_limit(req.user_uid)
    try:
        start_time = time.time()
        agent_response = await VOICE_AGENT.process_intent(req.text, req.user_uid)
        
        resp = {
            "text": agent_response["text"],
            "intent": agent_response["intent"],
            "data": agent_response.get("data"),
            "processing_time_ms": int((time.time() - start_time) * 1000)
        }
        return resp
    except HTTPException as he:
        raise he
    except Exception as e:
        logger.error(f"Chat Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# --- DIRECT QUERY ENDPOINT (TEXT-TO-SQL) ---
class QueryRequest(BaseModel):
    user_uid: str
    question: str

@app.post("/query")
async def query_endpoint(req: QueryRequest):
    """
    Direct Business Query Endpoint.
    Translates natural language to SQL and returns results.
    """
    from query_engine import query_engine
    
    check_rate_limit(req.user_uid)
    
    try:
        start_time = time.time()
        result = await query_engine.run_query(req.user_uid, req.question)
        
        return {
            "success": result.get("success", False),
            "text": result.get("text", ""),
            "data": result.get("data"),
            "processing_time_ms": int((time.time() - start_time) * 1000)
        }
    except Exception as e:
        logger.error(f"Query Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))


# --- PROCESSED VOICE (AGENT) ---
@app.post("/process-voice")
async def process_voice(
    file: UploadFile = File(...),
    user_uid: str = Form(...),
    language: Optional[str] = Form(None)
):
    check_rate_limit(user_uid)
    
    if not STT_MODEL:
        raise HTTPException(status_code=503, detail="AI Models not loaded")

    # 1. Save
    ext = file.filename.split(".")[-1]
    filename = f"agent_{uuid.uuid4()}.{ext}"
    filepath = TEMP_DIR / filename
    
    with open(filepath, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    detected_lang = "en"
    try:
        # 2. Transcribe (Reuse Logic)
        options = dict(fp16=(DEVICE=="cuda"))
        if language and language != "auto":
            options["language"] = language
            
        result = STT_MODEL.transcribe(str(filepath), **options)
        user_text = result["text"].strip()
        detected_lang = result.get("language", "en")
        logger.info(f"🗣️ User ({user_uid}): {user_text} (Lang: {detected_lang})")
        
        if not user_text:
             raise HTTPException(status_code=400, detail="No speech detected")

    except Exception as e:
        logger.error(f"Transcription failed: {e}")
        if filepath.exists(): os.remove(filepath)
        raise HTTPException(status_code=500, detail="Transcription failed")
    finally:
        if filepath.exists(): os.remove(filepath)
        
    # 3. Intent & Response
    agent_response = await VOICE_AGENT.process_intent(user_text, user_uid)
    
    # 4. Generate Audio
    audio_b64 = await generate_audio_edge(agent_response["text"], detected_lang)
    
    return {
        "user_text": user_text,
        "mahiru_text": agent_response["text"],
        "intent": agent_response["intent"],
        "data": agent_response.get("data"),
        "audio_base64": audio_b64
    }

@app.post("/stt")
async def stt_endpoint(
    file: UploadFile = File(...),
    language: Optional[str] = Form(None), # 'en', 'hi', 'mr', or None for auto
    mode: Optional[str] = Form("normal")
):
    """
    Dedicated Speech-to-Text Endpoint.
    """
    if not STT_MODEL:
        raise HTTPException(status_code=503, detail="Model not loaded")

    start_time = time.time()
    
    # Save Upload
    ext = file.filename.split(".")[-1] if "." in file.filename else "wav"
    filename = f"stt_{uuid.uuid4()}.{ext}"
    filepath = TEMP_DIR / filename
    
    with open(filepath, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    try:
        # Transcribe Options
        options = dict(fp16=(DEVICE=="cuda"))
        if language and language != "auto":
            options["language"] = language
            
        # Transcribe
        result = STT_MODEL.transcribe(str(filepath), **options)
        
        text = result.get("text", "").strip()
        detected_lang = result.get("language", "unknown")
        
        # Calculate Confidence
        confidence = 0.0
        if "segments" in result and result["segments"]:
            segments = result["segments"]
            avg_logprob = sum([s.get("avg_logprob", -10.0) for s in segments]) / len(segments)
            confidence = float(np.exp(avg_logprob))
            
        processing_time = (time.time() - start_time) * 1000
        
        return {
            "text": text,
            "language": detected_lang,
            "confidence": round(confidence, 2),
            "processing_time_ms": int(processing_time)
        }
        
    except Exception as e:
        logger.error(f"STT Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        if filepath.exists(): os.remove(filepath)

from bill_processor import bill_processor

# ... existing code ...

@app.post("/process-bill")
async def process_bill_endpoint(file: UploadFile = File(...)):
    """
    CamScanner + OCR Pipeline:
    1. Save Image
    2. Enhance (OpenCV)
    3. OCR (Tesseract)
    4. Extract Data (Regex)
    """
    start_time = time.time()
    
    # 1. Save Upload
    ext = file.filename.split(".")[-1]
    filename = f"bill_{uuid.uuid4()}.{ext}"
    filepath = TEMP_DIR / filename
    
    with open(filepath, "wb") as buffer:
        shutil.copyfileobj(file.file, buffer)
        
    try:
        # 2. Extract Text
        raw_text = bill_processor.extract_text(filepath)
        
        if isinstance(raw_text, dict) and "error" in raw_text:
             raise HTTPException(status_code=500, detail=raw_text["error"])
             
        # 3. Parse Data
        structured_data = bill_processor.parse_bill(raw_text)
        
        processing_time = (time.time() - start_time) * 1000
        
        logger.info(f"🧾 Processed Bill: {structured_data} ({processing_time}ms)")
        
        return {
            "success": True,
            "raw_text": raw_text,
            "data": structured_data,
            "processing_time_ms": int(processing_time)
        }
        
    except Exception as e:
        logger.error(f"Bill Processing Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
    finally:
        # Cleanup
        if filepath.exists():
            os.remove(filepath)

@app.post("/test-tts")
async def test_tts(text: str = Form(...), lang: str = Form("en")):
    b64 = await generate_audio_edge(text, lang)
    return {"audio_base64": b64}

@app.get("/")
def health_check():
    return {
        "status": "online",
        "device": DEVICE,
        "model": "whisper-small"
    }

if __name__ == "__main__":
    import uvicorn
    # 0.0.0.0 allowed for local network access (e.g., from physical phone)
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
