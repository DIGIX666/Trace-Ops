<template>
  <header>
    <div class="logo">TRACE-OPS <span class="zone-badge">ZONE 1</span></div>
    <nav v-if="userMultirole()">
      <RouterLink to="/">Menu</RouterLink>
      <RouterLink v-if="hasRole('operateur')" to="/alert">Terrain (Injection)</RouterLink>
      <RouterLink v-if="hasRole('analyste')" to="/j2">J2 (Analyse)</RouterLink>
      <RouterLink v-if="hasRole('decideur')" to="/em">EM (Décision)</RouterLink>
    </nav>
    <RouterLink v-if="keycloak?.authenticated" to="/logout" class="logout-button">Déconnexion</RouterLink>
  </header>

  <main>
    <RouterView />
  </main>
</template>

<script setup>
import { RouterLink, RouterView } from "vue-router";
import { inject, onMounted, ref } from "vue";
const keycloak = window.__KEYCLOAK
const userRoles = ref([]);

const navRoles = ['operateur','analyste','decideur'];

onMounted(() => {
  if (keycloak?.authenticated) {
    userRoles.value = keycloak.tokenParsed?.realm_access?.roles || [];
  }
});

const hasRole = (role) => userRoles.value.includes(role);

import { useRouter } from 'vue-router';

function userMultirole() {
  const router = useRouter();
  const userNavRoles = userRoles.value.filter(item => navRoles.includes(item));
  console.log(userNavRoles);

  if (userNavRoles.length !== 1) {
    return true;
  }

  const rolePages = {
    operateur: '/alert',
    analyste: '/j2',
    decideur: '/em'
  };

  const redirectUrl = rolePages[userNavRoles[0]];
  router.replace(redirectUrl);

  return false;
}

</script>

<style>
body {
  font-family: "Arial", sans-serif;
  margin: 0;
  background-color: #f0f2f5;
  color: #333;
}
header {
  background-color: #2c3e50;
  padding: 1rem 2rem;
  display: flex;
  justify-content: space-between;
  align-items: center;
  color: white;
}
.logo {
  font-weight: bold;
  font-size: 1.2rem;
}

.logout-button {
  color: white;
  text-decoration: none;
}

.zone-badge {
  background: #e74c3c;
  font-size: 0.8rem;
  padding: 2px 8px;
  border-radius: 4px;
  vertical-align: middle;
  margin-left: 10px;
}
nav a {
  color: #aaa;
  text-decoration: none;
  margin-left: 20px;
  font-weight: 500;
  transition: 0.3s;
}
nav a:hover,
nav a.router-link-active {
  color: white;
}
main {
  padding: 2rem;
  max-width: 1200px;
  margin: 0 auto;
}
</style>
