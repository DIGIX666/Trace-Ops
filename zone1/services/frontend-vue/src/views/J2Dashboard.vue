<script setup>
import { onMounted } from "vue";
import { store, fetchAlerts, analyzeAlert } from "../services/apiService";

onMounted(() => {
  fetchAlerts();
});

const getScoreClass = (score) => {
  if (!score) return "";
  if (score > 80) return "score-high";
  if (score > 50) return "score-med";
  return "score-low";
};
</script>

<template>
  <div class="panel">
    <h2>🔍 Pré-analyse J2</h2>
    <p>Monitoring des flux entrants et scoring automatique.</p>

    <table class="data-table">
      <thead>
        <tr>
          <th>ID</th>
          <th>Type</th>
          <th>Zone</th>
          <th>Score IA</th>
          <th>Action</th>
        </tr>
      </thead>
      <tbody>
        <tr v-for="alert in store.alerts" :key="alert.id" :class="alert.status">
          <td>{{ alert.id }}</td>
          <td>{{ alert.type }}</td>
          <td>{{ alert.zone }}</td>
          <td>
            <span v-if="alert.aiScore" :class="getScoreClass(alert.aiScore)">
              {{ alert.aiScore }}/100
            </span>
            <span v-else class="text-muted">En attente...</span>
          </td>
          <td>
            <button
              v-if="alert.status === 'NEW'"
              @click="analyzeAlert(alert.id)"
              class="btn-analyze"
            >
              Lancer IA
            </button>
            <span v-else>Transmis EM</span>
          </td>
        </tr>
      </tbody>
    </table>
  </div>
</template>

<style scoped>
.data-table {
  width: 100%;
  border-collapse: collapse;
  margin-top: 15px;
}
th,
td {
  border: 1px solid #ccc;
  padding: 10px;
  text-align: left;
}
th {
  background: #eee;
}
.btn-analyze {
  background: #6f42c1;
  color: white;
  border: none;
  padding: 5px 10px;
  cursor: pointer;
}
.score-high {
  color: red;
  font-weight: bold;
}
.score-med {
  color: orange;
  font-weight: bold;
}
.score-low {
  color: green;
}
</style>
