from fastapi import FastAPI, HTTPException, Depends, Security
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from pydantic import BaseModel
from typing import List, Optional
import uuid
import datetime
import random
from jose import jwt, JWTError
import requests

# --- CONFIGURATION KEYCLOAK ---
KEYCLOAK_URL = "http://keycloak:8080" # URL de base de Keycloak
REALM_NAME = "trace-ops"             # Votre Realm
# URL pour récupérer les clés publiques (JWKS)
JWKS_URL = f"{KEYCLOAK_URL}/realms/{REALM_NAME}/protocol/openid-connect/certs"

app = FastAPI(title="Trace-OPS J2 Service")

# --- SÉCURITÉ & DÉPENDANCES ---
security = HTTPBearer()

def get_current_user_token(credentials: HTTPAuthorizationCredentials = Security(security)):
    token = credentials.credentials
    try:
        # 1. Récupération de la clé publique depuis Keycloak (JWKS)
        # Note: En prod, il vaut mieux mettre en cache le résultat de cette requête !
        jwks_client = requests.get(JWKS_URL).json()
        
        # 2. Vérification de la signature et décodage
        # python-jose gère la recherche de la bonne clé 'kid' dans le jwks
        payload = jwt.decode(
            token,
            jwks_client,
            algorithms=["RS256"],
            audience="account", # Par défaut 'account', ou l'ID de votre client si configuré
            options={"verify_aud": False} # Mettre à True et configurer 'audience' pour plus de sécu
        )
        return payload
    except JWTError as e:
        raise HTTPException(status_code=401, detail=f"Invalid Token: {str(e)}")
    except Exception as e:
        raise HTTPException(status_code=500, detail="Keycloak connection failed")

# Classe utilitaire pour vérifier les rôles
class RoleChecker:
    def __init__(self, allowed_roles: List[str]):
        self.allowed_roles = allowed_roles

    def __call__(self, payload: dict = Depends(get_current_user_token)):
        # Keycloak met les rôles à deux endroits possibles :
        # 1. realm_access.roles (Rôles globaux)
        # 2. resource_access.{client_id}.roles (Rôles spécifiques au client)
        
        # Ici on vérifie les rôles du Realm (exemple simple)
        realm_access = payload.get("realm_access", {})
        user_roles = realm_access.get("roles", [])

        # Vérifie si l'un des rôles requis est présent
        for role in self.allowed_roles:
            if role in user_roles:
                return payload # Accès autorisé
        
        raise HTTPException(status_code=403, detail="Operation not permitted (Missing Role)")

# --- MODÈLES ---
class AlertCreate(BaseModel):
    type: str
    zone: str
    criticality: str

class DecisionUpdate(BaseModel):
    decision: str
    txHash: str

alerts_db = []

# --- ROUTES ---

@app.get("/health")
def health():
    return {"status": "J2 Service Online (FastAPI)"}

# Exemple : Route publique (ou authentifiée simple sans rôle précis)
@app.get("/alerts")
def get_alerts():
    return alerts_db

# Exemple : Route protégée (nécessite juste d'être connecté)
@app.post("/alerts", status_code=201, dependencies=[Depends(RoleChecker(["operateur", "decideur"]))])
def create_alert(
    alert: AlertCreate, 
    # user_info: dict = Depends(get_current_user_token) # Vérifie juste le token
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

# Exemple : Route protégée avec RÔLE (analyst uniquement)
@app.post("/analyze/{alert_id}", dependencies=[Depends(RoleChecker(["analyste"]))])
def analyze_alert(alert_id: str):
    for a in alerts_db:
        if a["id"] == alert_id:
            a["aiScore"] = random.randint(40, 99)
            a["aiSummary"] = f"Analyse J2: Menace potentielle confirmée sur {a['zone']}."
            a["status"] = "ANALYZED"
            return a
    raise HTTPException(status_code=404, detail="Alert not found")

# --- LA ROUTE APPELÉE PAR NODE JS ---
# Ici, Node.js doit passer le token.
# On vérifie que celui qui a déclenché l'action a le rôle 'manager'.
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