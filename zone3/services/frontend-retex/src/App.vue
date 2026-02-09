<template>
  <div class="container">
    <div class="header">
      <h1>📅 RETEX Timeline (Zone 3)</h1>
      <button @click="fetchData">Rafraîchir</button>
    </div>

    <div v-if="loading">Chargement des données...</div>
    <div v-else-if="error" style="color: red;">{{ error }}</div>

    <div v-else>
      <div v-for="event in events" :key="event.id" class="card">
        <div style="display:flex; justify-content:space-between;">
            <strong>{{ formatTime(event.timestamp) }}</strong>
            <span :class="['badge', event.type]">{{ event.type }}</span>
        </div>
        <p><strong>{{ event.author }}</strong>: {{ event.content.message || event.content.action }}</p>
        <small>ID: {{ event.id }} | Status: {{ event.status }}</small>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import axios from 'axios';

const events = ref([]);
const loading = ref(true);
const error = ref(null);

// Note: '/api' sera redirigé par Nginx vers le backend
const fetchData = async () => {
  loading.value = true;
  error.value = null;
  try {
    const response = await axios.get('/api/timeline');
    events.value = response.data;
  } catch (err) {
    error.value = "Erreur de connexion au Backend Zone 3";
    console.error(err);
  } finally {
    loading.value = false;
  }
};

const formatTime = (isoString) => {
    return new Date(isoString).toLocaleString();
}

onMounted(() => {
  fetchData();
});
</script>