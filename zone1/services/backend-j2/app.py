from fastapi import FastAPI
from pydantic import BaseModel

app = FastAPI(title="Trace-OPS J2 - AI Analysis Only")

class AnalyzeRequest(BaseModel):
    zone: str

@app.post("/analyze")
def analyze_alert(request: AnalyzeRequest):
    """Retourne simplement un score et un résumé IA (simulation)."""
    ai_score = random.randint(40, 99)
    ai_summary = f"Analyse J2: Menace potentielle confirmée sur {request.zone}."

    return {
        "aiScore": ai_score,
        "aiSummary": ai_summary
    }