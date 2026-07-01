from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from typing import Optional
from backend.app.models.base import User

# Configuration
# In production, this should validate against Cognito JWKS
OAUTH2_SCHEME = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/token")

async def get_current_user(token: str = Depends(OAUTH2_SCHEME)) -> dict:
    """
    Validate the JWT token.
    For MVP/Dev, this might just decode a dummy token or standard JWT.
    For PROD, use python-jose to verify signature against Cognito keys.
    """
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )
    
    # MOCK VALIDATION FOR DEV
    # In real impl, decode token, check expiry, check issuer (Cognito)
    if token == "mock-token":
        return {"user_id": "test-user-id", "email": "owner@example.com", "role": "owner"}
    
    # TODO: Implement actual JWT decode
    # try:
    #     payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
    #     user_id: str = payload.get("sub")
    # except JWTError:
    #     raise HTTPException(...)
    
    # Return a basic dict or User object
    return {"user_id": "test-user-id", "role": "owner"}

async def get_current_active_user(current_user: dict = Depends(get_current_user)):
    # if current_user.disabled: raise HTTPException(400, "Inactive user")
    return current_user
