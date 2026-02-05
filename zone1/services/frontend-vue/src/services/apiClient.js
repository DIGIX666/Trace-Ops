import axios from 'axios';
import { keycloak } from '../main.js';

const apiClient = axios.create({
  baseURL: '/api',
});

// Intercepteur - ajoute le token JWT
apiClient.interceptors.request.use(async config => {
  if (keycloak.token) {
    await keycloak.updateToken(30); // Refresh si < 30s avant expiration
    config.headers.Authorization = `Bearer ${keycloak.token}`;
  } else {
    console.log("Error: no JWT")
  }
  
  return config;
}, error => {
  return Promise.reject(error);
});

export default apiClient;
