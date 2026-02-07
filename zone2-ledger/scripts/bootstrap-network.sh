#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
COMPOSE_FILE="${ROOT_DIR}/compose/docker-compose.yaml"

CHANNEL_NAME=${CHANNEL_NAME:-traceops}
NETWORK_NAME=${NETWORK_NAME:-traceops}
TOOLS_IMAGE=${TOOLS_IMAGE:-hyperledger/fabric-tools:2.5}
CLEAN_START=${CLEAN_START:-true}

compose() {
  docker compose -f "${COMPOSE_FILE}" "$@"
}

wait_for_ca() {
  local retries=40
  local delay=2
  local i

  for i in $(seq 1 "${retries}"); do
    if curl -s "http://localhost:7054/cainfo" >/dev/null 2>&1; then
      return 0
    fi
    sleep "${delay}"
  done

  echo "Fabric CA did not become ready in time" >&2
  exit 1
}

extract_ca_cert() {
  mkdir -p "${ROOT_DIR}/crypto/ca"
  docker cp "ca.traceops.local:/etc/hyperledger/fabric-ca-server/ca-cert.pem" "${ROOT_DIR}/crypto/ca/ca-cert.pem"
}

run_peer_cli() {
  local org=$1
  local command=$2

  local msp_id
  local peer_address
  local admin_msp
  local tls_root
  local tls_cert
  local tls_key

  case "${org}" in
    orgj2)
      msp_id="OrgJ2MSP"
      peer_address="peer0.orgj2.traceops.local:7051"
      admin_msp="/crypto/organizations/peerOrganizations/orgj2.traceops.local/users/Admin@orgj2.traceops.local/msp"
      tls_root="/crypto/organizations/peerOrganizations/orgj2.traceops.local/peers/peer0.orgj2.traceops.local/tls/ca.crt"
      tls_cert="/crypto/organizations/peerOrganizations/orgj2.traceops.local/peers/peer0.orgj2.traceops.local/tls/server.crt"
      tls_key="/crypto/organizations/peerOrganizations/orgj2.traceops.local/peers/peer0.orgj2.traceops.local/tls/server.key"
      ;;
    orgem)
      msp_id="OrgEMMSP"
      peer_address="peer0.orgem.traceops.local:9051"
      admin_msp="/crypto/organizations/peerOrganizations/orgem.traceops.local/users/Admin@orgem.traceops.local/msp"
      tls_root="/crypto/organizations/peerOrganizations/orgem.traceops.local/peers/peer0.orgem.traceops.local/tls/ca.crt"
      tls_cert="/crypto/organizations/peerOrganizations/orgem.traceops.local/peers/peer0.orgem.traceops.local/tls/server.crt"
      tls_key="/crypto/organizations/peerOrganizations/orgem.traceops.local/peers/peer0.orgem.traceops.local/tls/server.key"
      ;;
    *)
      echo "Unsupported org '${org}'" >&2
      exit 1
      ;;
  esac

  docker run --rm \
    --network "${NETWORK_NAME}" \
    -v "${ROOT_DIR}/crypto:/crypto" \
    -e CORE_PEER_TLS_ENABLED=true \
    -e CORE_PEER_LOCALMSPID="${msp_id}" \
    -e CORE_PEER_ADDRESS="${peer_address}" \
    -e CORE_PEER_MSPCONFIGPATH="${admin_msp}" \
    -e CORE_PEER_TLS_ROOTCERT_FILE="${tls_root}" \
    -e CORE_PEER_TLS_CLIENTCERT_FILE="${tls_cert}" \
    -e CORE_PEER_TLS_CLIENTKEY_FILE="${tls_key}" \
    "${TOOLS_IMAGE}" \
    bash -c "${command}"
}

echo "[1/6] Starting CA and CouchDB services"
if [ "${CLEAN_START}" = "true" ]; then
  echo "Cleaning previous crypto artifacts for a fresh bootstrap"
  compose down -v >/dev/null 2>&1 || true
  rm -rf "${ROOT_DIR}/crypto/ca" "${ROOT_DIR}/crypto/organizations" "${ROOT_DIR}/crypto/channel-artifacts" "${ROOT_DIR}/crypto/fabric-ca-client"
fi

compose up -d ca.traceops.local couchdb0.orgj2.traceops.local couchdb0.orgem.traceops.local

echo "[2/6] Waiting for CA readiness and exporting TLS certificate"
wait_for_ca
extract_ca_cert

echo "[3/6] Bootstrapping identities via Fabric CA"
"${ROOT_DIR}/scripts/ca-bootstrap.sh"

echo "[4/6] Generating genesis/channel/anchor artifacts"
"${ROOT_DIR}/scripts/generate-channel-artifacts.sh"

echo "[5/6] Starting orderers and peers"
compose up -d orderer0.traceops.local orderer1.traceops.local peer0.orgj2.traceops.local peer0.orgem.traceops.local
sleep 6

ORDERER_CA="/crypto/organizations/ordererOrganizations/traceops.local/orderers/orderer0.traceops.local/tls/ca.crt"
CHANNEL_TX="/crypto/channel-artifacts/${CHANNEL_NAME}.tx"
CHANNEL_BLOCK="/crypto/channel-artifacts/${CHANNEL_NAME}.block"

echo "[6/6] Creating channel, joining peers, and setting anchor peers"
run_peer_cli orgj2 "peer channel create -o orderer0.traceops.local:7050 -c ${CHANNEL_NAME} -f ${CHANNEL_TX} --outputBlock ${CHANNEL_BLOCK} --tls --cafile ${ORDERER_CA} --clientauth --certfile /crypto/organizations/peerOrganizations/orgj2.traceops.local/peers/peer0.orgj2.traceops.local/tls/server.crt --keyfile /crypto/organizations/peerOrganizations/orgj2.traceops.local/peers/peer0.orgj2.traceops.local/tls/server.key"

run_peer_cli orgj2 "peer channel join -b ${CHANNEL_BLOCK}"
run_peer_cli orgem "peer channel join -b ${CHANNEL_BLOCK}"

run_peer_cli orgj2 "peer channel update -o orderer0.traceops.local:7050 -c ${CHANNEL_NAME} -f /crypto/channel-artifacts/OrgJ2MSPanchors.tx --tls --cafile ${ORDERER_CA} --clientauth --certfile /crypto/organizations/peerOrganizations/orgj2.traceops.local/peers/peer0.orgj2.traceops.local/tls/server.crt --keyfile /crypto/organizations/peerOrganizations/orgj2.traceops.local/peers/peer0.orgj2.traceops.local/tls/server.key"
run_peer_cli orgem "peer channel update -o orderer0.traceops.local:7050 -c ${CHANNEL_NAME} -f /crypto/channel-artifacts/OrgEMMSPanchors.tx --tls --cafile ${ORDERER_CA} --clientauth --certfile /crypto/organizations/peerOrganizations/orgem.traceops.local/peers/peer0.orgem.traceops.local/tls/server.crt --keyfile /crypto/organizations/peerOrganizations/orgem.traceops.local/peers/peer0.orgem.traceops.local/tls/server.key"

echo "Network bootstrap completed for channel '${CHANNEL_NAME}'."
