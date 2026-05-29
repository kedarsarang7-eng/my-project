from sqlalchemy.ext.asyncio import create_async_engine, AsyncSession
from sqlalchemy.orm import sessionmaker, declarative_base
import os
from dotenv import load_dotenv

load_dotenv()

# ── Fail-Fast Guard — prevent localhost connections in production ────────────
DATABASE_URL = os.getenv("DATABASE_URL")

if not DATABASE_URL:
    if os.getenv("ENVIRONMENT", "development") == "production":
        raise RuntimeError(
            "[FATAL] DATABASE_URL environment variable is required in production. "
            "Set it to your AWS RDS endpoint, e.g.: "
            "postgresql+asyncpg://user:pass@your-rds-host.amazonaws.com:5432/dukanx_db"
        )
    else:
        # Development-only: require explicit DATABASE_URL in .env file
        raise RuntimeError(
            "DATABASE_URL environment variable is not set. "
            "Add it to your .env file. Example: "
            "DATABASE_URL=postgresql+asyncpg://postgres:postgres@localhost:5432/dukanx_db"
        )

# Disable SQL echo in production for performance
is_production = os.getenv("ENVIRONMENT", "development") == "production"
engine = create_async_engine(DATABASE_URL, echo=not is_production, future=True)

AsyncSessionLocal = sessionmaker(
    engine, class_=AsyncSession, expire_on_commit=False
)

Base = declarative_base()

async def get_db():
    async with AsyncSessionLocal() as session:
        yield session
