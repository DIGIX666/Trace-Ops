import { reactive } from 'vue';
import apiClient from './apiClient.js';

export const store = reactive({
  alerts: []
});

// Appelé par le composant J2Dashboard et EMDecision pour rafraîchir la liste
export const fetchAlerts = async () => {
  try {
    // Remplace fetch par apiClient (l'intercepteur ajoute le token automatiquement)
    const response = await apiClient.get('/j2/alerts');
    store.alerts = response.data;
  } catch (error) {
    console.error("Erreur fetch alerts:", error);
  }
};

// Injection (Terrain)
export const injectAlert = async (alertData) => {
  try {
    const response = await apiClient.post('/j2/alerts', alertData);
    store.alerts.push(response.data);
    return response.data;
  } catch (error) {
    console.error("Erreur injection:", error);
  }
};

// Analyse (J2)
export const analyzeAlert = async (id) => {
  try {
    await apiClient.post(`/j2/analyze/${id}`);
    await fetchAlerts(); // Recharge la liste
  } catch (error) {
    console.error("Erreur analyse:", error);
  }
};

// Décision (EM)
export const makeDecision = async (id, decisionType) => {
  try {
    const response = await apiClient.post('/em/decision', {
      alertId: id,
      decision: decisionType
    });
    
    console.log("Retour Ledger simulé:", response.data);
    
    if (response.data.status === "SUCCESS") {
      await fetchAlerts();
    }
  } catch (error) {
    console.error("Erreur décision:", error);
  }
};
