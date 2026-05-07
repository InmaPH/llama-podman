from fastapi import FastAPI
import httpx
import os

app = FastAPI()

LLAMA_URL = os.getenv("LLAMA_URL", "http://127.0.0.1:8080")

@app.get("/generate")
async def generate(prompt: str):
    async with httpx.AsyncClient() as client:
        response = await client.post(
            f"{LLAMA_URL}/completion",
            json={
                "prompt": prompt,
                "n_predict": 256,
                "temperature": 0.7
            }
        )

    return response.json()