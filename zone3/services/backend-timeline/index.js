const express = require('express');
const cors = require('cors');
const mockData = require('./mockData');

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

// --- Routes ---

// 1. Healthcheck
app.get('/health', (req, res) => {
    res.json({ status: 'OK', mode: 'MOCK_DATA', zone: 'Zone3' });
});

// 2. Timeline API (Lecture seule)
app.get('/api/timeline', (req, res) => {
    // Simulation d'un délai réseau pour le réalisme (optionnel)
    setTimeout(() => {
        console.log("Fetching timeline data (MOCK)...");
        res.json(mockData);
    }, 500);
});

// 3. Detail API
app.get('/api/timeline/:id', (req, res) => {
    const item = mockData.find(d => d.id === req.params.id);
    if (item) {
        res.json(item);
    } else {
        res.status(404).json({ error: "Event not found" });
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
