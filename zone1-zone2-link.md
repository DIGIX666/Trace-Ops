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
./zone2-ledger/scripts/generate-connection-profiles.sh
```

### Copiez ce fichier :

zone2-ledger/config/connection-profiles/zone1-write-connection.json
ici :
zone1/services/backend-em/zone1-write-connection.json

```bash
cp zone2-ledger/config/connection-profiles/zone1-write-connection.json zone1/services/backend-em/zone1-write-connection.json
```

### Runnez les tests au cas où:

```bash
./zone2-ledger/scripts/run-unit-tests.sh
```

### Modifiez le fichier zone1/services/backend-em/zone1-write-connection.json :

- remplacer tous les localhosts par les noms des orderers / peers correspondant (exemple:)

```json
[...]
  "orderers": {
    "orderer0.traceops.local": {
      "url": "grpcs://orderer0.traceops.local:7050",
      [...]
    },
    "orderer1.traceops.local": {
      "url": "grpcs://orderer1.traceops.local:8050",
      [...]
    }
  },
  "peers": {
    "peer0.orgj2.traceops.local": {
      "url": "grpcs://peer0.orgj2.traceops.local:7051",
      [...]
    },
    "peer0.orgem.traceops.local": {
      "url": "grpcs://peer0.orgem.traceops.local:9051",
      [...]
    }
  },
[...]
```

### Pour le moment, il faut récupérer les fichiers cert.pem et \*\_sk à la main, et les mettre dans le dossier zone1/services/backend-em/wallet, voici comment faire :

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
