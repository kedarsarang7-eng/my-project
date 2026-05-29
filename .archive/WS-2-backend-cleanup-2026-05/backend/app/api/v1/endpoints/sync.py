from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.ext.asyncio import AsyncSession
from sqlalchemy.future import select
from typing import List
from datetime import datetime, timezone
from uuid import UUID

from ....core.db import get_db
from ....models.base import Customer, Product, Bill, BillItem
from ....schemas.sync import PushRequest, PullRequest, PullResponse, CustomerSync, ProductSync, BillSync, BillItemSync

router = APIRouter()

# --- HELPER: UPSERT LOGIC ---
async def upsert_entity(session: AsyncSession, model, schema_item: SyncEntity, business_id: UUID):
    """
    Generic upsert logic:
    1. Check if exists.
    2. If not, create.
    3. If exists, update IF schema_item.updated_at > db_item.updated_at.
    """
    # Note: merge() is often easier for simple upserts, but we want the timestamp check logic.
    stmt = select(model).where(model.id == schema_item.id)
    result = await session.execute(stmt)
    db_item = result.scalars().first()

    if not db_item:
        # Create New
        new_item = model(**schema_item.dict(exclude={'items'}), business_id=business_id) # Exclude nested items for Bills
        session.add(new_item)
    else:
        # Update if incoming is newer
        # Ensure timezone awareness for comparison
        db_updated_at = db_item.updated_at
        if db_updated_at.tzinfo is None:
            # Assume stored as UTC if naive
             db_updated_at = db_updated_at.replace(tzinfo=timezone.utc)
        
        inc_updated_at = schema_item.updated_at
        if inc_updated_at.tzinfo is None:
             inc_updated_at = inc_updated_at.replace(tzinfo=timezone.utc)

        if inc_updated_at > db_updated_at:
            for key, value in schema_item.dict(exclude={'items'}).items():
                setattr(db_item, key, value)
            # Explicitly set business_id to ensure safety
            db_item.business_id = business_id 

# --- ENDPOINTS ---

@router.post("/push", summary="Push local changes to Cloud")
async def push_changes(payload: PushRequest, db: AsyncSession = Depends(get_db)):
    """
    Receive changes from Desktop App.
    Apply changes to DB using Last-Write-Wins based on 'updated_at'.
    """
    # 1. Customers
    for item in payload.customers:
        await upsert_entity(db, Customer, item, payload.business_id)
    
    # 2. Products
    for item in payload.products:
        await upsert_entity(db, Product, item, payload.business_id)
        
    # 3. Bills (Complex: Handle items)
    for bill_data in payload.bills:
        # Upsert Bill Header
        await upsert_entity(db, Bill, bill_data, payload.business_id)
        
        # Upsert Bill Items
        # Strategy: Delete existing items for this bill and re-insert is safest for sync 
        # IF the bill is being fully ignored/overwritten. 
        # However, for efficiency, we might want to just upsert items too.
        # Let's sticking to upserting items individually if they have IDs.
        for item_data in bill_data.items:
             await upsert_entity(db, BillItem, item_data, payload.business_id)

    try:
        await db.commit()
        return {"status": "success", "message": "Changes synced successfully"}
    except Exception as e:
        await db.rollback()
        raise HTTPException(status_code=500, detail=str(e))

@router.post("/pull", response_model=PullResponse, summary="Pull cloud changes to Desktop")
async def pull_changes(req: PullRequest, db: AsyncSession = Depends(get_db)):
    """
    Return all records modified after 'last_sync_timestamp' for the given business.
    """
    response = PullResponse(server_timestamp=datetime.now(timezone.utc))
    
    # Helper to fetch
    async def fetch_updates(model, model_sync_schema):
        stmt = select(model).where(
            model.business_id == req.business_id,
            model.updated_at > req.last_sync_timestamp
        )
        result = await db.execute(stmt)
        return [model_sync_schema.from_orm(row) for row in result.scalars().all()]

    # 1. Customers
    response.customers = await fetch_updates(Customer, CustomerSync)
    
    # 2. Products
    response.products = await fetch_updates(Product, ProductSync)
    
    # 3. Bills (Need to fetch items eagerly? Or separate?)
    # For simplicity, fetching Bills. Clients might need to fetch Items separately or we include them.
    # Let's try to include items in the Bill schema if SQLAlchemy relationship is set up correctly (lazy='joined' helps).
    # Since we didn't specify lazy loading in models, we might need explicit join or just fetch bills.
    # For this iteration, let's fetch bills.
    
    stmt = select(Bill).where(
        Bill.business_id == req.business_id,
        Bill.updated_at > req.last_sync_timestamp
    )
    result = await db.execute(stmt)
    bills = result.scalars().all()
    
    # Manually populate Pydantic models to ensure nested relationships if loaded
    # To properly load items, we would typically use .options(selectinload(Bill.items))
    # But for now let's return bills without items to avoid N+1 query complexity in this first pass
    # OR we can just fetch items separately if the client sync logic supports it.
    # The Schema `BillSync` has `items: List[BillItemSync] = []`.
    # Let's populate it.
    
    from sqlalchemy.orm import selectinload
    stmt_bills = select(Bill).options(selectinload(Bill.items)).where(
         Bill.business_id == req.business_id,
         Bill.updated_at > req.last_sync_timestamp
    )
    result_bills = await db.execute(stmt_bills)
    response.bills = [BillSync.from_orm(b) for b in result_bills.scalars().all()]

    return response
