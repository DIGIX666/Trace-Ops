import axios from 'axios';
import { keycloak } from '../main.js';

const apiClient = axios.create({
  baseURL: '/api', // Garde le proxy Nginx existant (sans http://localhost)
});

// Intercepteur pour ajouter le token JWT
apiClient.interceptors.request.use(async config => {
  if (keycloak.token) {
    await keycloak.updateToken(30); // Refresh si < 30s avant expiration
    config.headers.Authorization = `Bearer ${keycloak.token}`;
  }
  return config;
}, error => {
  return Promise.reject(error);
});

export default apiClient;
