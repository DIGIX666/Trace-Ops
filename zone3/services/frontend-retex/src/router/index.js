import { createRouter, createWebHistory } from 'vue-router'
import App from '../App.vue'
import Home from '../views/Home.vue'
import Timeline from '../views/Timeline.vue'
import { callLogout } from '@/services/logout'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    { path: '/', component: Home, name: 'Accueil', meta: { requiresAuth: true } },
    { path: '/timeline', component: Timeline, name: 'Timeline', meta: { requiresRole: 'admin' } },
    { path: '/logout', name: 'Logout', beforeEnter: callLogout }
  ]
})

router.beforeEach(async (to, from, next) => {
  const keycloak = window.__KEYCLOAK
  
  if (!keycloak) {
    return next('/')
  }

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