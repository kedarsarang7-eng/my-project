
import logging
import json
import os
from typing import Dict, Any, List
from groq import AsyncGroq

logger = logging.getLogger("NaturalVoiceGenerator")

class NaturalVoiceGenerator:
    def __init__(self, api_key: str):
        self.client = AsyncGroq(api_key=api_key)
        self.model = "llama-3.1-8b-instant"

        self.SYSTEM_PROMPT = """
You are Mahiru, a friendly female voice assistant.
Your voice must sound Warm, Calm, Caring, and Human-like.

RULES:
1. Speak slightly slower, polite, soft.
2. Add natural pauses (,).
3. Use the USER'S LANGUAGE (Hindi/Marathi/English/Hinglish).
4. Short sentences. No technical terms.
5. Tone:
   - GREETING: Warm, smiling.
   - QUESTION: Polite, curious.
   - CONFIRMATION: Reassuring.
   - SUCCESS: Happy, positive.

OUTPUT: Return ONLY the spoken text string. No JSON. No Emojis.
"""

    async def generate_response(self, text_content: str, context_type: str = "general") -> str:
        """
        Refines the raw text response into a 'Mahiru Style' natural speech string.
        """
        try:
            # Context allows enforcing tone (e.g. 'error', 'success', 'question')
            prompt = f"Convert this system text into a natural, warm spoken response for a user (Type: {context_type}): '{text_content}'"
            
            completion = await self.client.chat.completions.create(
                model=self.model,
                messages=[
                    {"role": "system", "content": self.SYSTEM_PROMPT},
                    {"role": "user", "content": prompt}
                ],
                temperature=0.7, # Higher temp for natural variation
                max_tokens=128
            )
            
            spoken_text = completion.choices[0].message.content.strip()
            # Remove any quotes if LLM adds them
            spoken_text = spoken_text.replace('"', '').replace("'", "")
            return spoken_text

        except Exception as e:
            logger.error(f"Voice Gen Failed: {e}")
            return text_content # Fallback to original text
