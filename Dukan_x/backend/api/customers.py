from fastapi import APIRouter, Depends, HTTPException, Body
from core.auth import verify_token
from core.database import db
from models.customer import CustomerLinkRequest
from firebase_admin import firestore
import json

router = APIRouter()

@router.post("/link-shop")
async def link_customer_shop(
    payload: CustomerLinkRequest,
    user: dict = Depends(verify_token)
):
    """
    Securely links a customer to a shop via QR Code.
    Auto-creates customer account if it doesn't exist.
    """
    qr_data = payload.qr_data
    
    shop_id = qr_data.get("shopId") or qr_data.get("ownerUid")
    if not shop_id:
        raise HTTPException(status_code=400, detail="Invalid QR: Missing Shop ID")

    cust_ref = db.collection('customers').document(user['uid'])
    
    try:
        doc = cust_ref.get()
        if not doc.exists:
            # Create new customer
            new_cust = {
                "id": user['uid'],
                "linkedShopIds": [shop_id],
                "linkedOwnerId": shop_id, # Legacy
                "createdAt": firestore.SERVER_TIMESTAMP,
                "email": user.get("email", ""),
                "name": user.get("name", "") or "Customer",
                "phone": user.get("phone_number", ""),
                "totalDues": 0.0
            }
            cust_ref.set(new_cust)
        else:
            # Update existing
            data = doc.to_dict()
            current_links = data.get("linkedShopIds", [])
            if not isinstance(current_links, list):
                current_links = []
                
            if shop_id not in current_links:
                current_links.append(shop_id)
                updates = {"linkedShopIds": current_links}
                if not data.get("linkedOwnerId"):
                    updates["linkedOwnerId"] = shop_id
                cust_ref.update(updates)
                
        return {"status": "success", "message": f"Successfully linked to Shop {shop_id}"}
        
    except Exception as e:
        print(f"Linking Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))
