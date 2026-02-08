require('dotenv').config();

const { pushData, pullData } = require('./fabricService.js');
const express = require('express');
const axios = require('axios');
const { expressjwt: jwt } = require('express-jwt');
const jwksRsa = require('jwks-rsa');
const crypto = require('crypto');

const app = express();
const PORT = process.env.PORT;
const J2_SERVICE_URL = process.env.J2_SERVICE_URL;   // service Python

const { Pool } = require('pg');

const pool = new Pool({
  host: process.env.DATABASE_HOST,
  port: parseInt(process.env.DATABASE_PORT),
  database: process.env.DATABASE_NAME,
  user: process.env.DATABASE_USER,
  password: process.env.DATABASE_PASSWORD,
});

async function initDatabase() {
  try {
    // await pool.query(`DROP TABLE IF EXISTS alertes;`);
    await pool.query(`
      CREATE TABLE IF NOT EXISTS alertes (
        id              TEXT PRIMARY KEY,               -- on garde les UUID courts en TEXT
        created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
        is_analysed     BOOLEAN NOT NULL DEFAULT FALSE,
        ai_percentage   REAL,                             -- score IA (0-100 par ex)
        alert_data      JSONB NOT NULL,                   -- toutes les autres infos ici
        status          TEXT NOT NULL DEFAULT 'NEW'
      );

      -- Index utiles
      CREATE INDEX IF NOT EXISTS idx_alertes_status     ON alertes(status);
      CREATE INDEX IF NOT EXISTS idx_alertes_created_at ON alertes(created_at DESC);
      CREATE INDEX IF NOT EXISTS idx_alertes_ai_perc    ON alertes(ai_percentage);
    `);

    console.log("✅ Table 'alertes' prête");

    // Petit check santé
    const res = await pool.query(`SELECT 1`);
    if (res.rowCount !== 1) throw new Error("Échec test connexion DB");

    console.log("✅ DB Service Online");
  } catch (err) {
    console.error("Erreur initialisation DB :", err);
    process.exit(1); // ou autre stratégie selon votre tolérance
  }
}

// Lancement init DB au démarrage
initDatabase().catch(err => {
  console.error("Échec init DB au démarrage", err);
  process.exit(1);
});

app.use(express.json());

// ──────────────────────────────────────────────────────────────
// Authentification Keycloak
// ──────────────────────────────────────────────────────────────
const checkJwt = jwt({
  secret: jwksRsa.expressJwtSecret({
    cache: true,
    rateLimit: true,
    jwksRequestsPerMinute: 5,
    jwksUri: process.env.KEYCLOAK_JWKS_URI
  }),
  audience: process.env.KEYCLOAK_AUDIENCE,
  issuer: [
    'http://localhost:8080/realms/trace-ops',
    process.env.KEYCLOAK_ISSUER
  ],
  algorithms: ['RS256']
});

// ──────────────────────────────────────────────────────────────
// Health
// ──────────────────────────────────────────────────────────────
app.get('/health', (_req, res) => {
  res.json({ status: "EM Service Online" });
});

// ──────────────────────────────────────────────────────────────
// GET /alerts
// ──────────────────────────────────────────────────────────────
app.get('/alerts', checkJwt, async (req, res) => {
  const userRoles = req.auth.realm_access?.roles || [];

  if (!userRoles.includes('operateur') && !userRoles.includes('decideur')) {
    return res.status(403).json({ error: "Rôle 'operateur' ou 'decideur' requis" });
  }

  try {
    const result = await pool.query(`
      SELECT 
        id,
        created_at,
        status,
        ai_percentage,
        alert_data
      FROM alertes
      ORDER BY created_at DESC
      LIMIT 200
    `);

    const alerts = result.rows.map(row => ({
      id: row.id,
      ...row.alert_data,
      status: row.status,
      aiScore: row.ai_percentage,
      created_at: row.created_at
    }));

    res.json(alerts);
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Database error" });
  }
});

