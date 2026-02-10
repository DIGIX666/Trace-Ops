const express = require('express');
const cors = require('cors');
const { pullAllData } = require('./fabricService.js');

const app = express();
const port = 3000;

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

app.listen(port, () => {
    console.log(`Backend Timeline (Mock Mode) listening on port ${port}`);
});