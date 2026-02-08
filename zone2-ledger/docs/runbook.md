# Zone2 Ledger Runbook

This document explains how to start and verify Zone2 (Hyperledger Fabric) for the POC.

For a quick project overview and quick-start commands, see `zone2-ledger/README.md`.

## Prerequisites

- Docker
- Docker Compose v2 (`docker compose`)
- Free ports: `7054`, `5984`, `6984`, `7050`, `8050`, `7051`, `9051`, `7052`, `9052`

## Useful paths

- `zone2-ledger/compose/docker-compose.yaml`
- `zone2-ledger/config/ca.env`
- `zone2-ledger/config/configtx.yaml`
- `zone2-ledger/config/orderer0.yaml`
- `zone2-ledger/config/orderer1.yaml`
- `zone2-ledger/scripts/ca-bootstrap.sh`
- `zone2-ledger/scripts/generate-channel-artifacts.sh`
- `zone2-ledger/scripts/bootstrap-network.sh`
- `zone2-ledger/scripts/deploy-chaincode.sh`
- `zone2-ledger/scripts/generate-connection-profiles.sh`
- `zone2-ledger/scripts/run-unit-tests.sh`
- `zone2-ledger/scripts/tests/generate_connection_profiles_test.sh`
- `zone2-ledger/scripts/tests/preflight_test.sh`

## 1) Run preflight checks

Run before each startup or commit:

```bash
./zone2-ledger/scripts/tests/preflight_test.sh
```

Expected: `Preflight result: ... 0 failed`.

## 2) Start base services

Start CA + CouchDB:

```bash
docker compose -f zone2-ledger/compose/docker-compose.yaml up -d ca.traceops.local couchdb0.orgj2.traceops.local couchdb0.orgem.traceops.local
```

Check status:

```bash
docker compose -f zone2-ledger/compose/docker-compose.yaml ps
```

## 3) Quick health checks

Fabric CA:

```bash
curl -s http://localhost:7054/cainfo
```

CouchDB J2 and EM:

```bash
curl -s -u admin:adminpw http://localhost:5984/_up
curl -s -u admin:adminpw http://localhost:6984/_up
```

Expected: `{"status":"ok"}` for both CouchDB instances.

