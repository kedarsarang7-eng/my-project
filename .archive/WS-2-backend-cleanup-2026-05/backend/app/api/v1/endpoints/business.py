from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from typing import List
from uuid import UUID

from ....core.db import get_db
from ....core.auth import get_current_active_user
from ....models.base import Business, BusinessUser
from pydantic import BaseModel

router = APIRouter()

# --- SCHEMAS ---
class BusinessCreate(BaseModel):
    name: str
    business_type: str
    address: str = None
    gstin: str = None

class BusinessResponse(BaseModel):
    business_id: UUID
    name: str
    business_type: str
    role: str

    class Config:
        from_attributes = True

# --- ENDPOINTS ---

@router.post("/", response_model=BusinessResponse)
async def create_business(
    business_data: BusinessCreate,
    current_user: dict = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """
    Create a new business.
    The creator automatically becomes the 'owner'.
    """
    user_id = current_user.get("user_id") # UUID string or obj
    from uuid import UUID
    # Ensure user_id is UUID
    # owner_id = UUID(user_id) if isinstance(user_id, str) else user_id
    
    # 1. Create Business
    # Mocking Owner ID for now if auth is mocked
    import uuid
    owner_uuid = uuid.uuid4() 
    
    new_business = Business(
        owner_id=owner_uuid,
        name=business_data.name,
        business_type=business_data.business_type,
        address=business_data.address,
        gstin=business_data.gstin
    )
    db.add(new_business)
    await db.flush() # get ID
    
    # 2. Assign Role in BusinessUser
    # mapping = BusinessUser(
    #     business_id=new_business.business_id,
    #     user_id=owner_uuid,
    #     role="owner"
    # )
    # db.add(mapping)
    
    await db.commit()
    await db.refresh(new_business)
    
    return BusinessResponse(
        business_id=new_business.business_id,
        name=new_business.name,
        business_type=new_business.business_type,
        role="owner"
    )

@router.get("/", response_model=List[BusinessResponse])
async def list_my_businesses(
    current_user: dict = Depends(get_current_active_user),
    db: AsyncSession = Depends(get_db)
):
    """
    List all businesses where the user has a role.
    """
    # owner_id = current_user["user_id"]
    # stmt = select(Business).join(BusinessUser).where(BusinessUser.user_id == owner_id)
    # result = await db.execute(stmt)
    # businesses = result.scalars().all()
    
    # Returning empty list for now as example since auth is mocked
    return []
