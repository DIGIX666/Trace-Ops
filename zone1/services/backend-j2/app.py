from fastapi import FastAPI, HTTPException, Depends, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from typing import List, Optional
import uuid
import datetime
import random
from jose import jwt, JWTError
import requests
import os

# --- CONFIGURATION ---
KEYCLOAK_URL = os.getenv("KEYCLOAK_URL")
REALM_NAME = os.getenv("REALM_NAME")
JWKS_URL = f"{KEYCLOAK_URL}/realms/{REALM_NAME}/protocol/openid-connect/certs"

# Configuration CouchDB (Zone 2)
# Note: 'couchdb-j2' doit être résoluble via le réseau Docker
COUCHDB_URL = os.getenv("COUCHDB_URL")
DB_NAME = os.getenv("DB_NAME")

app = FastAPI(title="Trace-OPS J2 Service")
security = HTTPBearer()

# --- UTILS & AUTH ---

def get_current_user_token(credentials: HTTPAuthorizationCredentials = Security(security)):
    token = credentials.credentials
    try:
        jwks_client = requests.get(JWKS_URL).json()
        payload = jwt.decode(
            token,
            jwks_client,
            algorithms=["RS256"],
            audience="account",
            options={"verify_aud": False}
        )
        return payload
    except JWTError as e:
        raise HTTPException(status_code=401, detail=f"Invalid Token: {str(e)}")
    except Exception:
        raise HTTPException(status_code=500, detail="Keycloak connection failed")

class RoleChecker:
    def __init__(self, allowed_roles: List[str]):
        self.allowed_roles = allowed_roles

    def __call__(self, payload: dict = Depends(get_current_user_token)):
        user_roles = payload.get("realm_access", {}).get("roles", [])
        if any(role in user_roles for role in self.allowed_roles):
            return payload
        raise HTTPException(status_code=403, detail="Operation not permitted")

def get_ledger_data():
    """Récupère les documents depuis CouchDB Zone 2"""
    try:
        # On utilise _all_docs avec include_docs=true pour avoir les données
        url = f"{COUCHDB_URL}/{DB_NAME}/_all_docs?include_docs=true"
        response = requests.get(url, timeout=2)
        
        if response.status_code == 404:
            # La base n'existe pas encore (chaincode non déployé)
            return []
            
        data = response.json()
        # On extrait les documents en ignorant les IDs techniques de Fabric (ceux qui commencent par \x00)
        docs = []
        for row in data.get("rows", []):
            doc = row.get("doc")
            if doc and not doc["_id"].startswith("_"):
                docs.append(doc)
        return docs
    except Exception as e:
        print(f"Erreur CouchDB: {e}")
        return []

# --- MODÈLES ---

class AlertCreate(BaseModel):
    type: str
    zone: str
    criticality: str

class DecisionUpdate(BaseModel):
    decision: str
    txHash: str

# Simulation d'une DB locale pour les alertes en attente
alerts_db = []

# --- ROUTES MODIFIÉES ---

@app.get("/alerts")
def get_alerts():
    """Retourne les alertes combinant la DB locale et le Ledger"""
    # Pour le POC, on va chercher ce qui est écrit sur le Ledger
    ledger_alerts = get_ledger_data()
    
    if not ledger_alerts:
        # Si le Ledger est vide ou inaccessible, on peut retourner 
        # une liste vide ou tes alertes temporaires
        return {"source": "cache_local", "data": alerts_db}
        
    return {"source": "ledger", "data": ledger_alerts}

@app.get("/health")
def health():
    try:
        # Vérifie si le service CouchDB est joignable
        res = requests.get(f"{COUCHDB_URL}/_up", timeout=1)
        db_status = "connected" if res.status_code == 200 else "issue"
    except:
        db_status = "unreachable"

    return {
        "status": "J2 Service Online",
        "zone2_db": db_status,
        "target_db": DB_NAME
    }

@app.post("/alerts", status_code=201, dependencies=[Depends(RoleChecker(["operateur", "decideur"]))])
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

@app.post("/analyze/{alert_id}", dependencies=[Depends(RoleChecker(["analyste"]))])
def analyze_alert(alert_id: str):
    for a in alerts_db:
        if a["id"] == alert_id:
            a["aiScore"] = random.randint(40, 99)
            a["aiSummary"] = f"Analyse J2: Menace potentielle confirmée sur {a['zone']}."
            a["status"] = "ANALYZED"
            return a
    raise HTTPException(status_code=404, detail="Alert not found")

@app.put("/internal/update_decision/{alert_id}")
def update_decision(
    alert_id: str, 
    update: DecisionUpdate,
    user_payload: dict = Depends(RoleChecker(["decideur"]))
):
    """
    Cette route met à jour le front ET devrait normalement 
    déclencher une transaction vers le Ledger (Zone 2).
    """
    for a in alerts_db:
        if a["id"] == alert_id:
            a["decision"] = update.decision
            a["txHash"] = update.txHash
            a["status"] = "DECIDED"
            
            # TODO: Intégrer Fabric SDK ici pour persister dans le Ledger
            # payload_ledger = {"id": alert_id, "decision": update.decision, "by": user_payload.get('preferred_username')}
            
            return a
    raise HTTPException(status_code=404, detail="Alert not found")

@app.get("/ledger/verify/{tx_id}", dependencies=[Depends(RoleChecker(["analyste", "decideur"]))])
def verify_on_ledger(tx_id: str):
    """
    Route directe pour consulter le World State dans CouchDB (Zone 2)
    """
    try:
        # On interroge CouchDB directement pour vérifier si la donnée existe
        # Note: Le nom du document dans CouchDB dépend de comment le chaincode l'enregistre
        response = requests.get(f"{COUCHDB_URL}/{DB_NAME}/{tx_id}")
        if response.status_code == 200:
            return response.json()
        raise HTTPException(status_code=404, detail="Transaction not found on Ledger")
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error connecting to Zone 2 Ledger: {str(e)}")