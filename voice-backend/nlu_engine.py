
import logging
import json
import os
from typing import Dict, Any, Optional
from groq import AsyncGroq

logger = logging.getLogger("NluEngine")

class NluEngine:
    def __init__(self, api_key: str):
        self.client = AsyncGroq(api_key=api_key)
        self.model = "llama-3.1-8b-instant"
        
        self.SYSTEM_PROMPT = """
You are an NLP engine for a business billing application.
Your job is to analyze user speech or text and convert it into a STRICT, CLEAN JSON object that can be directly used by the backend.

-------------------------------
SUPPORTED LANGUAGES
-------------------------------
- Marathi
- Hindi
- English
- Hinglish / Mix language

-------------------------------
SUPPORTED INTENTS
-------------------------------
- SALE
- PAYMENT
- SALE_RETURN
- ESTIMATE
- SALE_ORDER
- DELIVERY_CHALLAN

-------------------------------
EXTRACTION RULES
-------------------------------
1. Detect the main intent (only ONE intent).
2. Extract customer name if mentioned.
3. Extract items:
   - itemName
   - quantity (number)
   - price (per unit)
4. Extract payment details if mentioned:
   - amount
   - mode (CASH | UPI | BANK | CARD)
5. If payment not mentioned, set payment as null.
6. If price is missing, keep price as null.
7. If quantity is missing, assume qty = 1.
8. Do NOT guess values.
9. Do NOT add extra explanation text.
10. Output ONLY valid JSON.

-------------------------------
OUTPUT JSON FORMAT (MANDATORY)
-------------------------------
{
  "intent": "SALE" | "PAYMENT" | ...,
  "customerName": "Name" | null,
  "items": [
    {
      "itemName": "Item Name",
      "qty": 1,
      "price": 100
    }
  ],
  "payment": {
    "amount": 500,
    "mode": "CASH"
  }
}
"""

    async def analyze_text(self, text: str) -> Dict[str, Any]:
        """
        Extracts structured billing data from natural language text.
        Returns a dictionary matching the strict JSON format.
        """
        try:
            logger.info(f"🔍 Analyzing text with NLU Engine: {text}")
            
            completion = await self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": self.SYSTEM_PROMPT},
                    {"role": "user", "content": text}
                ],
                temperature=0.0, # Zero temperature for strict deterministic output
                response_format={"type": "json_object"},
                max_tokens=512
            )
            
            raw_content = completion.choices[0].message.content
            logger.debug(f"NLU Raw Output: {raw_content}")
            
            parsed = json.loads(raw_content)
            
            # Normalize structure if needed (ensure minimal keys exist)
            if "items" not in parsed: parsed["items"] = []
            if "payment" not in parsed: parsed["payment"] = None
            
            return parsed

        except Exception as e:
            logger.error(f"NLU Extraction Failed: {e}")
            # Return a safe fallback or re-raise
            return {
                "intent": "UNKNOWN",
                "customerName": null, 
                "items": [], 
                "payment": null,
                "error": str(e)
            }
