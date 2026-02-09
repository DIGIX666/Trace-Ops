import { reactive } from 'vue';
import apiClient from './apiClient.js';

export const store = reactive({
  alerts: []
});
export const fetchAlerts = async () => {
  try {
    const response = await apiClient.get('/timeline');
    store.alerts = response.data;
  } catch (error) {
    console.error("Erreur fetch alerts:", error);
  }
};
