import google.generativeai as genai
from config import settings
import json
import logging

# Configure Logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

# Configure Gemini
if settings.GEMINI_API_KEY:
    genai.configure(api_key=settings.GEMINI_API_KEY)
else:
    logger.warning("GEMINI_API_KEY not found. AI features will be disabled.")

class GeminiService:
    def __init__(self):
        self.model = genai.GenerativeModel(settings.AI_MODEL)
    
    def generate_daily_insight(self, stats: dict, stock_summary: list) -> dict:
        """
        Orchestrates the AI generation process:
        1. Context Preparation
        2. Prompt Engineering
        3. Gemini Call
        4. Cleaning & Parsing
        """
        if not settings.GEMINI_API_KEY:
             return self._fallback_response("AI Key Missing")

        try:
            # 1. Prepare Context
            context_str = json.dumps({
                "sales_data": stats,
                "low_stock_alerts": stock_summary
            }, indent=2)

            # 2. System Prompt
            prompt = f"""
            You are 'DukanX AI', a smart business assistant for a shop owner. 
            Analyze the following JSON data representing today's business.

            DATA:
            {context_str}

            TASK:
            Provide a daily business summary.
            
            RULES:
            1. Output MUST be valid JSON.
            2. Do NOT hallucinate data not present in the input.
            3. Be concise and encouraging.

            OUTPUT FORMAT:
            {{
                "summary": "A 1-2 sentence overview of performance.",
                "highlights": ["List", "of", "key", "points"],
                "suggestions": ["Actionable", "advice", "based", "on", "data"]
            }}
            """

            # 3. Call Gemini
            # Using generation_config to enforce JSON if supported, or just prompting.
            # Gemini 1.5 often respects "Output JSON" instructions well.
            response = self.model.generate_content(
                prompt,
                generation_config=genai.types.GenerationConfig(
                    temperature=0.4,
                    # response_mime_type="application/json" # Valid for 1.5 Pro/Flash
                )
            )

            # 4. Parse Response
            raw_text = response.text
            # Basic cleanup if markdown backticks exist
            if "```json" in raw_text:
                raw_text = raw_text.split("```json")[1].split("```")[0]
            elif "```" in raw_text:
                raw_text = raw_text.split("```")[1].split("```")[0]

            data = json.loads(raw_text.strip())
            
            # Simple Schema Validation (Optional but recommended)
            return {
                "summary": data.get("summary", "No summary available."),
                "highlights": data.get("highlights", []),
                "suggestions": data.get("suggestions", [])
            }

        except Exception as e:
            logger.error(f"Gemini Error: {e}")
            return self._fallback_response(str(e))

    def _fallback_response(self, reason: str = "") -> dict:
        return {
            "summary": "Unable to generate AI insight at this moment.",
            "highlights": ["Data processed successfully", "AI view unavailable"],
            "suggestions": [f"Error: {reason}"]
        }

# Singleton
    def generate_dashboard_insight(self, context_data: dict) -> str:
        """
        Generates a concise, 3-sentence simple language explanation for the dashboard.
        """
        if not settings.GEMINI_API_KEY:
             return "AI Insights are unavailable. Please check your internet or API Key."

        try:
            prompt = f"""
            You are 'DukanX AI'.
            Analyze this daily business snapshot and provide a 3-sentence summary for the shop owner.
            Use simple English. Focus on what matters: Sales, Stock, and Profit.
            
            DATA:
            {json.dumps(context_data, indent=2)}

            OUTPUT FORMAT:
            Just the plain text paragraph. No JSON.
            Example:
            "Tea Powder sold the most today. Sugar stock is low and should be reordered. Cooking Oil sales are slow and causing minor loss."
            """

            response = self.model.generate_content(prompt)
            return response.text.replace("```", "").strip()

        except Exception as e:
            logger.error(f"Gemini Insight Error: {e}")
            return "Could not generate insight at this moment."


    def analyze_product_image(self, image_bytes: bytes) -> dict:
        """
        Analyzes an image to identify the product details (Name, Category).
        Returns a dictionary with suggestions.
        """
        if not settings.GEMINI_API_KEY:
             return self._fallback_response("AI Key Missing")

        try:
            import PIL.Image
            import io
            
            image = PIL.Image.open(io.BytesIO(image_bytes))
            
            prompt = """
            Analyze this product image.
            Identify the Item Name, Category, and if visible, the Brand and Size/Weight.
            
            OUTPUT JSON FORMAT:
            {
                "name": "Concise Product Name (e.g. Maggi Noodles)",
                "category": "Suggested Category (e.g. Snacks, Groceries)",
                "brand": "Brand Name or null",
                "size": "Size with unit or null (e.g. 70g)",
                "description": "Short visual description"
            }
            """
            
            # Gemini Vision Request
            # Note: gemini-1.5-flash supports images.
            response = self.model.generate_content([prompt, image])
            
            raw_text = response.text
             # Basic cleanup
            if "```json" in raw_text:
                raw_text = raw_text.split("```json")[1].split("```")[0]
            elif "```" in raw_text:
                 raw_text = raw_text.split("```")[1].split("```")[0]
                 
            return json.loads(raw_text.strip())

        except Exception as e:
            logger.error(f"Gemini Vision Error: {e}")
            return {
                "name": "", 
                "category": "Uncategorized", 
                "error": "Could not analyze image. Please enter manually."
            }

# Singleton
ai_service = GeminiService()
