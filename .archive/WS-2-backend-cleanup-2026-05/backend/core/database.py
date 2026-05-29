import firebase_admin
from firebase_admin import credentials, firestore
from config import settings
import os

# Initialize Firebase Admin
if not firebase_admin._apps:
    try:
        # 1. Check for specific key file (Development)
        # 1. Check for specific key file (Development)
        # Construct path relative to this file: .../backend/serviceAccountKey.json
        # file is in backend/core/database.py -> parent is core -> parent is backend
        base_dir = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
        key_path = os.path.join(base_dir, "serviceAccountKey.json")
        
        if os.path.exists(key_path):
            print(f"Loading Firebase credentials from: {key_path}")
            cred = credentials.Certificate(key_path)
            firebase_admin.initialize_app(cred)
        # 2. Check for Env Var (Production)
        elif os.getenv('GOOGLE_APPLICATION_CREDENTIALS'):
            print("Loading Firebase credentials from GOOGLE_APPLICATION_CREDENTIALS")
            firebase_admin.initialize_app()
        else:
            # 3. Fallback (GCP environment implicit auth)
            print("Warning: serviceAccountKey.json not found. Attempting default credentials.")
            firebase_admin.initialize_app()
            
    except Exception as e:
        print(f"Failed to initialize Firebase: {e}")

try:
    db = firestore.client()
except Exception as e:
    print(f"Firestore Client Connection failed: {e}")
    db = None
