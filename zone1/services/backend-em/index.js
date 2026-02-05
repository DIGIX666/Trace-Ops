const express = require('express');
const axios = require('axios');
const { expressjwt: jwt } = require('express-jwt'); // Attention à la syntaxe v6+
const jwksRsa = require('jwks-rsa');

const app = express();
const PORT = 3000;
const J2_SERVICE_URL = 'http://backend-j2:8000'; // Correction nom variable

app.use(express.json()); // Important pour req.body

// --- CONFIGURATION JWT (La logique Python) ---
// On crée un middleware qui va chercher les clés publiques (JWKS)
// exactement comme ta fonction get_current_user_token en Python
const checkJwt = jwt({
  secret: jwksRsa.expressJwtSecret({
    cache: true,
    rateLimit: true,
    jwksRequestsPerMinute: 5,
    // URL interne Docker pour récupérer les clés
    jwksUri: 'http://keycloak:8080/realms/trace-ops/protocol/openid-connect/certs'
  }),
  audience: 'account', // Ou null si tu veux ignorer
  issuer: [
      'http://localhost:8080/realms/trace-ops', 
      'http://keycloak:8080/realms/trace-ops'
  ], // Vérifie qui a émis le token
  algorithms: ['RS256']
//   requestProperty: 'auth' // Le token décodé sera dans req.auth (ou req.user)
});

app.get('/health', (req, res) => {
    res.json({ status: "EM Service Online" });
});

// Endpoint de Décision
// On remplace keycloak.protect() par checkJwt
app.post('/decision', checkJwt, async (req, res) => {
    
    // Si on est ici, le token est valide (Signature OK)
    // Les infos utilisateur sont dans req.auth
    const userRoles = req.auth.realm_access?.roles || [];
    
    // Check de rôle manuel (Comme ta classe RoleChecker en Python)
    if (!userRoles.includes('decideur')) {
         return res.status(403).json({ error: "Rôle 'decideur' requis" });
    }

    const { alertId, decision } = req.body;
    console.log(`[EM] User ${req.auth.preferred_username} a validé ${alertId}`);

    // --- SIMULATION ZONE 2 (LEDGER) ---
    const crypto = require('crypto');
    const mockTxHash = "0x" + crypto.randomBytes(32).toString('hex');
    
    await new Promise(r => setTimeout(r, 500));

    // --- MISE À JOUR ZONE 1 ---
    try {
        // On transfère le token reçu vers le service Python
        await axios.put(`${J2_SERVICE_URL}/internal/update_decision/${alertId}`, {
            decision: decision,
            txHash: mockTxHash
        }, {
            headers: { Authorization: req.headers.authorization }
        });

        res.json({
            status: "SUCCESS",
            txHash: mockTxHash,
            alertId: alertId
        });

    } catch (error) {
        console.error("Erreur communication J2:", error.message);
        res.status(500).json({ error: "Failed to update local state" });
    }
});

// Gestion des erreurs d'auth (Ex: Token expiré)
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