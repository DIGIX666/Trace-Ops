<template>
  <div class="scan-container">
    <div class="scan-header">
      <div>
        <h1>TraceScan</h1>
        <p>Vue technique des blocs et transactions (MVP demo)</p>
      </div>
      <button @click="fetchBlocks" :disabled="loading" class="refresh-btn">
        {{ loading ? 'Chargement...' : 'Actualiser' }}
      </button>
    </div>

    <div v-if="error" class="error-banner">{{ error }}</div>

    <div class="scan-grid" v-else>
      <table>
        <thead>
          <tr>
            <th>Block</th>
            <th>TxId</th>
            <th>Canal</th>
            <th>Type</th>
            <th>Status</th>
            <th>Auteur</th>
            <th>Horodatage</th>
          </tr>
        </thead>
        <tbody>
          <tr
            v-for="row in blocks"
            :key="row.txId"
            @click="selectRow(row)"
            :class="{ active: selectedTx && selectedTx.txId === row.txId }"
          >
            <td>#{{ row.blockNumber }}</td>
            <td>{{ row.txId }}</td>
            <td>{{ row.channel }}</td>
            <td>{{ row.type }}</td>
            <td>{{ row.status }}</td>
            <td>{{ row.author }}</td>
            <td>{{ formatDate(row.timestamp) }}</td>
          </tr>
        </tbody>
      </table>
    </div>

    <div v-if="selectedTx" class="tx-detail">
      <h3>Detail transaction {{ selectedTx.txId }}</h3>
      <pre>{{ prettyPayload(selectedTx.payload) }}</pre>
    </div>
  </div>
</template>

<script setup>
import axios from 'axios';
import { onMounted, ref } from 'vue';

const blocks = ref([]);
const selectedTx = ref(null);
const loading = ref(false);
const error = ref('');

const fetchBlocks = async () => {
  loading.value = true;
  error.value = '';
  try {
    const response = await axios.get('/api/tracescan/blocks');
    blocks.value = response.data;
    selectedTx.value = null;
  } catch (err) {
    error.value = 'Impossible de charger les blocs TraceScan.';
    console.error(err);
  } finally {
    loading.value = false;
  }
};

const selectRow = async (row) => {
  try {
    const response = await axios.get(`/api/tracescan/tx/${row.txId}`);
    selectedTx.value = response.data;
  } catch (err) {
    console.error(err);
  }
};

const formatDate = (iso) => new Date(iso).toLocaleString('fr-FR');
const prettyPayload = (payload) => JSON.stringify(payload, null, 2);

onMounted(() => {
  fetchBlocks();
});
</script>

<style scoped>
.scan-container {
  background: #fff;
  border: 1px solid #d9dee6;
  border-radius: 8px;
  padding: 16px;
}

.scan-header {
  display: flex;
  justify-content: space-between;
  align-items: center;
  margin-bottom: 12px;
}

.scan-header h1 {
  margin: 0;
}

.scan-header p {
  margin: 4px 0 0;
  color: #616975;
}

.refresh-btn {
  border: 0;
  border-radius: 4px;
  padding: 8px 12px;
  background: #27374a;
  color: #fff;
  cursor: pointer;
}

.scan-grid {
  overflow-x: auto;
}

table {
  width: 100%;
  border-collapse: collapse;
}

th,
td {
  border-bottom: 1px solid #eceff3;
  text-align: left;
  padding: 10px 8px;
  font-size: 0.92rem;
}

tbody tr {
  cursor: pointer;
}

tbody tr:hover {
  background: #f8faff;
}

tbody tr.active {
  background: #eef4ff;
}

.tx-detail {
  margin-top: 14px;
  padding: 12px;
  background: #f8fafc;
  border: 1px solid #e2e8f0;
  border-radius: 6px;
}

.tx-detail h3 {
  margin: 0 0 8px;
}

.tx-detail pre {
  margin: 0;
  white-space: pre-wrap;
  font-size: 0.85rem;
}

.error-banner {
  background: #fff1f1;
  color: #a61b1b;
  border: 1px solid #ffcccc;
  border-radius: 6px;
  padding: 10px;
}
</style>
