<template>
  <header>
    <div class="logo">TRACE-OPS <span class="zone-badge">ZONE 1</span></div>
    <nav>
      <RouterLink to="/alert">📡 Terrain (Injection)</RouterLink>
      <RouterLink to="/j2">🔍 J2 (Analyse)</RouterLink>
      <RouterLink to="/em">⚖️ EM (Décision)</RouterLink>
    </nav>
  </header>

  <main>
    <RouterView />
  </main>
</template>

<script setup>
import { RouterLink, RouterView } from "vue-router";
</script>

<style>
/* Global simple styles */
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
