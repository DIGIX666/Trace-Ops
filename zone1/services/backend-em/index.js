const express = require('express');
const axios = require('axios');
const { expressjwt: jwt } = require('express-jwt');
const jwksRsa = require('jwks-rsa');
const { submitDecision, queryDecision } = require('./fabricService');
const crypto = require('crypto');

const app = express();
const PORT = 3000;
const J2_SERVICE_URL = 'http://backend-j2:8000';

app.use(express.json());

// Fonction - récupère le token et check si la signature est OK
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

// Endpoint - vérification de la santé du service
app.get('/health', (_req, res) => {
    res.json({ status: "EM Service Online" });
});

// Endpoint - communique avec la Zone 2 puis met à jour les infos dans la base de donnée
// pour le moment, la zone 2 est simulée et les infos sont simplement envoyé vers l'API python qui met à jour le front
app.post('/decision', checkJwt, async (req, res) => {
    
    const userRoles = req.auth.realm_access?.roles || [];
    
    // Check du rôle
    if (!userRoles.includes('decideur')) {
         return res.status(403).json({ error: "Rôle 'decideur' requis" });
    }

    console.log("Hello World")
    console.log(req.body)

    const { alertId, decision } = req.body;

    const myID = alertId
    const myData = decision

    console.log(myID)
    console.log(myData)
        
    const payloadStr = JSON.stringify(myData);
    const hash = crypto.createHash('sha256').update(payloadStr).digest('hex');

    try {
        // --- ÉCRITURE ---
        console.log("Envoi de la décision...");
        await submitDecision(myID, myData, hash);

        // --- LECTURE ---
        console.log("Lecture immédiate...");
        const record = await queryDecision(myID);
        
        console.log("Record récupéré depuis la Blockchain :");
        console.log(`- ID: ${record.id}`);
        console.log(`- TxID: ${record.txId}`);
        console.log(`- Payload récupéré:`, record.payload);
        
    } catch (error) {
        console.error("Échec :", error.message);
    }
    
    // --- MISE À JOUR ZONE 1 ---
    try {
        await axios.put(`${J2_SERVICE_URL}/internal/update_decision/${alertId}`, {
            decision: decision,
            txHash: mockTxHash
        }, {
            headers: { Authorization: req.headers.authorization }
        });

        res.json({
            status: "SUCCESS",
            txHash: "placeholder",
            alertId: "placeholderma"
        });

    } catch (error) {
        console.error("Erreur communication J2:", error.message);
        res.status(500).json({ error: "Failed to update local state" });
    }
    // --- ---
});

// Middleware - gère les erreurs d'auth
app.use((err, req, res, next) => {
    if (err.name === 'UnauthorizedError') {
      res.status(401).send('Invalid Token: ' + err.message);
    } else {
      next(err);
    }
});

app.listen(PORT, () => {
    console.log('EM Service running on port 3000');
});