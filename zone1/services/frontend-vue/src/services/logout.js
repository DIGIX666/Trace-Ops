const callLogout = async () => {
    const keycloak = window.__KEYCLOAK
    if (keycloak?.authenticated) {
      // IMPORTANT: redirectUri ABSOLU complet
      const logoutUrl = keycloak.createLogoutUrl({
        redirectUri: window.location.origin + import.meta.env.BASE_URL
      })
      // LOCATION natif - PAS router.push !
      window.location.href = logoutUrl
      return
    }
    window.location.href = window.location.origin + import.meta.env.BASE_URL
  }

export {callLogout};