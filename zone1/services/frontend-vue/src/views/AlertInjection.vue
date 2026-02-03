<template>
  <div class="panel">
    <h2>📡 Injection d'Alertes (Terrain)</h2>
    <form @submit.prevent="submitAlert" class="alert-form">
      <div class="form-group">
        <label>Type d'incident</label>
        <select v-model="form.type" required>
          <option>Mouvement Troupes</option>
          <option>Tir Artillerie</option>
          <option>Cyber Intrusion</option>
          <option>Interception Radio</option>
        </select>
      </div>

      <div class="form-group">
        <label>Zone Géographique</label>
        <input v-model="form.zone" placeholder="Ex: Secteur Alpha" required />
      </div>

      <div class="form-group">
        <label>Niveau de Criticité</label>
        <select v-model="form.criticality">
          <option>Basse</option>
          <option>Moyenne</option>
          <option>Haute</option>
          <option>Critique</option>
        </select>
      </div>

      <button type="submit" class="btn-primary">Envoyer au J2</button>
    </form>

    <div v-if="lastId" class="success-msg">
      Alerte {{ lastId }} transmise avec succès !
    </div>
  </div>
</template>

<script setup>
import { reactive, ref } from "vue";
import { injectAlert } from "../services/apiService";

const lastId = ref(null);
const form = reactive({
  type: "Mouvement Troupes",
  zone: "",
  criticality: "Moyenne",
});

const submitAlert = () => {
  const result = injectAlert({ ...form });
  lastId.value = result.id;
  // Reset partiel
  form.zone = "";
};
</script>

<style scoped>
.panel {
  border: 1px solid #ddd;
  padding: 20px;
  border-radius: 8px;
  background: #f9f9f9;
}
.form-group {
  margin-bottom: 15px;
}
label {
  display: block;
  font-weight: bold;
  margin-bottom: 5px;
}
input,
select {
  width: 100%;
  padding: 8px;
}
.btn-primary {
  background: #007bff;
  color: white;
  border: none;
  padding: 10px 20px;
  cursor: pointer;
}
.success-msg {
  margin-top: 15px;
  color: green;
  font-weight: bold;
}
</style>
