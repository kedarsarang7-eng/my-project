
import logging
import json
import os
from typing import Dict, Any, List
from dotenv import load_dotenv
from groq import AsyncGroq
from query_engine import query_engine  # NEW: Import QueryEngine

load_dotenv()

logger = logging.getLogger("VoiceAgent")

class VoiceAgent:
    def __init__(self):
        self.api_key = os.getenv("GROQ_API_KEY")
        if not self.api_key:
            logger.error("❌ GROQ_API_KEY not found in environment variables!")
        
        self.client = AsyncGroq(
            api_key=self.api_key,
        )
        self.model = "llama-3.1-8b-instant" 
        
        # In-memory history: { "user_uid": [ {"role": "user", "content": "..."}, ... ] }
        self.conversation_history: Dict[str, List[Dict[str, str]]] = {}

        self.SYSTEM_PROMPT = """
You are IMMORTAL — a calm, accurate, and trustworthy Indian voice assistant designed for voice-based billing in real shop environments.

Your primary responsibility is to help the user create bills accurately using voice, even with imperfect on-device speech recognition.
Accuracy, confirmation, and clarity are more important than speed.

────────────────────────
CORE BEHAVIOR
────────────────────────
- Speak calmly and clearly.
- Use simple, polite Indian-English.
- Never rush the user.
- Assume background noise and STT errors are possible.
- Prefer short questions and short answers.
- Always confirm before taking billing actions.

Never guess values.
Never auto-add items without confirmation.

────────────────────────
VOICE BILLING MODE (DEFAULT)
────────────────────────
Voice billing must follow a STEP-BY-STEP guided flow.
Correct flow:
1) Item name
2) Quantity
3) Price per unit
4) Confirmation
5) Add to bill

────────────────────────
CAPABILITIES (TOOLS)
────────────────────────
You must output JSON to trigger these tools:
1. "create_bill": Start a new bill or add items. Args: {"action": "add_item", "item": "name", "qty": 1, "price": 100} OR {"action": "generate_bill"}
2. "check_dues": Check pending balance. Args: {"name": "customer_name"}
3. "check_stock": Check inventory. Args: {"product_name": "product_name"}
4. "check_sales": Check sales stats. Args: {"period": "today" | "week" | "month"}
5. "navigate": Open screen. Args: {"screen": "home" | "billing" | "inventory" | "settings"}
6. "run_query": Execute business analytics query. Args: {"question": "user question"}

────────────────────────
CONFIRMATION RULE (MANDATORY)
────────────────────────
Before adding any item (triggering create_bill), always confirm:
"I am adding: <item>, Qty: <qty>, Price: <price>. Should I add this?"
Only proceed if user says YES.

────────────────────────
OUTPUT FORMAT
────────────────────────
ALWAYS return a valid JSON object.
Example 1 (Conversation): { "text": "What is the item name?", "intent": "conversation", "data": null }
Example 2 (Action): { "text": "Adding Milk to bill.", "intent": "create_bill", "data": {"action": "add_item", "item": "Milk", "qty": 2, "price": 40} }
Example 3 (Query): { "text": "Checking sales...", "intent": "run_query", "data": {"question": "total sales today"} }
"""

    async def process_intent(self, text: str, user_uid: str) -> Dict[str, Any]:
        """
        Main entry point. Uses Context-Aware LLM generation.
        """
        logger.info(f"🧠 Processing: {text} (User: {user_uid})")

        # 1. Initialize History
        if user_uid not in self.conversation_history:
            self.conversation_history[user_uid] = []
        
        # 2. Add System Prompt (Dynamic or Static)
        messages = [{"role": "system", "content": self.SYSTEM_PROMPT}]
        
        # 3. Append History (Limit to last 10 turns to save tokens)
        history = self.conversation_history[user_uid][-10:]
        messages.extend(history)
        
        # 4. Add Current User Message
        messages.append({"role": "user", "content": text})

        final_response = None
        
        # 5. Call LLM (Groq)
        try:
            completion = await self.client.chat.completions.create(
                model=self.model,
                messages=messages,
                temperature=0.3,
                max_tokens=256,
                response_format={"type": "json_object"}
            )
            response_content = completion.choices[0].message.content
            
            # 6. Parse JSON
            try:
                parsed = json.loads(response_content)
                final_response = {
                    "text": parsed.get("text", ""),
                    "intent": parsed.get("intent", "conversation"), 
                    "data": parsed.get("data", parsed.get("parameters", {})) # Handle variations
                }
            except json.JSONDecodeError:
                # Fallback if LLM messes up JSON
                logger.warning(f"Invalid JSON from LLM: {response_content}")
                final_response = {"text": response_content, "intent": "conversation", "data": None}

        except Exception as e:
            logger.error(f"Groq Error: {str(e)}")
            final_response = {"text": "I'm having trouble connecting to my brain.", "intent": "error", "data": {"error": str(e)}}

        # 7. Handle run_query intent - Execute the query!
        if final_response.get("intent") == "run_query":
            question = final_response.get("data", {}).get("question", text)
            logger.info(f"📊 Executing Query: {question}")
            
            try:
                query_result = await query_engine.run_query(user_uid, question)
                
                # Replace the placeholder response with actual result
                final_response["text"] = query_result.get("text", "Query completed.")
                final_response["data"] = query_result.get("data")
                
                if not query_result.get("success"):
                    final_response["intent"] = "query_failed"
                else:
                    final_response["intent"] = "query_result"
                    
            except Exception as e:
                logger.error(f"Query Execution Error: {e}")
                final_response["text"] = f"Sorry, I couldn't run that query: {str(e)}"
                final_response["intent"] = "query_failed"

        # 8. Update History
        # Add User Message
        self.conversation_history[user_uid].append({"role": "user", "content": text})
        # Add Assistant Message (Strict text content)
        assistant_text = final_response.get("text", "")
        self.conversation_history[user_uid].append({"role": "assistant", "content": assistant_text})

        # 9. Natural Voice Humanization (Optional Polish)
        # For business queries, we want precision, so we might skip re-humanizing logic 
        # that could hallucinate data, but we can keep it for "conversation" intent.
        
        return final_response

