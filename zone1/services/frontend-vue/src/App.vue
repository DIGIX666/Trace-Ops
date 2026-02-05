<template>
  <header>
    <div class="logo">TRACE-OPS <span class="zone-badge">ZONE 1</span></div>
    <nav>
      <RouterLink v-if="hasRole('operateur')" to="/alert"
        >Terrain (Injection)</RouterLink
      >
      <RouterLink v-if="hasRole('analyste')" to="/j2"
        >J2 (Analyse)</RouterLink
      >
      <RouterLink v-if="hasRole('decideur')" to="/em"
        >EM (Décision)</RouterLink
      >
    </nav>
    <RouterLink v-if="keycloak?.authenticated" to="/logout">Déconnexion</RouterLink>
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

onMounted(() => {
  if (keycloak?.authenticated) {
    userRoles.value = keycloak.tokenParsed?.realm_access?.roles || [];
  }
});

const hasRole = (role) => userRoles.value.includes(role);
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
