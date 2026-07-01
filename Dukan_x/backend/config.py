import os
from dotenv import load_dotenv

load_dotenv()

class Settings:
    # General
    ENV: str = os.getenv("ENV", "development")
    PORT: int = int(os.getenv("PORT", 8000))
    
    # Firebase
    FIREBASE_CREDENTIALS_PATH: str = os.getenv("FIREBASE_CREDENTIALS_PATH", "serviceAccountKey.json")
    
    # AI (Gemini)
    GEMINI_API_KEY: str = os.getenv("GEMINI_API_KEY", "")
    AI_MODEL: str = "gemini-1.5-flash"

settings = Settings()
