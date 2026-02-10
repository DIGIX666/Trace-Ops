const express = require('express');
const cors = require('cors');
const { pullAllData } = require('./fabricService.js');

const app = express();
const port = 3000;

const buildMockBlocks = () => {
    const sorted = [...mockData].sort((a, b) => new Date(a.timestamp) - new Date(b.timestamp));
    return sorted.map((tx, index) => ({
        blockNumber: index + 1,
        txId: tx.id,
        channel: 'traceops',
        timestamp: tx.timestamp,
        type: tx.type,
        status: tx.status,
        author: tx.author,
        payload: tx.content
    }));
};

app.use(cors()); // Important pour que le Frontend Vue puisse appeler l'API
app.use(express.json());

var data

// --- Routes ---

// 1. Healthcheck
app.get('/health', (req, res) => {
    res.json({ status: 'OK', mode: 'MOCK_DATA', zone: 'Zone3' });
});

// 2. Timeline API (Lecture seule)
app.get('/api/timeline', async (req, res) => {
    try {
        console.log("Pulling Data from Fabric")
        data = await pullAllData();
        res.json(data);
    } catch(err) {
        console.log("Erreur pulling data from fabric : ", err)
    }
});

// 4. TraceScan API (MVP)
app.get('/api/tracescan/blocks', (req, res) => {
    const blocks = buildMockBlocks();
    res.json(blocks);
});

app.get('/api/tracescan/tx/:txId', (req, res) => {
    const blocks = buildMockBlocks();
    const tx = blocks.find((b) => b.txId === req.params.txId);
    if (tx) {
        res.json(tx);
    } else {
        res.status(404).json({ error: 'Transaction not found' });
    }
});

app.listen(port, () => {
    console.log(`Backend Timeline (Mock Mode) listening on port ${port}`);
});
