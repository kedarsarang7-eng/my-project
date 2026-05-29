from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

class CustomerLinkRequest(BaseModel):
    qr_data: dict

class CustomerProfile(BaseModel):
    id: str
    name: str
    phone: str
    email: str = ""
    linkedShopIds: List[str] = []
    created_at: datetime = None
