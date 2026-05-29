
import logging
import time
from typing import Dict, Any, Optional

logger = logging.getLogger("DialogueManager")

class DialogueManager:
    def __init__(self):
        # In-Memory Storage for Active Sessions
        # Key: user_uid, Value: sessionContext
        self.sessions = {}
        self.SESSION_TIMEOUT = 60 # seconds

    def get_session(self, user_uid: str) -> Dict[str, Any]:
        now = time.time()
        if user_uid in self.sessions:
            # Check timeout
            if now - self.sessions[user_uid]["last_active"] > self.SESSION_TIMEOUT:
                self.clear_session(user_uid)
            else:
                return self.sessions[user_uid]

        # Create new session
        self.sessions[user_uid] = {
            "active": False,
            "intent": None,
            "customerName": None,
            "items": [],
            "payment": {"amount": None, "mode": None},
            "last_question": None,
            "turn_count": 0,
            "last_active": now
        }
        return self.sessions[user_uid]

    def update_session(self, user_uid: str, data: Dict[str, Any]):
        if user_uid in self.sessions:
            current = self.sessions[user_uid]
            # Merge updates
            for key, val in data.items():
                if val is not None:
                    current[key] = val
            current["last_active"] = time.time()
            self.sessions[user_uid] = current

    def clear_session(self, user_uid: str):
        if user_uid in self.sessions:
            self.sessions.pop(user_uid)

    def determine_next_step(self, user_uid: str, text: str, nlu_data: Dict[str, Any]) -> Dict[str, Any]:
        """
        State Machine for Billing Conversation.
        """
        session = self.get_session(user_uid)
        session["last_active"] = time.time()
        
        # 0. Global Interrupts
        if "cancel" in text.lower() or "stop" in text.lower() or "बंद" in text:
            self.clear_session(user_uid)
            return {"text": "Okay boss, cancelled. (ठीक आहे, रद्द केले.)", "action": "cancel"}
        
        # 1. Update Session with extracted NLU data
        self._merge_nlu_to_session(session, nlu_data)
        
        # 2. INTENT DETECTION PHASE
        if not session["intent"]:
            if nlu_data.get("intent"):
                session["intent"] = nlu_data["intent"]
                session["active"] = True
            else:
                session["last_question"] = "intent"
                return {"text": "तुम्हाला काय करायचं आहे? बिल, पेमेंट की रिटर्न? (Bill, Payment or Return?)", "action": "listen"}

        # 3. CUSTOMER PHASE
        if not session["customerName"]:
            session["last_question"] = "customerName"
            return {"text": "ग्राहकाचं नाव सांगा? (Customer Name?)", "action": "listen"}

        # 4. ITEM PHASE (Loop)
        if session["intent"] == "create_bill":
             if not session["items"]:
                 return {"text": "कोणता आयटम ॲड करायचा? (Which item?)", "action": "listen"}
             
             # Check last item completeness
             last_item = session["items"][-1]
             
             # Name likely exists if item added, but check just in case
             if not last_item.get("itemName"):
                  # Should not happen ideally if NLU worked
                  session["items"].pop() 
                  return {"text": "Please say the item name again.", "action": "listen"}

             if not last_item.get("qty"):
                 return {"text": f"'{last_item['itemName']}' चे किती नग? (Quantity?)", "action": "listen"}
                 
             if not last_item.get("price") and not last_item.get("salePrice"): 
                 # 'salePrice' might come from DB. If not, ask.
                 return {"text": f"'{last_item['itemName']}' ची किंमत काय? (Price?)", "action": "listen"}
             
             # If completely valid, check if user wants to finish
             if "confirm" in text.lower() or "save" in text.lower() or "बस" in text.lower() or "done" in text.lower():
                 # Create summary and ask final confirm
                 pass # Fallthrough to Confirmation Phase
             else:
                 # Default loop: Ask for more
                 return {"text": f"Added {last_item['qty']} {last_item['itemName']}. आणखी काही? (Anything else?)", "action": "listen"}

        # 5. CONFIRMATION PHASE
        # Generate Summary
        summary = f"Validating: {session['intent']} for {session['customerName']}. "
        items_summary = ", ".join([f"{i['qty']} {i['itemName']}" for i in session['items']])
        
        return {
            "text": f"Complete. {summary} Items: {items_summary}. Shall I save it?", 
            "action": "confirm",
            "payload": session 
        }

    def _merge_nlu_to_session(self, session, nlu_data):
        # 1. Basic Fields
        if nlu_data.get("intent"): session["intent"] = nlu_data["intent"]
        if nlu_data.get("customerName"): session["customerName"] = nlu_data["customerName"]
        
        # 2. Items Logic - Smart Merge
        new_items = nlu_data.get("items", [])
        
        if new_items:
            # User provided a full item or list of items
            for it in new_items:
                # Basic validation: If just a number, might be an update to previous
                # But NluEngine usually returns structure.
                
                # If NluEngine detected an item without name but with qty/price?
                # That implies context completion.
                if not it.get("itemName") and session["items"]:
                    # Update incomplete last item
                    last = session["items"][-1]
                    if it.get("qty") and not last.get("qty"): last["qty"] = it["qty"]
                    if it.get("price") and not last.get("price"): last["price"] = it["price"]
                else:
                    # New Item
                    session["items"].append(it)
