<template>
  <div class="monitor-container">
    <div class="monitor-header">
      <div>
        <h1>📅 Timeline Calendaire (Zone 3)</h1>
        <p class="subtitle">Vue continue • Transactions & Événements</p>
      </div>
      <div class="actions">
        <button @click="fetchData" :disabled="loading" class="btn-refresh">
          {{ loading ? 'Chargement...' : '⟳ Actualiser' }}
        </button>
      </div>
    </div>

    <div v-if="error" class="error-banner">{{ error }}</div>

    <div class="timeline-scroll-area" ref="scrollContainer" @wheel.prevent="handleScroll">
      <div class="timeline-track">
        <div 
          v-for="day in calendarDays" 
          :key="day.dateKey" 
          class="day-slot"
          :class="{ 'has-events': day.events.length > 0, 'is-today': day.isToday }"
        >
          <div class="day-header">
            <span class="day-name">{{ day.dayName }}</span>
            <span class="day-num">{{ day.dayNum }}</span>
          </div>

          <div class="day-content">
            <div 
              v-for="event in day.events" 
              :key="event.id"
              class="event-node"
              @click.stop="selectEvent(event)"
            >
              <div 
                class="event-dot" 
                :class="[
                  getBadgeClass(event.mainType), 
                  { 'is-active': selectedEvent && selectedEvent.id === event.id }
                ]"
              ></div>
              
              <div class="event-time" :class="{ 'text-active': selectedEvent?.id === event.id }">
                {{ formatTime(event.timestampMs) }}
              </div>
              
              <div class="event-stem"></div>
            </div>

            <div v-if="day.events.length === 0" class="empty-marker"></div>
          </div>
          
          <div class="day-separator"></div>
        </div>
      </div>
    </div>

    <!-- Panneau de détail -->
    <div class="detail-panel" :class="{ 'open': selectedEvent }">
      <div v-if="selectedEvent" class="detail-wrapper">
        <div class="detail-left">
          <span class="big-time">{{ formatTime(selectedEvent.timestampMs) }}</span>
          <span class="small-date">{{ formatFullDate(selectedEvent.timestampMs) }}</span>
        </div>
        
        <div class="detail-main">
          <!-- Affichage dynamique de TOUT le contenu du payload -->
          <div class="detail-payload">
            <div class="payload-row">
              <span class="payload-key">{{ selectedEvent.payload }}</span>
            </div>
          </div>

          <!-- Info technique en petit -->
          <div class="detail-footer">
            <small>Source: {{ selectedEvent.source || '—' }}</small>
            <small class="tx-id">tx: {{ selectedEvent.txId.slice(0,12) }}…</small>
          </div>
        </div>

        <button class="close-btn" @click="selectedEvent = null">Fermer</button>
      </div>

      <div v-else class="detail-empty">
        Cliquez sur un point pour voir les détails de l'événement.
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted, nextTick } from 'vue';
import axios from 'axios';

const rawEvents = ref([]);
const loading = ref(true);
const error = ref(null);
const selectedEvent = ref(null);
const scrollContainer = ref(null);

// ────────────────────────────────────────────────
//  Normalisation des événements
// ────────────────────────────────────────────────
const normalizedEvents = computed(() => {
  return rawEvents.value.map(item => {
    let payload = {};
    try {
      payload = JSON.parse(item.payload || '{}');
    } catch (e) {
      console.warn("Payload invalide pour l'événement", item.id);
    }

    const tsSeconds = parseFloat(item.txTimestamp || 0);
    const timestampMs = Math.floor(tsSeconds * 1000);

    // On essaie de trouver une "type" principale pour la couleur du point
    const mainType = detectMainType(payload);

    return {
      id: item.id,
      timestampMs,
      payload,                // ← on garde TOUT le payload
      mainType,               // pour la couleur du point
      source: item.source || '—',
      txId: item.txId || '—'
    };
  });
});