> [!NOTE]
> - For normal usage, run [step 6](#6-bootstrap-the-network) directly (full automatic bootstrap).
> - Use steps 4 and 5 only when you need to debug or run the process manually step by step.

## 4) Bootstrap identities (once CA is up)

Purpose: generate Fabric identities (MSP/TLS) for orgs, peers, and orderers.
Without this step, peers/orderers cannot start correctly with security enabled.

The CA bootstrap script reads `CA_SCHEME` from `zone2-ledger/config/ca.env`.

- Current default is `http`.
- If you switch to `https`, make sure `zone2-ledger/crypto/ca/ca-cert.pem` exists.

Then run:

```bash
./zone2-ledger/scripts/ca-bootstrap.sh
```

Expected result:

- `zone2-ledger/crypto/organizations/...` is generated
- MSP/TLS materials for orgs, peers, and orderers.

## 5) Generate channel/genesis artifacts

Purpose: generate blockchain configuration artifacts (`genesis.block`, channel tx, anchor updates).
Without these artifacts, channel creation and network configuration cannot be completed.

After organizations are generated:

```bash
./zone2-ledger/scripts/generate-channel-artifacts.sh
```

Expected result:

- `zone2-ledger/crypto/channel-artifacts/genesis.block`
- `zone2-ledger/crypto/channel-artifacts/traceops.tx`

## 6) Bootstrap the network

Purpose: run a full one-shot bootstrap (recommended path).
This step orchestrates startup + identities + artifacts + channel creation/join/anchor updates.
Use this step when you want a full automatic setup instead of running steps 4 and 5 manually.

Run the full bootstrap flow:

```bash
./zone2-ledger/scripts/bootstrap-network.sh
```

What it does:

- starts CA and both CouchDB services
- waits for CA and exports `ca-cert.pem`
- runs CA identities bootstrap
- generates channel artifacts (genesis/channel/anchors)
- starts orderers and peers
- creates channel `traceops`, joins both peers, updates anchor peers.

## 7) Deploy decision chaincode

Deploy `decision` to channel `traceops` using Fabric lifecycle:

```bash
./zone2-ledger/scripts/deploy-chaincode.sh
```

What it does:

- packages and installs chaincode on both peers,
- approves definition for OrgJ2 and OrgEM,
- commits chaincode definition with endorsement policy,
- runs a smoke invoke/query by default.

> [!NOTE]
> - Defaults: `CHAINCODE_NAME=decision`, `CHAINCODE_VERSION=1.0`, `CHAINCODE_SEQUENCE=1`.
> - Set `RUN_SMOKE_TEST=false` to skip invoke/query smoke test.

## 8) Generate inter-zone connection profiles

Generate SDK connection profiles for Zone1 (write) and Zone3 (read):

```bash
./zone2-ledger/scripts/generate-connection-profiles.sh
```

Output files:

- `zone2-ledger/config/connection-profiles/zone1-write-connection.json`
- `zone2-ledger/config/connection-profiles/zone3-read-connection.json`

> [!NOTE]
> - These files include TLS CA certs inline.
> - For remote hosts, set `ZONE2_PUBLIC_HOST=<host-or-ip>` before running the script.
> - Generated profiles are local artifacts and are ignored by git.

## 9) Minimal observability

Check container health status:

```bash
docker compose -f zone2-ledger/compose/docker-compose.yaml ps
```

Read recent logs for all services:

```bash
docker compose -f zone2-ledger/compose/docker-compose.yaml logs --tail=100
```

Read recent logs for one service:

```bash
docker compose -f zone2-ledger/compose/docker-compose.yaml logs --tail=100 peer0.orgj2.traceops.local
```

> [!NOTE]
> - Compose now includes healthchecks for CA, orderers, peers, and CouchDB.
> - Compose now includes log rotation (`json-file`, max-size `10m`, max-file `3`).
> - Metrics endpoints are not enabled yet (optional next step).

## 10) Run unit tests

Run all current unit tests (chaincode + critical scripts):

```bash
./zone2-ledger/scripts/run-unit-tests.sh
```

Equivalent manual commands:

```bash
(cd zone2-ledger/chaincode/decision && go test ./...)
./zone2-ledger/scripts/tests/generate_connection_profiles_test.sh
```

## 11) Stop services

Stop services without deleting volumes:

```bash
docker compose -f zone2-ledger/compose/docker-compose.yaml down
```

Check that all services are stopped:

```bash
docker compose -f zone2-ledger/compose/docker-compose.yaml ps
```

## 12) Reset environment

Use this only when you want to recreate Zone2 from scratch.

Stop services and remove volumes:

```bash
docker compose -f zone2-ledger/compose/docker-compose.yaml down -v
```

Remove generated crypto and artifacts:

```bash
rm -rf zone2-ledger/crypto/organizations zone2-ledger/crypto/channel-artifacts zone2-ledger/crypto/fabric-ca-client zone2-ledger/crypto/ca/ca-cert.pem
```

Recreate the full environment:

```bash
./zone2-ledger/scripts/bootstrap-network.sh
```

## 13) Backup

Create a timestamped backup containing crypto materials and channel artifacts:

```bash
mkdir -p zone2-ledger/backups
tar -czf "zone2-ledger/backups/zone2-backup-$(date +%Y%m%d-%H%M%S).tgz" \
  zone2-ledger/crypto/organizations \
  zone2-ledger/crypto/channel-artifacts \
  zone2-ledger/config
```

Optional: keep Docker named volumes as part of infra-level backup using your host snapshot tooling.

## 14) Restore

Stop services before restore:

```bash
docker compose -f zone2-ledger/compose/docker-compose.yaml down
```

Restore from a backup archive:

```bash
tar -xzf zone2-ledger/backups/<backup-file>.tgz
```

Start services:

```bash
docker compose -f zone2-ledger/compose/docker-compose.yaml up -d
```

Verify with:

```bash
./zone2-ledger/scripts/tests/preflight_test.sh
```

## 15) Certificate rotation (POC-safe procedure)

This POC currently uses Fabric CA enrollment outputs generated by `ca-bootstrap.sh`.

For a safe rotation in this repository:

1. Backup first (see [step 13](#13-backup)).
2. Run a full reset (see [step 12](#12-reset-environment)).
3. Re-run bootstrap and chaincode deploy.

```bash
./zone2-ledger/scripts/bootstrap-network.sh
./zone2-ledger/scripts/deploy-chaincode.sh
```

For production-like no-downtime rotation, plan dedicated cert update flows per org/orderer and channel config updates.

## 16) Known issues and troubleshooting

- Chaincode deploy may fail on some Docker Desktop environments with `docker.proxy.sock` `broken pipe` during `InstallChaincode`.
- If this occurs, restart Docker Desktop and rerun steps 6 then 7.
- If peers crash at startup, check peer logs and ensure no invalid `CORE_PEER_TLS_CLIENTAUTHREQUIRED` override is set.
- If orderers return temporary `consenter error` immediately after bootstrap, wait a few seconds for leader election and retry.
