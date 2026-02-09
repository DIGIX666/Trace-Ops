const express = require('express');
const cors = require('cors');
const mockData = require('./mockData');

const app = express();
const port = 3000;

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

app.listen(port, () => {
    console.log(`Backend Timeline (Mock Mode) listening on port ${port}`);
});