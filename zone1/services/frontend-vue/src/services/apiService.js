import { reactive } from 'vue';

// État réactif pour l'affichage
export const store = reactive({
  alerts: []
});

// --- APPELS API RÉELS ---

// Appelé par le composant J2Dashboard et EMDecision pour rafraîchir la liste
export const fetchAlerts = async () => {
  try {
    // Appel vers Nginx /api/j2/alerts -> Python
    const response = await fetch('/api/j2/alerts');
    const data = await response.json();
    store.alerts = data; // Mise à jour de la liste
  } catch (error) {
    console.error("Erreur fetch alerts:", error);
  }
};

// Injection (Terrain)
export const injectAlert = async (alertData) => {
  try {
    const response = await fetch('/api/j2/alerts', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify(alertData)
    });
    const newAlert = await response.json();
    // On rafraichit la liste locale
    store.alerts.push(newAlert); 
    return newAlert;
  } catch (error) {
    console.error("Erreur injection:", error);
  }
};

// Analyse (J2)
export const analyzeAlert = async (id) => {
  try {
    const response = await fetch(`/api/j2/analyze/${id}`, {
      method: 'POST'
    });
    if (response.ok) {
      // On recharge tout pour avoir l'état à jour
      await fetchAlerts(); 
    }
  } catch (error) {
    console.error("Erreur analyse:", error);
  }
};

// Décision (EM) -> Appelle Node.js
export const makeDecision = async (id, decisionType) => {
  try {
    // Appel vers Nginx /api/em/decision -> Node
    const response = await fetch('/api/em/decision', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ alertId: id, decision: decisionType })
    });
    
    const result = await response.json();
    console.log("Retour Ledger simulé:", result);
    
    if (result.status === "SUCCESS") {
      await fetchAlerts(); // Mise à jour UI
    }
  } catch (error) {
    console.error("Erreur décision:", error);
  }
};