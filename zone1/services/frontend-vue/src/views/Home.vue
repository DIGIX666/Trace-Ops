<!-- Home.vue -->
<script setup></script>

<template>
  <div class="home">
    <h1>Choisir une section</h1>
    <div class="menu">
      <div class="menu-card" v-if="hasRole('operateur')"><RouterLink to="/alert">Terrain (Injection)</RouterLink></div>
      <div class="menu-card" v-if="hasRole('analyste')"><RouterLink to="/j2">J2 (Analyse)</RouterLink></div>
      <div class="menu-card" v-if="hasRole('decideur')"><RouterLink to="/em">EM (Décision)</RouterLink></div>
    </div>
  </div>
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

</script>

<style>

.menu {
  display: grid;
  grid-template-columns: 1fr 1fr;
  gap: 10px 20px;
}

.menu a {
  color: black;
  text-decoration: none;
  display: block;
  line-height: 100px;
  text-align: center;
}

.menu-card a {
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 10px;
  color: black;
  text-decoration: none;
  height: 100%;
}

.menu-card {
  border: 1px solid;
  height: 100px;
  position: relative;
}

.menu-card a {
  display: flex;
  justify-content: center;
  align-items: center;
  width: 100%;
  height: 100%;
  text-decoration: none;
  color: black;
  position: relative;
}

.menu-card a::after {
  content: "→";
  position: absolute;
  right: 30px;
  font-size: 20px;
  color: gray;
  transition: transform 0.2s ease, color 0.2s ease;
}

.menu-card a:hover::after {
  transform: translateX(5px);
  color: black;
}

</style>