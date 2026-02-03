const express = require('express');
const axios = require('axios'); // Pour appeler le conteneur Python
const cors = require('cors');
const crypto = require('crypto');

const app = express();
app.use(express.json());
app.use(cors());

// URL du service Python dans le réseau Docker interne
// "backend-j2" est le nom du service dans docker-compose
const J2_SERVICE_URL = 'http://backend-j2:8000'; 

app.get('/health', (req, res) => {
    res.json({ status: "EM Service Online" });
});

// Endpoint de Décision (Appelé par l'interface EM)
app.post('/decision', async (req, res) => {
    const { alertId, decision } = req.body;

    console.log(`[EM] Reçu décision pour ${alertId}: ${decision}`);

    // --- SIMULATION ZONE 2 (LEDGER) ---
    // 1. On génère un faux hash de transaction Hyperledger
    const mockTxHash = "0x" + crypto.randomBytes(32).toString('hex');
    console.log(`[EM] Simulation envoi Ledger... TX: ${mockTxHash}`);

    // 2. On attend un peu pour simuler la latence réseau/blockchain
    await new Promise(r => setTimeout(r, 500)); 

    // --- MISE À JOUR ZONE 1 ---
    // On informe le backend J2 que la décision est actée
    try {
        await axios.put(`${J2_SERVICE_URL}/internal/update_decision/${alertId}`, {
            decision: decision,
            txHash: mockTxHash
        });

        // On renvoie le résultat au Frontend
        res.json({
            status: "SUCCESS",
            message: "Decision anchored in Ledger (Simulated)",
            txHash: mockTxHash,
            alertId: alertId
        });

    } catch (error) {
        console.error("Erreur communication J2:", error.message);
        res.status(500).json({ error: "Failed to update local state" });
    }
});

app.listen(3000, () => {
    console.log('EM Service running on port 3000');
});