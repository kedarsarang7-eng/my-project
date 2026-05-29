from core.database import db

# Simple mock database for demo purposes (Common Indian FMCG items)
MOCK_BARCODE_DB = {
    "8901058000000": {"name": "Maggi 2-Minute Noodles", "brand": "Nestle", "size": "70g", "category": "Snacks"},
    "8901030541738": {"name": "Lux International Creamy", "brand": "Lux", "size": "125g", "category": "Personal Care"},
    "8901725132225": {"name": "Tata Salt", "brand": "Tata", "size": "1kg", "category": "Groceries"},
    "8901233020615": {"name": "Amul Butter", "brand": "Amul", "size": "100g", "category": "Dairy"},
}

def lookup_barcode_details(barcode: str, owner_uid: str) -> dict:
    """
    Checks strictly:
    1. Owner's existing stock (to prevent duplicates or fetch current details)
    2. Global/Mock database (for new items)
    """
    
    # 1. Check Owner's Stock
    docs = db.collection('owners').document(owner_uid).collection('stock').where('sku', '==', barcode).limit(1).stream()
    
    existing = None
    for doc in docs:
        existing = doc.to_dict()
        existing['id'] = doc.id
        break
        
    if existing:
        return {
            "found": True,
            "source": "inventory",
            "data": existing
        }
        
    # 2. Check Mock/Global DB
    if barcode in MOCK_BARCODE_DB:
        return {
            "found": True,
            "source": "global_db",
            "data": MOCK_BARCODE_DB[barcode]
        }
        
    return {"found": False}

def add_stock_item(owner_uid: str, item_data: dict) -> dict:
    """
    Securely adds stock to Firestore.
    """
    try:
        ref = db.collection('owners').document(owner_uid).collection('stock')
        
        # Check duplicate SKU if SKU is provided
        sku = item_data.get('sku')
        if sku:
            existing = ref.where('sku', '==', sku).limit(1).get()
            if len(existing) > 0:
                # Update existing? Or Error? Prompt says "Stock saved via MCP". 
                # Let's simple-add or update logic.
                # If duplicate, we might just update Qty? 
                # For safety, let's treat "Add Stock" as adding *new* item usually, 
                # but if it exists, update quantity.
                doc = existing[0]
                current_qty = float(doc.get('quantity') or 0.0)
                added_qty = float(item_data.get('quantity', 0))
                new_qty = current_qty + added_qty
                doc.reference.update({'quantity': new_qty, 'updatedAt':  item_data.get('updatedAt')})
                return {"status": "updated", "id": doc.id, "new_quantity": new_qty}

        # Create new
        _, new_ref = ref.add(item_data)
        return {"status": "created", "id": new_ref.id}
    except Exception as e:
        raise Exception(f"Database Error: {e}")
