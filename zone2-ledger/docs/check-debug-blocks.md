# Check and Debug Blocks (Zone2)

This guide shows how to inspect Fabric channel blocks from the CLI for debug purposes.

## Prerequisites

- Zone2 network is running (`bootstrap-network.sh` done).
- Channel exists (`traceops`).
- Containers are healthy (`docker compose -f zone2-ledger/compose/docker-compose.yaml ps`).

## 1) Select org context

Use OrgEM by default:

```bash
export ORG=orgem
if [ "$ORG" = "orgem" ]; then
  export MSP=OrgEMMSP
  export PEER=peer0.orgem.traceops.local:9051
  export ORG_DOMAIN=orgem.traceops.local
else
  export MSP=OrgJ2MSP
  export PEER=peer0.orgj2.traceops.local:7051
  export ORG_DOMAIN=orgj2.traceops.local
fi

echo "$MSP | $PEER | $ORG_DOMAIN"
```

## 2) Check chain height

```bash
docker run --rm \
  --network traceops \
  -v "$PWD/zone2-ledger/crypto:/crypto" \
  -e CORE_PEER_TLS_ENABLED=true \
  -e CORE_PEER_LOCALMSPID="$MSP" \
  -e CORE_PEER_ADDRESS="$PEER" \
  -e CORE_PEER_MSPCONFIGPATH="/crypto/organizations/peerOrganizations/$ORG_DOMAIN/users/Admin@$ORG_DOMAIN/msp" \
  -e CORE_PEER_TLS_ROOTCERT_FILE="/crypto/organizations/peerOrganizations/$ORG_DOMAIN/peers/peer0.$ORG_DOMAIN/tls/ca.crt" \
  -e CORE_PEER_TLS_CLIENTAUTHREQUIRED=true \
  -e CORE_PEER_TLS_CLIENTCERT_FILE="/crypto/organizations/peerOrganizations/$ORG_DOMAIN/peers/peer0.$ORG_DOMAIN/tls/server.crt" \
  -e CORE_PEER_TLS_CLIENTKEY_FILE="/crypto/organizations/peerOrganizations/$ORG_DOMAIN/peers/peer0.$ORG_DOMAIN/tls/server.key" \
  hyperledger/fabric-tools:2.5 \
  bash -lc "peer channel getinfo -c traceops"
```

Expected output includes `height`.

## 3) Fetch newest block

```bash
docker run --rm \
  --network traceops \
  -v "$PWD/zone2-ledger/crypto:/crypto" \
  -e CORE_PEER_TLS_ENABLED=true \
  -e CORE_PEER_LOCALMSPID="$MSP" \
  -e CORE_PEER_ADDRESS="$PEER" \
  -e CORE_PEER_MSPCONFIGPATH="/crypto/organizations/peerOrganizations/$ORG_DOMAIN/users/Admin@$ORG_DOMAIN/msp" \
  -e CORE_PEER_TLS_ROOTCERT_FILE="/crypto/organizations/peerOrganizations/$ORG_DOMAIN/peers/peer0.$ORG_DOMAIN/tls/ca.crt" \
  -e CORE_PEER_TLS_CLIENTAUTHREQUIRED=true \
  -e CORE_PEER_TLS_CLIENTCERT_FILE="/crypto/organizations/peerOrganizations/$ORG_DOMAIN/peers/peer0.$ORG_DOMAIN/tls/server.crt" \
  -e CORE_PEER_TLS_CLIENTKEY_FILE="/crypto/organizations/peerOrganizations/$ORG_DOMAIN/peers/peer0.$ORG_DOMAIN/tls/server.key" \
  hyperledger/fabric-tools:2.5 \
  bash -lc "peer channel fetch newest /crypto/channel-artifacts/newest.block -c traceops -o orderer0.traceops.local:7050 --tls --cafile /crypto/organizations/ordererOrganizations/traceops.local/orderers/orderer0.traceops.local/tls/ca.crt --clientauth --certfile /crypto/organizations/peerOrganizations/$ORG_DOMAIN/peers/peer0.$ORG_DOMAIN/tls/server.crt --keyfile /crypto/organizations/peerOrganizations/$ORG_DOMAIN/peers/peer0.$ORG_DOMAIN/tls/server.key"
```

## 4) Decode block to JSON

```bash
docker run --rm \
  -v "$PWD/zone2-ledger/crypto:/crypto" \
  hyperledger/fabric-tools:2.5 \
  bash -lc "configtxlator proto_decode --type common.Block --input /crypto/channel-artifacts/newest.block > /crypto/channel-artifacts/newest.json"
```

Read it:

```bash
python3 -m json.tool zone2-ledger/crypto/channel-artifacts/newest.json | less
```

## 5) Fetch a specific block (example: block 3)

```bash
docker run --rm \
  --network traceops \
  -v "$PWD/zone2-ledger/crypto:/crypto" \
  -e CORE_PEER_TLS_ENABLED=true \
  -e CORE_PEER_LOCALMSPID="$MSP" \
  -e CORE_PEER_ADDRESS="$PEER" \
  -e CORE_PEER_MSPCONFIGPATH="/crypto/organizations/peerOrganizations/$ORG_DOMAIN/users/Admin@$ORG_DOMAIN/msp" \
  -e CORE_PEER_TLS_ROOTCERT_FILE="/crypto/organizations/peerOrganizations/$ORG_DOMAIN/peers/peer0.$ORG_DOMAIN/tls/ca.crt" \
  -e CORE_PEER_TLS_CLIENTAUTHREQUIRED=true \
  -e CORE_PEER_TLS_CLIENTCERT_FILE="/crypto/organizations/peerOrganizations/$ORG_DOMAIN/peers/peer0.$ORG_DOMAIN/tls/server.crt" \
  -e CORE_PEER_TLS_CLIENTKEY_FILE="/crypto/organizations/peerOrganizations/$ORG_DOMAIN/peers/peer0.$ORG_DOMAIN/tls/server.key" \
  hyperledger/fabric-tools:2.5 \
  bash -lc "peer channel fetch 3 /crypto/channel-artifacts/block3.block -c traceops -o orderer0.traceops.local:7050 --tls --cafile /crypto/organizations/ordererOrganizations/traceops.local/orderers/orderer0.traceops.local/tls/ca.crt --clientauth --certfile /crypto/organizations/peerOrganizations/$ORG_DOMAIN/peers/peer0.$ORG_DOMAIN/tls/server.crt --keyfile /crypto/organizations/peerOrganizations/$ORG_DOMAIN/peers/peer0.$ORG_DOMAIN/tls/server.key"
```

```bash
docker run --rm \
  -v "$PWD/zone2-ledger/crypto:/crypto" \
  hyperledger/fabric-tools:2.5 \
  bash -lc "configtxlator proto_decode --type common.Block --input /crypto/channel-artifacts/block3.block > /crypto/channel-artifacts/block3.json"
```

```bash
python3 -m json.tool zone2-ledger/crypto/channel-artifacts/block3.json | less
```

## Common pitfalls

- mTLS is required on peers; always provide `CORE_PEER_TLS_CLIENTCERT_FILE` and `CORE_PEER_TLS_CLIENTKEY_FILE`.
- Ensure org variables are set (`MSP`, `PEER`, `ORG_DOMAIN`) before running commands.
- Do not put a space after `\` in multiline commands.
