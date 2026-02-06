# Zone2 Ledger Runbook

This document explains how to start and verify Zone2 (Hyperledger Fabric) for the POC.

## Prerequisites

- Docker
- Docker Compose v2 (`docker compose`)
- Free ports: `7054`, `5984`, `6984`, `7050`, `8050`, `7051`, `9051`, `7052`, `9052`

## Useful paths

- `zone2-ledger/compose/docker-compose.yaml`
- `zone2-ledger/config/ca.env`
- `zone2-ledger/config/configtx.yaml`
- `zone2-ledger/scripts/ca-bootstrap.sh`
- `zone2-ledger/scripts/generate-channel-artifacts.sh`
- `zone2-ledger/scripts/bootstrap-network.sh`
- `zone2-ledger/scripts/test-preflight.sh`

## 1) Run preflight checks

Run before each startup or commit:

```bash
./zone2-ledger/scripts/test-preflight.sh
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

## Recommended path

- For normal usage, run [step 6](#6-bootstrap-the-network) directly (full automatic bootstrap).
- Use steps 4 and 5 only when you need to debug or run the process manually step by step.

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

## 7) Stop or clean up

Stop without deleting volumes:

```bash
docker compose -f zone2-ledger/compose/docker-compose.yaml down
```

Stop and remove volumes:

```bash
docker compose -f zone2-ledger/compose/docker-compose.yaml down -v
```
