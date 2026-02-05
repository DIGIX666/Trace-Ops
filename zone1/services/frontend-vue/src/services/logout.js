// Fonction - déconnecte
const callLogout = async () => {
    const keycloak = window.__KEYCLOAK
    if (keycloak?.authenticated) {
      const logoutUrl = keycloak.createLogoutUrl({
        redirectUri: window.location.origin + import.meta.env.BASE_URL
      })
      window.location.href = logoutUrl
      return
    }
    window.location.href = window.location.origin + import.meta.env.BASE_URL
  }

export {callLogout};