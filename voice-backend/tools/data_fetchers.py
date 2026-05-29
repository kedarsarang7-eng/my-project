from core.database import db
from datetime import datetime, timedelta

def fetch_sales_as_dataframe(owner_uid: str, days: int = 1):
    """
    Fetches bills for the last N days.
    Returns list of dicts.
    """
    end_date = datetime.now()
    start_date = end_date - timedelta(days=days)
    start_date_iso = start_date.isoformat()

    # Query 'bills' collection where ownerId == owner_uid
    # Ensure Firestore index exists
    bills_ref = db.collection('bills')
    query = bills_ref.where('ownerId', '==', owner_uid)\
                     .where('date', '>=', start_date_iso)\
                     .stream()

    data = []
    for doc in query:
        d = doc.to_dict()
        d['id'] = doc.id
        data.append(d)
    
    return data

def fetch_stock_limit(owner_uid: str, limit: int = 50):
    """
    Fetch stock items.
    """
    stock_ref = db.collection('owners').document(owner_uid).collection('stock')
    # Limit to avoid overwhelming context
    query = stock_ref.limit(limit).stream()
    
    data = []
    for doc in query:
        d = doc.to_dict()
        # Clean data for AI
        data.append({
            "name": d.get("name", "Unknown"),
            "quantity": d.get("quantity", 0),
            "unit": d.get("unit", "kg")
        })
    return data

def fetch_all_stock(owner_uid: str):
    """
    Fetch ALL stock items for categorization logic.
    """
    stock_ref = db.collection('owners').document(owner_uid).collection('stock')
    query = stock_ref.stream()
    
    data = []
    for doc in query:
        d = doc.to_dict()
        data.append({
            "name": d.get("name", "Unknown"),
            "quantity": float(d.get("quantity", 0)),
            "unit": d.get("unit", "kg"),
            "lowStockThreshold": float(d.get("lowStockThreshold", 5.0))
        })
    return data

def fetch_purchases(owner_uid: str, days: int = 1):
    """
    Fetch purchases for the last N days.
    Assuming 'purchases' collection exists with ownerId or subcollection.
    Fallback to empty if not found logic handled by empty return.
    """
    end_date = datetime.now()
    start_date = end_date - timedelta(days=days)
    start_date_iso = start_date.isoformat()

    # Try 'owners/{uid}/purchases' first, or 'purchases' collection
    # Based on patterns, likely root 'purchases' or owner subcollection
    # Let's try root 'purchases' with ownerId filter as per 'bills'
    
    purchases_ref = db.collection('purchases')
    query = purchases_ref.where('ownerId', '==', owner_uid)\
                         .where('date', '>=', start_date_iso)\
                         .stream()
    
    data = []
    for doc in query:
        d = doc.to_dict()
        data.append(d)
    return data