// Détection d'un type principal pour la couleur (facultatif mais utile)
const detectMainType = (payload) => {
  const str = JSON.stringify(payload).toLowerCase();
  if (str.includes('approv') || str.includes('accept') || str.includes('ok')) return 'approved';
  if (str.includes('reject') || str.includes('deni') || str.includes('fail')) return 'rejected';
  if (str.includes('pend') || str.includes('wait')) return 'pending';
  if (str.includes('error') || str.includes('except')) return 'error';
  return 'default';
};

// ────────────────────────────────────────────────
//  Génération du calendrier
// ────────────────────────────────────────────────
const calendarDays = computed(() => {
  if (normalizedEvents.value.length === 0) return [];

  const sorted = [...normalizedEvents.value].sort((a, b) => a.timestampMs - b.timestampMs);

  const first = new Date(sorted[0].timestampMs);
  const last  = new Date(sorted[sorted.length - 1].timestampMs);

  const startDate = addDays(first, -10);
  const endDate   = addDays(last,  10);

  const timeline = [];
  let current = new Date(startDate);
  current.setHours(0,0,0,0);

  const endLimit = new Date(endDate);
  endLimit.setHours(0,0,0,0);

  const todayStr = new Date().toISOString().split('T')[0];

  while (current <= endLimit) {
    const dateKey = current.toISOString().split('T')[0];

    const eventsForDay = sorted.filter(e => {
      const d = new Date(e.timestampMs);
      return d.toISOString().split('T')[0] === dateKey;
    });

    timeline.push({
      dateKey,
      dayName: current.toLocaleDateString('fr-FR', { weekday: 'short' }).toUpperCase(),
      dayNum: current.toLocaleDateString('fr-FR', { day: '2-digit', month: 'short' }),
      isToday: dateKey === todayStr,
      events: eventsForDay
    });

    current = addDays(current, 1);
  }

  return timeline;
});

const addDays = (date, days) => {
  const res = new Date(date);
  res.setDate(res.getDate() + days);
  return res;
};

// ────────────────────────────────────────────────
//  Chargement des données
// ────────────────────────────────────────────────
const fetchData = async () => {
  loading.value = true;
  error.value = null;
  selectedEvent.value = null;

  try {
    const response = await axios.get('/api/timeline');
    rawEvents.value = Array.isArray(response.data) ? response.data : [];
    nextTick(scrollToLastEvent);
  } catch (err) {
    error.value = "Erreur lors du chargement des données";
    console.error(err);
  } finally {
    loading.value = false;
  }
};

const scrollToLastEvent = () => {
  if (!scrollContainer.value) return;
  scrollContainer.value.scrollLeft = scrollContainer.value.scrollWidth - 400;
};

const handleScroll = (e) => {
  if (scrollContainer.value) scrollContainer.value.scrollLeft += e.deltaY;
};

const selectEvent = (evt) => {
  selectedEvent.value = evt;
};

// ────────────────────────────────────────────────
//  Formatage
// ────────────────────────────────────────────────
const formatTime = (ms) => {
  const d = new Date(ms);
  return `${d.getHours()}h${d.getMinutes().toString().padStart(2, '0')}`;
};

const formatFullDate = (ms) => {
  return new Date(ms).toLocaleDateString('fr-FR', { 
    weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' 
  });
};

const getBadgeClass = (type) => {
  const map = {
    'approved': 'info',
    'rejected': 'error',
    'pending': 'warn',
    'error': 'error',
    'default': 'default'
  };
  return map[type] || 'default';
};

// Pour un affichage propre des clés
const formatKey = (key) => {
  console.log(key)
  if (typeof key !== 'string') {
    return String(key || '—'); // ou '' ou 'clé invalide'
  }
  return key
    .replace(/([A-Z])/g, ' $1')
    .replace(/^./, str => str.toUpperCase())
    .trim();
};