// ──────────────────────────────────────────────────────────────
// POST /alerts
// ──────────────────────────────────────────────────────────────
app.post('/alerts', checkJwt, async (req, res) => {
  const userRoles = req.auth.realm_access?.roles || [];

  if (!userRoles.includes('operateur') && !userRoles.includes('decideur')) {
    return res.status(403).json({ error: "Rôle 'operateur' ou 'decideur' requis" });
  }

  const { type, zone, criticality } = req.body;

  const alertId = crypto.randomUUID().slice(0, 8);
  const timestamp = new Date().toISOString();

  const alertData = {
    type,
    zone,
    timestamp,
    criticality,
    aiSummary: null,
    decision: null
  };

  try {
    await pool.query(`
      INSERT INTO alertes (id, alert_data, status, is_analysed)
      VALUES ($1, $2, 'NEW', FALSE)
    `, [alertId, alertData]);

    res.status(201).json({
      id: alertId,
      ...alertData,
      status: "NEW",
      aiScore: null
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: "Failed to create alert" });
  }
});

// ──────────────────────────────────────────────────────────────
// POST /analyze/:alert_id
// ──────────────────────────────────────────────────────────────
app.post('/analyze/:alert_id', checkJwt, async (req, res) => {
  const userRoles = req.auth.realm_access?.roles || [];

  if (!userRoles.includes('analyste')) {
    return res.status(403).json({ error: "Rôle 'analyste' requis" });
  }

  const { alert_id } = req.params;

  try {
    const result = await pool.query(`
      SELECT alert_data, status 
      FROM alertes 
      WHERE id = $1
    `, [alert_id]);

    if (result.rowCount === 0) {
      return res.status(404).json({ error: "Alert not found" });
    }

    const alert = result.rows[0];

    // Appel service IA Python
    const { data } = await axios.post(`${J2_SERVICE_URL}/analyze`, {
      zone: alert.alert_data.zone
    });

    // ──────────────── Défenses ────────────────
    const aiPercentage = Number(data.aiScore) || null;           // force number ou null
    const aiSummary    = data.aiSummary != null ? String(data.aiSummary) : null;

    // Log pour debug (à retirer en prod si tu veux)
    console.log("Valeurs IA reçues →", { aiPercentage, aiSummary });

    await pool.query(`
      UPDATE alertes
      SET 
        is_analysed   = TRUE,
        ai_percentage = $1,
        alert_data    = alert_data || jsonb_build_object(
          'aiSummary', 
          $2::text
        ),
        status        = 'ANALYZED'
      WHERE id = $3
    `, [aiPercentage, aiSummary, alert_id]);

    // Retour de l'alerte mise à jour
    const updated = await pool.query(`
      SELECT id, status, ai_percentage, alert_data
      FROM alertes
      WHERE id = $1
    `, [alert_id]);

    const row = updated.rows[0];

    res.json({
      id: row.id,
      ...row.alert_data,
      status: row.status,
      aiScore: row.ai_percentage
    });

  } catch (err) {
    console.error("Erreur analyse :", err.message);
    res.status(500).json({ error: "Failed to run AI analysis" });
  }
});

// ──────────────────────────────────────────────────────────────
// POST /decision
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
    console.log("Envoi décision vers blockchain...");
    await pushData(alertId, decision, hash);

    console.log("Lecture immédiate blockchain...");
    const record = await pullData(alertId);
    console.log("Record blockchain :", record);

    res.json({
      status: "SUCCESS",
      txHash: hash,
      alertId
    });

  } catch (err) {
    console.error("Échec décision / blockchain :", err.message);
    res.status(500).json({ error: "Failed to record decision" });
  }
});

// Gestion erreurs JWT
app.use((err, _req, res, next) => {
  if (err.name === 'UnauthorizedError') {
    return res.status(401).json({ error: 'Invalid Token: ' + err.message });
  }
  next(err);
});

app.listen(PORT, () => {
  console.log(`✅ EM Service running on port ${PORT}`);
});