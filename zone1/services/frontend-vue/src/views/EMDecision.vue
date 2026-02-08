<script setup>
import { onMounted, computed } from "vue";
import {
  store,
  fetchAlerts,
  analyzeAlert,
  makeDecision,
} from "../services/apiService";

onMounted(() => {
  fetchAlerts();
});

const pendingAlerts = computed(() =>
  store.alerts.filter((a) => a.status === "ANALYZED"),
);
const decidedAlerts = computed(() =>
  store.alerts.filter((a) => a.status === "DECIDED"),
);
</script>

<template>
  <div class="panel">
    <h2>⚖️ Décision État-Major (J3)</h2>
    <div class="alert-grid">
      <div v-for="alert in pendingAlerts" :key="alert.id" class="card">
        <div class="card-header">
          <strong>{{ alert.id }}</strong> -
          <span class="badge">{{ alert.criticality }}</span>
        </div>
        <div class="card-body">
          <p><strong>Type:</strong> {{ alert.type }}</p>
          <p><strong>Zone:</strong> {{ alert.zone }}</p>
          <div class="ai-box">
            <p>
              🤖 <strong>IA Summary (Score {{ alert.aiScore }}):</strong>
            </p>
            <p>
              <em>{{ alert.aiSummary }}</em>
            </p>
          </div>
        </div>
        <div class="card-actions">
          <button
            @click="makeDecision(alert.id, 'VALIDATED')"
            class="btn-valid"
          >
            ✅ Valider
          </button>
          <button @click="makeDecision(alert.id, 'ARBITRATED')" class="btn-arb">
            ⚠️ Arbitrer
          </button>
          <button
            @click="makeDecision(alert.id, 'REJECTED')"
            class="btn-reject"
          >
            ❌ Rejeter
          </button>
        </div>
      </div>

      <div v-if="pendingAlerts.length === 0" class="empty-state">
        Aucune alerte en attente de décision.
      </div>
    </div>

    <h3>Historique Récent (Simulé Ledger)</h3>
    <ul>
      <li v-for="alert in decidedAlerts" :key="alert.id">
        {{ alert.id }} : <strong>{{ alert.decision }}</strong> (Hash: 0x{{
          Math.random().toString(16).substr(2, 8)
        }}...)
      </li>
    </ul>
  </div>
</template>

<style scoped>
.alert-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(300px, 1fr));
  gap: 20px;
  margin-bottom: 30px;
}
.card {
  border: 1px solid #bbb;
  border-radius: 8px;
  overflow: hidden;
  background: white;
  box-shadow: 2px 2px 5px rgba(0, 0, 0, 0.1);
}
.card-header {
  background: #333;
  color: white;
  padding: 10px;
  display: flex;
  justify-content: space-between;
}
.card-body {
  padding: 15px;
}
.ai-box {
  background: #eef;
  padding: 10px;
  border-left: 4px solid #007bff;
  margin-top: 10px;
  font-size: 0.9em;
}
.card-actions {
  display: flex;
  border-top: 1px solid #ddd;
}
.card-actions button {
  flex: 1;
  padding: 10px;
  border: none;
  cursor: pointer;
  font-weight: bold;
}
.btn-valid {
  background: #d4edda;
  color: #155724;
}
.btn-valid:hover {
  background: #c3e6cb;
}
.btn-arb {
  background: #fff3cd;
  color: #856404;
}
.btn-reject {
  background: #f8d7da;
  color: #721c24;
}
.empty-state {
  padding: 20px;
  text-align: center;
  color: #666;
  font-style: italic;
}
</style>
