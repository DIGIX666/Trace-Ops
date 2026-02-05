import { createRouter, createWebHistory } from 'vue-router'
import AlertInjection from '../views/AlertInjection.vue'
import J2Dashboard from '../views/J2Dashboard.vue'
import EMDecision from '../views/EMDecision.vue'
import Home from '../views/Home.vue'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    { path: '/', component: Home, name: 'Accueil', meta: { requiresAuth: true } },
    { path: '/alert', component: AlertInjection, name: 'Injection', meta: { requiresRole: 'operateur' } },
    { path: '/j2', component: J2Dashboard, name: 'Analyse J2', meta: { requiresRole: 'analyste' } },
    { path: '/em', component: EMDecision, name: 'Decision EM', meta: { requiresRole: 'decideur' } }
  ]
})

router.beforeEach(async (to, from, next) => {
  const keycloak = window.__KEYCLOAK
  
  if (!keycloak) {
    // Keycloak pas encore prêt
    return next('/')
  }

  // Vérifier l'authentification
  if (to.meta.requiresAuth && !keycloak.authenticated) {
    await keycloak.login()
    return
  }
  if (to.meta.requiresRole) {
    const hasRole = keycloak.hasRealmRole(to.meta.requiresRole);
    if (!hasRole) {
      alert("Accès interdit : Vous n'avez pas le rôle requis.");
      return next('/');
    }
  }
  next();
});

export default router