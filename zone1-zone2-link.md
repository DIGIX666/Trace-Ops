## To initialize everything for now:

### Run these commands in order from the repository root:

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

### Verify the generated/copied profile automatically:

From `generate-connection-profiles.sh`, the file is generated in Zone2 **and** automatically copied to Zone1.

```bash
ls -l zone2-ledger/config/connection-profiles/zone1-write-connection.json
ls -l zone1/connection-profiles/zone1-write-connection.json
```

### Run tests just in case:

```bash
./zone2-ledger/scripts/run-unit-tests.sh
```

### Fabric identities in `zone1/wallet`:

The EM backend expects `wallet/cert.pem` and one `*_sk` file in `zone1/wallet`.

Quick check:

```bash
ls -l zone1/wallet
```

After that, copy this wallet into Zone3 as well.

```
cp zone1/wallet zone3/wallet
```

### Once this is done, you can start Zone 1:

[Keycloak configuration](/keycloak-config/README-keycloak.md)

AND

```bash
make z1-build
```

### You can also start Zone 3 after Zone 1:

```bash
make z3-build
```
