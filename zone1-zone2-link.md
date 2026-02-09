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


### identités Fabric dans `zone1/wallet` :

Le backend EM attend `wallet/cert.pem` et un fichier `*_sk` dans `zone1/wallet`.

Vérification rapide :

```bash
ls -l zone1/wallet
```


### Une fois cela de fait, on peut lancer la zone 1:

[Configuration de Keycloak](/keycloak-config/README-keycloak.md)

AND 

```bash
make z1-build
```
