from pydantic import BaseModel
from typing import List, Optional
from datetime import datetime

class BillItem(BaseModel):
    product_id: Optional[str] = None
    name: str
    quantity: float
    price: float
    total: float

class BillCreate(BaseModel):
    customer_id: str
    shop_id: str
    items: List[BillItem]
    subtotal: float
    gst: float = 0.0
    total: float
    paid_amount: float = 0.0
    payment_status: str = "Unpaid" # Paid, Unpaid, Partial
