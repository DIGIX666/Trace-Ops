const { submitDecision, queryDecision } = require('./fabricService.js');
const express = require('express');
const axios = require('axios');
const { expressjwt: jwt } = require('express-jwt');
const jwksRsa = require('jwks-rsa');
const crypto = require('crypto');

const app = express();
const PORT = 3000;
const J2_SERVICE_URL = 'http://backend-j2:8000';   // ← service Python

app.use(express.json());

// ──────────────────────────────────────────────────────────────
// Auth Keycloak (même configuration qu’avant)
// ──────────────────────────────────────────────────────────────
const checkJwt = jwt({
  secret: jwksRsa.expressJwtSecret({
    cache: true,
    rateLimit: true,
    jwksRequestsPerMinute: 5,
    jwksUri: 'http://keycloak:8080/realms/trace-ops/protocol/openid-connect/certs'
  }),
  audience: 'account',
  issuer: [
    'http://localhost:8080/realms/trace-ops',
    'http://keycloak:8080/realms/trace-ops'
  ],
  algorithms: ['RS256']
});

// Base de données en mémoire (remplace l’ancien alerts_db du Python)
let alerts_db = [];

// ──────────────────────────────────────────────────────────────
// Health
// ──────────────────────────────────────────────────────────────
app.get('/health', (_req, res) => {
  res.json({ status: "EM Service Online" });
});

// ──────────────────────────────────────────────────────────────
// GET /alerts
// ──────────────────────────────────────────────────────────────
app.get('/alerts', checkJwt, (req, res) => {
    const userRoles = req.auth.realm_access?.roles || [];

    if (!userRoles.includes('operateur') && !userRoles.includes('decideur')) {
        return res.status(403).json({ error: "Rôle 'operateur' ou 'decideur' requis" });
    }
    res.json(alerts_db);
});

// ──────────────────────────────────────────────────────────────
// POST /alerts  (création d’alerte)
// ──────────────────────────────────────────────────────────────
app.post('/alerts', checkJwt, (req, res) => {
  const userRoles = req.auth.realm_access?.roles || [];

  if (!userRoles.includes('operateur') && !userRoles.includes('decideur')) {
    return res.status(403).json({ error: "Rôle 'operateur' ou 'decideur' requis" });
  }

  const { type, zone, criticality } = req.body;

  const new_alert = {
    id: crypto.randomUUID().slice(0, 8),
    type,
    zone,
    timestamp: new Date().toISOString(),
    criticality,
    status: "NEW",
    aiScore: null,
    aiSummary: null,
    decision: null,
    txHash: null
  };

  alerts_db.push(new_alert);
  res.status(201).json(new_alert);
});

// ──────────────────────────────────────────────────────────────
// POST /analyze/:alert_id  → appelle le service Python
// ──────────────────────────────────────────────────────────────
app.post('/analyze/:alert_id', checkJwt, async (req, res) => {
  const userRoles = req.auth.realm_access?.roles || [];

  if (!userRoles.includes('analyste')) {
    return res.status(403).json({ error: "Rôle 'analyste' requis" });
  }

  const alert_id = req.params.alert_id;
  const alert = alerts_db.find(a => a.id === alert_id);

  if (!alert) {
    return res.status(404).json({ error: "Alert not found" });
  }

  try {
    // Appel du service Python (seulement pour l’IA)
    const { data } = await axios.post(`${J2_SERVICE_URL}/analyze`, {
      zone: alert.zone
    });

    // Mise à jour de l’alerte dans la DB JS
    alert.aiScore = data.aiScore;
    alert.aiSummary = data.aiSummary;
    alert.status = "ANALYZED";

    res.json(alert);
  } catch (error) {
    console.error("Erreur analyse IA :", error.message);
    res.status(500).json({ error: "Failed to run AI analysis" });
  }
});

// ──────────────────────────────────────────────────────────────
// POST /decision  (décision + écriture blockchain simulée)
// ──────────────────────────────────────────────────────────────
app.post('/decision', checkJwt, async (req, res) => {
    const userRoles = req.auth.realm_access?.roles || [];

    if (!userRoles.includes('decideur')) {
        return res.status(403).json({ error: "Rôle 'decideur' requis" });
    }

    const { alertId, decision } = req.body;

    const payloadStr = JSON.stringify(decision);
    const hash = crypto.createHash('sha256').update(payloadStr).digest('hex');

    try { 
        // --- ÉCRITURE ---
        console.log("Envoi de la décision...");
        await submitDecision(alertId, decision, hash);

        // --- LECTURE ---
        console.log("Lecture immédiate...");
        const record = await queryDecision(alertId);
        
        console.log("Record récupéré depuis la Blockchain :");
        console.log(`- ID: ${record.id}`);
        console.log(`- TxID: ${record.txId}`);
        console.log(`- Payload récupéré:`, record.payload);
        
    } catch (error) {
        console.error("Échec :", error.message);
    }

    // --- Il faudra prendre ce que return la DB pour être sûr des données
    const alert = alerts_db.find(a => a.id === alertId);
    if (!alert) {
        return res.status(404).json({ error: "Alert not found" });
    }

    alert.decision = decision;
    alert.txHash = hash;
    alert.status = "DECIDED";
    // ---

    console.log(`Décision enregistrée par ${req.auth.preferred_username} → ${decision}`);

    res.json({
        status: "SUCCESS",
        txHash: hash,
        alertId: alert.id
    });
});

// Gestion des erreurs JWT
app.use((err, _req, res, next) => {
  if (err.name === 'UnauthorizedError') {
    return res.status(401).json({ error: 'Invalid Token: ' + err.message });
  }
  next(err);
});

app.listen(PORT, () => {
  console.log(`✅ EM Service running on port ${PORT}`);
});
