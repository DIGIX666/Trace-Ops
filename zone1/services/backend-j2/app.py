from fastapi import FastAPI, HTTPException
from pydantic import BaseModel
from typing import List, Optional
import uuid
import datetime
import random

app = FastAPI(title="Trace-OPS J2 Service")

class AlertCreate(BaseModel):
    type: str
    zone: str
    criticality: str

alerts_db = []

@app.get("/health")
def health():
    return {"status": "J2 Service Online (FastAPI)"}

@app.get("/alerts")
def get_alerts():
    return alerts_db

@app.post("/alerts", status_code=201)
def create_alert(alert: AlertCreate):
    new_alert = {
        "id": str(uuid.uuid4())[:8],
        "type": alert.type,
        "zone": alert.zone,
        "timestamp": datetime.datetime.now().isoformat(),
        "criticality": alert.criticality,
        "status": "NEW",
        "aiScore": None,
        "aiSummary": None,
        "decision": None,
        "txHash": None
    }
    alerts_db.append(new_alert)
    return new_alert

@app.post("/analyze/{alert_id}")
def analyze_alert(alert_id: str):
    for a in alerts_db:
        if a["id"] == alert_id:
            a["aiScore"] = random.randint(40, 99)
            a["aiSummary"] = f"Analyse J2: Menace potentielle confirmée sur {a['zone']}."
            a["status"] = "ANALYZED"
            return a
    raise HTTPException(status_code=404, detail="Alert not found")

class DecisionUpdate(BaseModel):
    decision: str
    txHash: str

@app.put("/internal/update_decision/{alert_id}")
def update_decision(alert_id: str, update: DecisionUpdate):
    for a in alerts_db:
        if a["id"] == alert_id:
            a["decision"] = update.decision
            a["txHash"] = update.txHash
            a["status"] = "DECIDED"
            return a
    raise HTTPException(status_code=404, detail="Alert not found")