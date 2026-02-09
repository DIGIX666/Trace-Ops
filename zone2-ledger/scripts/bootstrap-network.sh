#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
COMPOSE_FILE="${ROOT_DIR}/compose/docker-compose.yaml"

CHANNEL_NAME=${CHANNEL_NAME:-traceops}
NETWORK_NAME=${NETWORK_NAME:-traceops}
TOOLS_IMAGE=${TOOLS_IMAGE:-hyperledger/fabric-tools:2.5}
CLEAN_START=${CLEAN_START:-true}

compose() {
  # Keep compose file location centralized for every compose call
  docker compose -f "${COMPOSE_FILE}" "$@"
}

wait_for_ca() {
  # CA may take a few seconds; poll cainfo before running enroll/register
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
  # Export CA certificate to the host path consumed by follow-up scripts
  mkdir -p "${ROOT_DIR}/crypto/ca"
  docker cp "ca.traceops.local:/etc/hyperledger/fabric-ca-server/ca-cert.pem" "${ROOT_DIR}/crypto/ca/ca-cert.pem"
}

run_peer_cli() {
  # Execute peer CLI as a tools container with org-specific identity and TLS
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
    -e CORE_PEER_TLS_CLIENTAUTHREQUIRED=true \
    -e CORE_PEER_TLS_CLIENTCERT_FILE="${tls_cert}" \
    -e CORE_PEER_TLS_CLIENTKEY_FILE="${tls_key}" \
    "${TOOLS_IMAGE}" \
    bash -c "${command}"
}

sync_zone1_wallet() {
  # Mirror OrgEM admin cert/key into Zone1 wallet for backend-em Fabric client
  local zone1_root="${ROOT_DIR}/../zone1"
  local zone1_wallet="${zone1_root}/wallet"
  local orgem_admin_msp="${ROOT_DIR}/crypto/organizations/peerOrganizations/orgem.traceops.local/users/Admin@orgem.traceops.local/msp"
  local cert_src="${orgem_admin_msp}/signcerts/cert.pem"
  local key_files
  local key_src

  if [ ! -d "${zone1_root}" ]; then
    echo "Zone1 workspace not found at ${zone1_root}, skipping wallet sync."
    return 0
  fi

  if [ ! -f "${cert_src}" ]; then
    echo "Missing OrgEM admin cert at ${cert_src}" >&2
    return 1
  fi

  shopt -s nullglob
  key_files=("${orgem_admin_msp}/keystore/"*_sk)
  shopt -u nullglob

  if [ "${#key_files[@]}" -eq 0 ]; then
    echo "Missing OrgEM admin private key (*_sk) in ${orgem_admin_msp}/keystore" >&2
    return 1
  fi

  key_src="${key_files[0]}"

  mkdir -p "${zone1_wallet}"
  cp -f "${cert_src}" "${zone1_wallet}/cert.pem"
  cp -f "${key_src}" "${zone1_wallet}/"
  chmod 644 "${zone1_wallet}/cert.pem" "${zone1_wallet}/$(basename "${key_src}")"

  echo "Synced Zone1 wallet from OrgEM admin MSP:"
  echo "- ${zone1_wallet}/cert.pem"
  echo "- ${zone1_wallet}/$(basename "${key_src}")"
}

echo "[1/6] Starting CA and CouchDB services"
if [ "${CLEAN_START}" = "true" ]; then
  echo "Cleaning previous crypto artifacts for a fresh bootstrap"
  # Full cleanup keeps MSP/certs/channel artifacts aligned with generated config
  compose down -v >/dev/null 2>&1 || true
  rm -rf "${ROOT_DIR}/crypto/ca" "${ROOT_DIR}/crypto/organizations" "${ROOT_DIR}/crypto/channel-artifacts" "${ROOT_DIR}/crypto/fabric-ca-client"
fi

compose up -d ca.traceops.local couchdb0.orgj2.traceops.local couchdb0.orgem.traceops.local

echo "[2/6] Waiting for CA readiness and exporting TLS certificate"
wait_for_ca
extract_ca_cert

echo "[3/6] Bootstrapping identities via Fabric CA"
"${ROOT_DIR}/scripts/ca-bootstrap.sh"

echo "[3b/6] Syncing Zone1 wallet artifacts"
sync_zone1_wallet

echo "[4/6] Generating genesis/channel/anchor artifacts"
"${ROOT_DIR}/scripts/generate-channel-artifacts.sh"

echo "[5/6] Starting orderers and peers"
compose up -d orderer0.traceops.local orderer1.traceops.local peer0.orgj2.traceops.local peer0.orgem.traceops.local
sleep 6

ORDERER_CA="/crypto/organizations/ordererOrganizations/traceops.local/orderers/orderer0.traceops.local/tls/ca.crt"
CHANNEL_TX="/crypto/channel-artifacts/${CHANNEL_NAME}.tx"
CHANNEL_BLOCK="/crypto/channel-artifacts/${CHANNEL_NAME}.block"

echo "[6/6] Creating channel, joining peers, and setting anchor peers"
# Channel create uses OrgJ2 admin; both org peers then join and set anchors
run_peer_cli orgj2 "peer channel create -o orderer0.traceops.local:7050 -c ${CHANNEL_NAME} -f ${CHANNEL_TX} --outputBlock ${CHANNEL_BLOCK} --tls --cafile ${ORDERER_CA} --clientauth --certfile /crypto/organizations/peerOrganizations/orgj2.traceops.local/peers/peer0.orgj2.traceops.local/tls/server.crt --keyfile /crypto/organizations/peerOrganizations/orgj2.traceops.local/peers/peer0.orgj2.traceops.local/tls/server.key"

run_peer_cli orgj2 "peer channel join -b ${CHANNEL_BLOCK}"
run_peer_cli orgem "peer channel join -b ${CHANNEL_BLOCK}"

run_peer_cli orgj2 "peer channel update -o orderer0.traceops.local:7050 -c ${CHANNEL_NAME} -f /crypto/channel-artifacts/OrgJ2MSPanchors.tx --tls --cafile ${ORDERER_CA} --clientauth --certfile /crypto/organizations/peerOrganizations/orgj2.traceops.local/peers/peer0.orgj2.traceops.local/tls/server.crt --keyfile /crypto/organizations/peerOrganizations/orgj2.traceops.local/peers/peer0.orgj2.traceops.local/tls/server.key"
run_peer_cli orgem "peer channel update -o orderer0.traceops.local:7050 -c ${CHANNEL_NAME} -f /crypto/channel-artifacts/OrgEMMSPanchors.tx --tls --cafile ${ORDERER_CA} --clientauth --certfile /crypto/organizations/peerOrganizations/orgem.traceops.local/peers/peer0.orgem.traceops.local/tls/server.crt --keyfile /crypto/organizations/peerOrganizations/orgem.traceops.local/peers/peer0.orgem.traceops.local/tls/server.key"

echo "Network bootstrap completed for channel '${CHANNEL_NAME}'."
echo "Next step: run ${ROOT_DIR}/scripts/deploy-chaincode.sh"
