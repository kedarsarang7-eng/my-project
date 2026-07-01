from sqlalchemy import Column, String, Boolean, DateTime, ForeignKey, Numeric, text
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import relationship
from sqlalchemy.sql import func
import uuid
from ..core.db import Base

class SyncMixin:
    """Mixin for fields required by Synchronization logic"""
    # Assuming business_id is handled by MultiTenantMixin or explicitly in tables
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now(), index=True)
    is_deleted = Column(Boolean, default=False)

class User(Base):
    __tablename__ = "users"
    
    user_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email = Column(String, unique=True, nullable=False)
    password_hash = Column(String, nullable=False)
    full_name = Column(String)
    phone = Column(String)
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())

class Business(Base):
    __tablename__ = "businesses"

    business_id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    owner_id = Column(UUID(as_uuid=True), ForeignKey("users.user_id"), nullable=False)
    name = Column(String, nullable=False)
    business_type = Column(String)
    address = Column(String)
    gstin = Column(String)
    
    created_at = Column(DateTime(timezone=True), server_default=func.now())
    updated_at = Column(DateTime(timezone=True), server_default=func.now(), onupdate=func.now())
    is_deleted = Column(Boolean, default=False)

class Customer(Base, SyncMixin):
    __tablename__ = "customers"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    business_id = Column(UUID(as_uuid=True), ForeignKey("businesses.business_id"), nullable=False, index=True)
    
    name = Column(String, nullable=False)
    phone = Column(String)
    email = Column(String)
    balance = Column(Numeric(15, 2), default=0.00)
    
    last_synced_at = Column(DateTime(timezone=True))

class Product(Base, SyncMixin):
    __tablename__ = "products"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    business_id = Column(UUID(as_uuid=True), ForeignKey("businesses.business_id"), nullable=False, index=True)
    
    name = Column(String, nullable=False)
    sku = Column(String)
    price = Column(Numeric(10, 2), nullable=False)
    stock_qty = Column(Numeric(10, 2), default=0.00)
    unit = Column(String)

class Bill(Base, SyncMixin):
    __tablename__ = "bills"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    business_id = Column(UUID(as_uuid=True), ForeignKey("businesses.business_id"), nullable=False, index=True)
    customer_id = Column(UUID(as_uuid=True), ForeignKey("customers.id"), nullable=True)
    
    invoice_number = Column(String, nullable=False)
    bill_date = Column(DateTime(timezone=True), nullable=False)
    total_amount = Column(Numeric(15, 2), nullable=False)
    status = Column(String, default='PAID')
    
    items = relationship("BillItem", back_populates="bill")

class BillItem(Base, SyncMixin):
    __tablename__ = "bill_items"
    
    id = Column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    business_id = Column(UUID(as_uuid=True), ForeignKey("businesses.business_id"), nullable=False, index=True)
    bill_id = Column(UUID(as_uuid=True), ForeignKey("bills.id"), nullable=False)
    product_id = Column(UUID(as_uuid=True), ForeignKey("products.id"), nullable=True)
    
    qty = Column(Numeric(10, 2), nullable=False)
    price = Column(Numeric(10, 2), nullable=False)
    total = Column(Numeric(15, 2), nullable=False)
    
    bill = relationship("Bill", back_populates="items")
