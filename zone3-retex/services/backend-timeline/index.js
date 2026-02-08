const express = require('express');
const app = express();
const port = 3000;

app.use(express.json());

// Healthcheck endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'OK', zone: 'Zone3', purpose: 'RETEX Timeline' });
});

// Placeholder pour l'API Timeline (Step 04)
app.get('/api/timeline', (req, res) => {
  res.json({ message: "Timeline data endpoint - Not connected to ledger yet" });
});

app.listen(port, () => {
  console.log(`Backend Timeline listening at http://localhost:${port}`);
});