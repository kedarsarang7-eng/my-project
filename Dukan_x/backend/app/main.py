from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
import uvicorn
import os

from .core.db import engine, Base
from .api.v1.endpoints import sync, business
# from .api.v1.endpoints import auth # If we had a dedicated auth endpoint for login

app = FastAPI(title="DukanX Backend", version="1.0.0")

# CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Include Routers
app.include_router(sync.router, prefix="/api/v1/sync", tags=["Sync"])
app.include_router(business.router, prefix="/api/v1/business", tags=["Business"])
# app.include_router(auth.router, prefix="/api/v1/auth", tags=["Auth"])

@app.on_event("startup")
async def startup():
    # create tables if they don't exist (useful for dev)
    async with engine.begin() as conn:
        await conn.run_sync(Base.metadata.create_all)

@app.get("/")
def health_check():
    return {"status": "online", "service": "DukanX Backend"}
    
if __name__ == "__main__":
    uvicorn.run("app.main:app", host="0.0.0.0", port=8000, reload=True)
