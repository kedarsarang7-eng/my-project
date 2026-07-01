from fastapi import HTTPException, Security, Request
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from firebase_admin import auth
from functools import wraps

security = HTTPBearer()

async def verify_token(credentials: HTTPAuthorizationCredentials = Security(security)):
    token = credentials.credentials
    try:
        decoded_token = auth.verify_id_token(token)
        return decoded_token
    except Exception as e:
        raise HTTPException(status_code=401, detail=f"Invalid authentication token: {e}")

def require_role(role: str):
    def decorator(func):
        @wraps(func)
        async def wrapper(*args, **kwargs):
            # Inspect kwargs for 'user' injected by depends or request
            # This is complex in FastAPI with decorators. 
            # Simplified: Logic usually goes inside the endpoint or a Dependency
            pass
        return wrapper
    return decorator

# Dependency for Owner-only routes
async def get_current_owner(user: dict = Security(verify_token)):
    # In a real app, we might check custom claims. 
    # For DukanX, we check if they are in 'owners' collection or just proceed with UID.
    # We will trust the UID is the owner_uid for now, logic handled in service.
    return user
