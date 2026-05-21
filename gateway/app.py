from fastapi import FastAPI
import httpx
import asyncio
import os

app = FastAPI()

LLAMA_URL = os.getenv("LLAMA_URL", "http://llama:8080")


@app.get("/generate")
async def generate(prompt: str):
    async with httpx.AsyncClient(timeout=60) as client:

        for _ in range(10):
            try:
                r = await client.post(
                    f"{LLAMA_URL}/completion",
                    json={
                        "prompt": prompt,
                        "n_predict": 256,
                        "temperature": 0.7
                    }
                )
                return r.json()

            except Exception:
                await asyncio.sleep(2)

        return {"error": "llama not available"}