
import logging
import json
import os
from typing import Dict, Any, List
from groq import AsyncGroq

logger = logging.getLogger("DataValidator")

class DataValidator:
    def __init__(self, api_key: str):
        self.client = AsyncGroq(api_key=api_key)
        self.model = "llama-3.1-8b-instant"

        self.SYSTEM_PROMPT = """
You are an NLP validation and error-handling engine for a voice-based billing system.
Your task is to analyze extracted intent JSON and determine whether the data is COMPLETE or INCOMPLETE.

RULES:
1. NEVER guess missing values.
2. Validate required fields.
3. If missing, status = "INCOMPLETE" & ask a SHORT follow-up question.
4. If complete, status = "COMPLETE".
5. Output strict JSON only.

REQUIRED FIELDS:
SALE: customerName, items (at least 1 with name, qty, price)
PAYMENT: customerName, amount, mode (can assume CASH if unspecified but amount is mandatory)
SALE_RETURN: customerName, items
ESTIMATE: customerName, items

OUTPUT FORMAT:
{
  "status": "COMPLETE" | "INCOMPLETE",
  "missingFields": ["price", "customerName"],
  "followUpQuestion": "What is the price of Rice?"
}
"""

    async def validate_data(self, user_text: str, extracted_json: Dict[str, Any]) -> Dict[str, Any]:
        """
        Validates the extracted JSON against required fields.
        Returns JSON with status and follow-up question if needed.
        """
        try:
            # Prepare contextual input
            context = {
                "user_input": user_text,
                "extracted_data": extracted_json
            }
            
            completion = await self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": self.SYSTEM_PROMPT},
                    {"role": "user", "content": json.dumps(context)}
                ],
                temperature=0.0,
                response_format={"type": "json_object"},
                max_tokens=256
            )
            
            raw_content = completion.choices[0].message.content
            logger.debug(f"Validator Output: {raw_content}")
            
            return json.loads(raw_content)

        except Exception as e:
            logger.error(f"Validation Error: {e}")
            # Fallback: Assume complete to avoid blocking, or error
            return {
                "status": "ERROR",
                "missingFields": [],
                "followUpQuestion": f"I encountered an error validating the data: {str(e)}"
            }
