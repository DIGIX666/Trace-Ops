import { createRouter, createWebHistory } from 'vue-router'
import AlertInjection from '../views/AlertInjection.vue'
import J2Dashboard from '../views/J2Dashboard.vue'
import EMDecision from '../views/EMDecision.vue'

const router = createRouter({
  history: createWebHistory(import.meta.env.BASE_URL),
  routes: [
    { path: '/', redirect: '/alert' },
    { path: '/alert', component: AlertInjection, name: 'Injection' },
    { path: '/j2', component: J2Dashboard, name: 'Analyse J2' },
    { path: '/em', component: EMDecision, name: 'Decision EM' }
  ]
})

export default router