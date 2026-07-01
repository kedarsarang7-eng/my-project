from pydantic import BaseModel
from typing import List, Optional, Any, Dict
from datetime import datetime
from uuid import UUID

# Base Schema for synced entities
class SyncEntity(BaseModel):
    id: UUID
    updated_at: datetime
    is_deleted: bool = False

    class Config:
        from_attributes = True

# Specific Schemas
class CustomerSync(SyncEntity):
    name: str
    phone: Optional[str] = None
    email: Optional[str] = None
    balance: Optional[float] = 0.0

class ProductSync(SyncEntity):
    name: str
    sku: Optional[str] = None
    price: float
    stock_qty: Optional[float] = 0.0
    unit: Optional[str] = None

class BillItemSync(SyncEntity):
    bill_id: UUID
    product_id: Optional[UUID] = None
    qty: float
    price: float
    total: float

class BillSync(SyncEntity):
    customer_id: Optional[UUID] = None
    invoice_number: str
    bill_date: datetime
    total_amount: float
    status: str
    items: List[BillItemSync] = []

# Payload Structures
class PushRequest(BaseModel):
    business_id: UUID
    customers: List[CustomerSync] = []
    products: List[ProductSync] = []
    bills: List[BillSync] = []

class PullRequest(BaseModel):
    business_id: UUID
    last_sync_timestamp: datetime

class PullResponse(BaseModel):
    customers: List[CustomerSync] = []
    products: List[ProductSync] = []
    bills: List[BillSync] = []
    server_timestamp: datetime
