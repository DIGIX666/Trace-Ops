## Pour tout initialiser pour l'instant:

### Lancez ces commandes dans l'ordre depuis la racine:

```bash
docker compose -f zone2-ledger/compose/docker-compose.yaml up -d ca.traceops.local couchdb0.orgj2.traceops.local couchdb0.orgem.traceops.local
```

```bash
sudo ./zone2-ledger/scripts/bootstrap-network.sh
```

```bash
./zone2-ledger/scripts/deploy-chaincode.sh
```

```bash
sudo ./zone2-ledger/scripts/generate-connection-profiles.sh
```

### Vérifiez le profil généré/copié automatiquement :

Depuis `generate-connection-profiles.sh`, le fichier est généré dans Zone2 **et** recopié automatiquement dans Zone1.

```bash
ls -l zone2-ledger/config/connection-profiles/zone1-write-connection.json
ls -l zone1/connection-profiles/zone1-write-connection.json
```

### Runnez les tests au cas où:

```bash
./zone2-ledger/scripts/run-unit-tests.sh
```


### Pour le moment, il faut récupérer les fichiers cert.pem et \*\_sk à la main, et les mettre dans le dossier zone1/wallet/, voici comment faire :

- le fichier cert.pem se situe ici:
  zone2-ledger/crypto/organizations/peerOrganizations/orgj2.traceops.local/users/Admin@orgj2.traceops.local/msp/signcerts/cert.pem
  (on peut juste copier collé le contenue)

- le fichier \*\_sk se situe ici:
  zone2-ledger/crypto/organizations/peerOrganizations/orgj2.traceops.local/users/Admin@orgj2.traceops.local/msp/keystore/\*sk
  (on peut juste copier collé le contenue)

  ATTENTION => le fichier sk est protégé par des permissions. Le plus simple pour les 2 fichiers est de sudo cat /path/ ou sudo chmod /path/ le fichier et de copier le résultat dans cert.pem et hello_sk dans le dossier /wallet/

### Une fois cela de fait, on peut lancer la zone 1:

```bash
make z1-build
```
