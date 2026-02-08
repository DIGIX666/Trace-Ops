import { createApp } from 'vue'
import App from './App.vue'
import router from './router'
import Keycloak from 'keycloak-js'

const initOptions = {
  url: 'http://localhost:8080',
  realm: 'trace-ops',
  clientId: 'frontend-vue',
  onLoad: 'login-required',
  checkLoginIframe: false,
  redirectUri: window.location.origin + window.location.pathname
}

const keycloak = new Keycloak(initOptions)

keycloak.init(
    { 
        onLoad: initOptions.onLoad, 
        silentCheckSsoRedirectUri: window.location.origin + '/silent-check-sso.html', 
        checkLoginIframe: false, 
        enableLogging: true 
    })
    .then((auth) => {
        if (!auth) {
            window.location.reload();
        } else {
            console.log("Authenticated");

            const app = createApp(App)
            app.provide('keycloak', keycloak)
            
            app.config.globalProperties.$keycloak = keycloak;
            
            app.use(router)
            app.mount('#app')
        }

        setInterval(() => {
            keycloak.updateToken(70).then((refreshed) => {
            if (refreshed) {
                console.log('Token refreshed ' + refreshed);
            }
            }).catch(() => {
            console.error('Failed to refresh token');
            });
        }, 60000)

    }).catch(() => {
        console.error("Authenticated Failed");
    }
);

window.__KEYCLOAK = keycloak

export { keycloak };
