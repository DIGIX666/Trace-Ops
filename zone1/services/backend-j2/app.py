from fastapi import FastAPI, HTTPException, Depends, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from typing import List, Optional
import uuid
import datetime
import random
from jose import jwt, JWTError
import requests

KEYCLOAK_URL = "http://keycloak:8080" # os.getenv("KEYCLOAK_URL")
REALM_NAME = "trace-ops" # os.getenv("REALM_NAME")

JWKS_URL = f"{KEYCLOAK_URL}/realms/{REALM_NAME}/protocol/openid-connect/certs"

app = FastAPI(title="Trace-OPS J2 Service")

security = HTTPBearer()

# Fonction - récupère le token et check si la signature est OK
def get_current_user_token(credentials: HTTPAuthorizationCredentials = Security(security)):
    token = credentials.credentials
    try:
        # Note: En prod, il vaut mieux mettre en cache le résultat de cette requête !
        jwks_client = requests.get(JWKS_URL).json()
        
        payload = jwt.decode(
            token,
            jwks_client,
            algorithms=["RS256"],
            audience="account",
            options={"verify_aud": False} # Mettre à True et configurer 'audience' pour plus de sécu
        )
        return payload
    except JWTError as e:
        raise HTTPException(status_code=401, detail=f"Invalid Token: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail="Keycloak connection failed")

# Classe - vérifie les rôles
class RoleChecker:
    def __init__(self, allowed_roles: List[str]):
        self.allowed_roles = allowed_roles

    def __call__(self, payload: dict = Depends(get_current_user_token)):
        realm_access = payload.get("realm_access", {})
        user_roles = realm_access.get("roles", [])

        for role in self.allowed_roles:
            if role in user_roles:
                return payload
        
        raise HTTPException(status_code=403, detail="Operation not permitted (Missing Role)")

class AlertCreate(BaseModel):
    type: str
    zone: str
    criticality: str

class DecisionUpdate(BaseModel):
    decision: str
    txHash: str

alerts_db = []

# --- ROUTES ---

# Endpoint - vérification de la santé du service
@app.get("/health")
def health():
    return {"status": "J2 Service Online (FastAPI)"}

# Endpoint - GET toutes les alertes
@app.get("/alerts")
def get_alerts():
    return alerts_db

# Endpoint - POST l'ajout / modification des alertes
@app.post("/alerts", status_code=201, dependencies=[Depends(RoleChecker(["operateur", "decideur"]))])
def create_alert(
    alert: AlertCreate, 
):
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

# Endpoint - POST les analyses J2
@app.post("/analyze/{alert_id}", dependencies=[Depends(RoleChecker(["analyste"]))])
def analyze_alert(alert_id: str):
    for a in alerts_db:
        if a["id"] == alert_id:
            a["aiScore"] = random.randint(40, 99)
            a["aiSummary"] = f"Analyse J2: Menace potentielle confirmée sur {a['zone']}."
            a["status"] = "ANALYZED"
            return a
    raise HTTPException(status_code=404, detail="Alert not found")

# Endpoint - Udpate une alerte sur le front
@app.put("/internal/update_decision/{alert_id}")
def update_decision(
    alert_id: str, 
    update: DecisionUpdate,
    user_payload: dict = Depends(RoleChecker(["decideur"])) # Bloque si pas 'manager'
):
    print(f"Mise à jour demandée par {user_payload.get('preferred_username')}")
    
    for a in alerts_db:
        if a["id"] == alert_id:
            a["decision"] = update.decision
            a["txHash"] = update.txHash
            a["status"] = "DECIDED"
            return a
    raise HTTPException(status_code=404, detail="Alert not found")