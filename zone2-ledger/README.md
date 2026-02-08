# Zone2 Ledger

Zone2 provides the Hyperledger Fabric network for the Trace-Ops POC.

Current topology:

- 2 orgs (`OrgJ2MSP`, `OrgEMMSP`)
- 2 orderers (etcdraft)
- 2 peers (one per org)
- CouchDB state database
- Fabric CA identities and TLS material
- Channel: `traceops`
- Chaincode: `decision`

## Quick start

Run preflight checks:

```bash
./zone2-ledger/scripts/tests/preflight_test.sh
```

Bootstrap the network:

```bash
./zone2-ledger/scripts/bootstrap-network.sh
```

Deploy chaincode:

```bash
./zone2-ledger/scripts/deploy-chaincode.sh
```

Generate Zone1/Zone3 connection profiles:

```bash
./zone2-ledger/scripts/generate-connection-profiles.sh
```

## Main paths

- `zone2-ledger/compose/docker-compose.yaml`
- `zone2-ledger/config/`
- `zone2-ledger/scripts/`
- `zone2-ledger/chaincode/decision/`
- `zone2-ledger/docs/runbook.md`

## Operations guide

For full procedures (start, stop, reset, backup, restore, cert rotation, troubleshooting), see:

- `zone2-ledger/docs/runbook.md`
