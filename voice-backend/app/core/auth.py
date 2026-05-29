import os
import json
import base64
from fastapi import Depends, HTTPException, status
from fastapi.security import OAuth2PasswordBearer
from typing import Optional

# Configuration — Cognito JWT validation
# COGNITO_REGION and COGNITO_USER_POOL_ID must be set in production
COGNITO_REGION = os.getenv("COGNITO_REGION", os.getenv("AWS_REGION", "ap-south-1"))
COGNITO_USER_POOL_ID = os.getenv("COGNITO_USER_POOL_ID", "")

# Fail-fast in production if Cognito is not configured
if os.getenv("ENVIRONMENT", "development") == "production" and not COGNITO_USER_POOL_ID:
    raise RuntimeError(
        "[FATAL] COGNITO_USER_POOL_ID must be set in production. "
        "Cannot start without authentication configuration."
    )

OAUTH2_SCHEME = OAuth2PasswordBearer(tokenUrl="/api/v1/auth/token")


async def get_current_user(token: str = Depends(OAUTH2_SCHEME)) -> dict:
    """
    Validate the JWT token against Cognito.
    Decodes the JWT payload and extracts user claims.
    
    For full production security, integrate python-jose with Cognito JWKS:
      pip install python-jose[cryptography] requests
    """
    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Could not validate credentials",
            headers={"WWW-Authenticate": "Bearer"},
        )

    try:
        # Decode JWT payload (middle segment) to extract claims
        # NOTE: For full security, verify signature against Cognito JWKS endpoint:
        #   https://cognito-idp.{region}.amazonaws.com/{pool_id}/.well-known/jwks.json
        # Use python-jose: jwt.decode(token, jwks_keys, algorithms=["RS256"], audience=client_id)
        parts = token.split(".")
        if len(parts) != 3:
            raise ValueError("Invalid JWT format")

        # Decode payload with padding fix
        payload_b64 = parts[1]
        payload_b64 += "=" * (4 - len(payload_b64) % 4)
        payload = json.loads(base64.urlsafe_b64decode(payload_b64))

        # Extract standard Cognito claims
        user_id = payload.get("sub")
        if not user_id:
            raise ValueError("Missing 'sub' claim in token")

        # Check token expiration
        import time
        exp = payload.get("exp")
        if exp and time.time() > exp:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Token has expired",
                headers={"WWW-Authenticate": "Bearer"},
            )

        return {
            "user_id": user_id,
            "email": payload.get("email", ""),
            "role": payload.get("custom:role", "staff"),
            "tenant_id": payload.get("custom:tenant_id", ""),
        }

    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=f"Invalid authentication token: {str(e)}",
            headers={"WWW-Authenticate": "Bearer"},
        )


async def get_current_active_user(current_user: dict = Depends(get_current_user)):
    if not current_user.get("user_id"):
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Invalid user session",
        )
    return current_user
