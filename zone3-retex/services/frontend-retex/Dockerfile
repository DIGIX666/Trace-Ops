# Stage de build (pour plus tard quand le code Vue sera là)
FROM node:18-alpine as build-stage
WORKDIR /app
COPY package*.json ./
# RUN npm install
# COPY . .
# RUN npm run build

# Stage de production (Simulation pour l'instant)
FROM nginx:stable-alpine
# Pour l'instant on crée un index.html bidon pour tester le conteneur
RUN echo "<h1>Zone 3 - RETEX UI Ready</h1>" > /usr/share/nginx/html/index.html
EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]