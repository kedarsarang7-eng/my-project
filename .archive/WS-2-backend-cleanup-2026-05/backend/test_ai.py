import asyncio
import os
import logging
from dotenv import load_dotenv

# Force load .env
load_dotenv()

import sys
import io

# Force UTF-8 for Windows console
sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# Configure logging to see errors
logging.basicConfig(level=logging.INFO)

from voice_agent import VoiceAgent

async def test_mahiru():
    print(f"DEBUG: API Key present: {bool(os.getenv('GROQ_API_KEY'))}")
    
    agent = VoiceAgent()
    
    print("--- Test 1: Identity ---")
    res1 = await agent.process_intent("Who are you?", "test_user_123")
    print(res1)
    
    print("\n--- Test 2: Hindi Greeting ---")
    res2 = await agent.process_intent("Namaste Mahiru", "test_user_123")
    print(res2)

    print("\n--- Test 3: Navigation ---")
    res3 = await agent.process_intent("Go to Settings", "test_user_123")
    print(res3)

if __name__ == "__main__":
    asyncio.run(test_mahiru())