const formatValue = (value) => {
  console.log(value)
  if (typeof value === 'object' && value !== null) {
    return JSON.stringify(value, null, 2);
  }
  return String(value);
};

onMounted(fetchData);
</script>

<style scoped>
/* ────────────────────────────────────────────────
   Styles existants conservés + ajouts pour payload
───────────────────────────────────────────────── */

.payload-row {
  display: flex;
  margin: 8px 0;
  gap: 12px;
  align-items: baseline;
}

.payload-key {
  font-weight: 600;
  color: #444;
  min-width: 140px;
  text-align: right;
  opacity: 0.9;
}

.payload-value {
  color: #2c3e50;
  white-space: pre-wrap;
  word-break: break-word;
  flex: 1;
}

.detail-payload {
  margin: 12px 0 20px;
  font-size: 0.95rem;
  line-height: 1.5;
}

.detail-footer {
  margin-top: 16px;
  display: flex;
  gap: 20px;
  color: #777;
  font-size: 0.8rem;
}

.tx-id {
  font-family: 'Courier New', monospace;
}

/* Couleurs pour les types (points + tags) */
.event-dot.approved,
.type-tag.approved { background: #2ecc71; }
.event-dot.rejected,
.type-tag.rejected { background: #e74c3c; }
.event-dot.pending,
.type-tag.pending   { background: #f39c12; }
.event-dot.error,
.type-tag.error     { background: #c0392b; }
.event-dot.default,
.type-tag.default   { background: #95a5a6; }

/* --- Structure --- */
.monitor-container {
  display: flex; flex-direction: column;
  height: 70vh; max-width: 1400px; margin: 0 auto;
  background: #f4f6f8; border-radius: 8px; overflow: hidden;
  font-family: 'Segoe UI', sans-serif;
  border: 1px solid #dcdcdc;
}

.monitor-header {
  background: #fff; padding: 15px 20px; border-bottom: 1px solid #e0e0e0;
  display: flex; justify-content: space-between; align-items: center;
}
.monitor-header h1 { margin: 0; font-size: 1.2rem; color: #333; }
.subtitle { margin: 0; font-size: 0.8rem; color: #888; }
.btn-refresh { padding: 8px 15px; background: #333; color: #fff; border:none; border-radius:4px; cursor: pointer; }

/* --- TIMELINE AREA --- */
.timeline-scroll-area {
  flex: 1;
  overflow-x: auto;
  overflow-y: hidden;
  position: relative;
  background: #fff;
  /* Pattern de fond subtil pour l'effet papier millimétré */
  background-image: linear-gradient(#f0f0f0 1px, transparent 1px);
  background-size: 20px 20px;
}

.timeline-track {
  display: flex;
  height: 100%;
  padding-bottom: 20px; /* espace pour scrollbar */
}

/* --- SLOT JOUR --- */
.day-slot {
  position: relative;
  min-width: 140px; /* Largeur fixe minimale par jour */
  display: flex;
  flex-direction: column;
  border-right: 1px dashed #e0e0e0;
  transition: background 0.2s;
}

.day-slot.is-today { background-color: rgba(52, 152, 219, 0.05); }
.day-slot.has-events { background-color: #fff; }
/* Les jours vides sont légèrement grisés par le background global container, 
   mais on peut forcer ici si besoin */

/* Header Date */
.day-header {
  text-align: center; padding-top: 15px; height: 50px;
  border-bottom: 1px solid transparent;
}
.day-name { display: block; font-size: 0.7rem; font-weight: bold; color: #aaa; text-transform: uppercase; }
.day-num { font-size: 1rem; font-weight: 600; color: #555; }
.is-today .day-num { color: #3498db; }

/* Contenu (Ligne des events) */
.day-content {
  flex: 1;
  display: flex;
  align-items: center; /* Centrer verticalement sur la ligne de temps */
  justify-content: center; /* Centrer les points dans la case jour */
  position: relative;
  gap: 15px; /* Espace si plusieurs events le même jour */
}

/* La ligne horizontale centrale (Timeline axis) */
.day-content::before {
  content: ''; position: absolute;
  top: 50%; left: 0; right: 0;
  height: 2px; background: #ddd; z-index: 0;
}

/* Event Node (Groupe Point + Heure) */
.event-node {
  position: relative; z-index: 1;
  display: flex; flex-direction: column; align-items: center;
  cursor: pointer;
  transition: transform 0.2s;
}
.event-node:hover { transform: translateY(-5px); }

/* Point */
.event-dot {
  width: 16px;
  height: 16px;
  border-radius: 50%;
  border: 3px solid #fff;
  box-shadow: 0 2px 4px rgba(0,0,0,0.1);
  transition: all 0.2s ease-in-out;
  cursor: pointer;
  z-index: 2;
}

/* L'état ACTIF : Uniquement pour l'ID correspondant */
.event-dot.is-active {
  transform: scale(1.5); /* Il grossit plus que les autres */
  border-color: #2c3e50; /* Bordure foncée pour le faire ressortir */
  box-shadow: 0 0 12px rgba(0,0,0,0.3);
  z-index: 10;
}

/* Optionnel : mettre l'heure en gras quand sélectionné */
.event-time.text-active {
  color: #2c3e50;
  font-weight: 800;
  transform: translateY(-2px);
}

/* Couleurs */
.event-dot.info { background: #3498db; }
.event-dot.warn, .event-dot.warning { background: #f39c12; }
.event-dot.error, .event-dot.alert { background: #e74c3c; }

/* Heure (au dessus du point) */
.event-time {
  position: absolute; top: -25px;
  font-size: 0.7rem; color: #666; font-weight: bold;
  background: rgba(255,255,255,0.8); padding: 0 4px; border-radius: 4px;
  white-space: nowrap;
}

/* Tige (sous le point) */
.event-stem {
  position: absolute; top: 16px;
  width: 1px; height: 20px; background: #ddd;
}

/* Marqueur vide (pour les jours sans données) */
.empty-marker {
  width: 6px; height: 6px; border-radius: 50%; background: #eee;
  z-index: 1;
}

/* --- Detail Panel --- */
.detail-panel {
  height: 0; background: #fff; border-top: 1px solid #ccc;
  overflow: hidden; transition: height 0.3s ease;
}
.detail-panel.open { height: 180px; }

.detail-wrapper {
  display: flex; height: 100%; padding: 20px; box-sizing: border-box;
}

.detail-left {
  display: flex; flex-direction: column; justify-content: center;
  min-width: 120px; border-right: 1px solid #eee; margin-right: 20px;
}
.big-time { font-size: 2rem; font-weight: 300; color: #333; }
.small-date { font-size: 0.8rem; color: #888; text-transform: uppercase; }

.detail-main { flex: 1; display: flex; flex-direction: column; justify-content: center; }
.detail-badges { margin-bottom: 10px; }
.type-tag { padding: 4px 8px; border-radius: 4px; color: white; font-size: 0.75rem; margin-right: 10px; font-weight: bold; text-transform: uppercase; }
.type-tag.info { background: #3498db; }
.type-tag.warn { background: #f39c12; }
.type-tag.error { background: #e74c3c; }
.status-tag { font-size: 0.75rem; color: #666; border: 1px solid #ddd; padding: 3px 8px; border-radius: 4px; }

.detail-main h3 { margin: 0 0 5px 0; font-size: 1.1rem; }
.detail-main p { margin: 0; color: #555; }

.close-btn { align-self: flex-start; background: none; border: 1px solid #ddd; padding: 5px 10px; cursor: pointer; border-radius: 4px; }
.close-btn:hover { background: #f9f9f9; }

.detail-empty { display: flex; align-items: center; justify-content: center; height: 100%; color: #aaa; font-style: italic; }
</style>