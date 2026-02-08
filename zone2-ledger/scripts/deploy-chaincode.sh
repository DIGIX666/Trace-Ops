#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

CHANNEL_NAME=${CHANNEL_NAME:-traceops}
CHAINCODE_NAME=${CHAINCODE_NAME:-decision}
CHAINCODE_LABEL=${CHAINCODE_LABEL:-decision_1.0}
CHAINCODE_VERSION=${CHAINCODE_VERSION:-1.0}
CHAINCODE_SEQUENCE=${CHAINCODE_SEQUENCE:-1}
CHAINCODE_SRC=${CHAINCODE_SRC:-/workspace/chaincode/decision}
CHAINCODE_PACKAGE=${CHAINCODE_PACKAGE:-/workspace/crypto/channel-artifacts/${CHAINCODE_LABEL}.tar.gz}
CHAINCODE_LANG=${CHAINCODE_LANG:-golang}
ENDORSEMENT_POLICY=${ENDORSEMENT_POLICY:-"AND('OrgJ2MSP.member','OrgEMMSP.member')"}

NETWORK_NAME=${NETWORK_NAME:-traceops}
TOOLS_IMAGE=${TOOLS_IMAGE:-hyperledger/fabric-tools:2.5}
RUN_SMOKE_TEST=${RUN_SMOKE_TEST:-true}
WAIT_FOR_EVENT_TIMEOUT=${WAIT_FOR_EVENT_TIMEOUT:-120s}

ORDERER_ADDR=${ORDERER_ADDR:-orderer0.traceops.local:7050}
ORDERER_CA=/crypto/organizations/ordererOrganizations/traceops.local/orderers/orderer0.traceops.local/tls/ca.crt

PEER_J2_ADDR=peer0.orgj2.traceops.local:7051
PEER_J2_TLS=/crypto/organizations/peerOrganizations/orgj2.traceops.local/peers/peer0.orgj2.traceops.local/tls/ca.crt
PEER_EM_ADDR=peer0.orgem.traceops.local:9051
PEER_EM_TLS=/crypto/organizations/peerOrganizations/orgem.traceops.local/peers/peer0.orgem.traceops.local/tls/ca.crt

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
      peer_address="${PEER_J2_ADDR}"
      admin_msp="/crypto/organizations/peerOrganizations/orgj2.traceops.local/users/Admin@orgj2.traceops.local/msp"
      tls_root="${PEER_J2_TLS}"
      tls_cert="/crypto/organizations/peerOrganizations/orgj2.traceops.local/peers/peer0.orgj2.traceops.local/tls/server.crt"
      tls_key="/crypto/organizations/peerOrganizations/orgj2.traceops.local/peers/peer0.orgj2.traceops.local/tls/server.key"
      ;;
    orgem)
      msp_id="OrgEMMSP"
      peer_address="${PEER_EM_ADDR}"
      admin_msp="/crypto/organizations/peerOrganizations/orgem.traceops.local/users/Admin@orgem.traceops.local/msp"
      tls_root="${PEER_EM_TLS}"
      tls_cert="/crypto/organizations/peerOrganizations/orgem.traceops.local/peers/peer0.orgem.traceops.local/tls/server.crt"
      tls_key="/crypto/organizations/peerOrganizations/orgem.traceops.local/peers/peer0.orgem.traceops.local/tls/server.key"
      ;;
    *)
      echo "Unsupported org '${org}'" >&2
      exit 1
      ;;
  esac

  # Run peer CLI in a disposable tools container with org-specific identity
  docker run --rm \
    --network "${NETWORK_NAME}" \
    -v "${ROOT_DIR}:/workspace" \
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

if [ ! -d "${ROOT_DIR}/crypto/organizations" ]; then
  echo "Missing crypto organizations under ${ROOT_DIR}/crypto/organizations" >&2
  echo "Run bootstrap-network.sh first." >&2
  exit 1
fi

echo "[1/7] Packaging chaincode ${CHAINCODE_NAME}"
# Package is generated from current source and label; reruns may produce new package IDs
run_peer_cli orgj2 "peer lifecycle chaincode package ${CHAINCODE_PACKAGE} --path ${CHAINCODE_SRC} --lang ${CHAINCODE_LANG} --label ${CHAINCODE_LABEL}"

echo "[2/7] Installing chaincode package on both peers"
install_on_org() {
  local org=$1
  local output

  set +e
  output=$(run_peer_cli "${org}" "peer lifecycle chaincode install ${CHAINCODE_PACKAGE}" 2>&1)
  local rc=$?
  set -e

  if [ "${rc}" -eq 0 ]; then
    printf '%s\n' "${output}"
    return
  fi

  # Re-runs are expected during debug; treat already-installed as success
  if printf '%s\n' "${output}" | grep -qi "already successfully installed"; then
    printf '%s\n' "${output}"
    return
  fi

  printf '%s\n' "${output}" >&2
  exit "${rc}"
}

install_on_org orgj2
install_on_org orgem

installed_output=$(run_peer_cli orgj2 "peer lifecycle chaincode queryinstalled")
package_id=$(printf '%s\n' "${installed_output}" | sed -n "s/^Package ID: \([^,]*\), Label: ${CHAINCODE_LABEL}$/\1/p" | head -n 1)

if [ -z "${package_id}" ]; then
  echo "Unable to resolve package ID for label '${CHAINCODE_LABEL}'" >&2
  echo "queryinstalled output:" >&2
  printf '%s\n' "${installed_output}" >&2
  exit 1
fi

echo "Resolved package ID: ${package_id}"

set +e
# Namespace not found is normal before the first commit; other errors must fail fast
already_committed=$(run_peer_cli orgj2 "peer lifecycle chaincode querycommitted -C ${CHANNEL_NAME} --name ${CHAINCODE_NAME}" 2>&1)
already_committed_rc=$?
set -e

if [ "${already_committed_rc}" -ne 0 ] && ! printf '%s\n' "${already_committed}" | grep -q "404 - namespace ${CHAINCODE_NAME} is not defined"; then
  printf '%s\n' "${already_committed}" >&2
  exit "${already_committed_rc}"
fi

if printf '%s\n' "${already_committed}" | grep -q "Version: ${CHAINCODE_VERSION}, Sequence: ${CHAINCODE_SEQUENCE}"; then
  echo "Chaincode ${CHAINCODE_NAME} already committed at version ${CHAINCODE_VERSION} sequence ${CHAINCODE_SEQUENCE}."
  exit 0
fi

echo "[3/7] Approving definition for OrgJ2"
run_peer_cli orgj2 "peer lifecycle chaincode approveformyorg -o ${ORDERER_ADDR} --channelID ${CHANNEL_NAME} --name ${CHAINCODE_NAME} --version ${CHAINCODE_VERSION} --package-id ${package_id} --sequence ${CHAINCODE_SEQUENCE} --signature-policy \"${ENDORSEMENT_POLICY}\" --tls --cafile ${ORDERER_CA} --clientauth --certfile /crypto/organizations/peerOrganizations/orgj2.traceops.local/peers/peer0.orgj2.traceops.local/tls/server.crt --keyfile /crypto/organizations/peerOrganizations/orgj2.traceops.local/peers/peer0.orgj2.traceops.local/tls/server.key --waitForEventTimeout ${WAIT_FOR_EVENT_TIMEOUT}"

echo "[4/7] Approving definition for OrgEM"
run_peer_cli orgem "peer lifecycle chaincode approveformyorg -o ${ORDERER_ADDR} --channelID ${CHANNEL_NAME} --name ${CHAINCODE_NAME} --version ${CHAINCODE_VERSION} --package-id ${package_id} --sequence ${CHAINCODE_SEQUENCE} --signature-policy \"${ENDORSEMENT_POLICY}\" --tls --cafile ${ORDERER_CA} --clientauth --certfile /crypto/organizations/peerOrganizations/orgem.traceops.local/peers/peer0.orgem.traceops.local/tls/server.crt --keyfile /crypto/organizations/peerOrganizations/orgem.traceops.local/peers/peer0.orgem.traceops.local/tls/server.key --waitForEventTimeout ${WAIT_FOR_EVENT_TIMEOUT}"

echo "[5/7] Verifying commit readiness"
# Both org approvals must be true before commit
run_peer_cli orgj2 "peer lifecycle chaincode checkcommitreadiness -C ${CHANNEL_NAME} --name ${CHAINCODE_NAME} --version ${CHAINCODE_VERSION} --sequence ${CHAINCODE_SEQUENCE} --signature-policy \"${ENDORSEMENT_POLICY}\" --output json"

echo "[6/7] Committing chaincode definition"
run_peer_cli orgj2 "peer lifecycle chaincode commit -o ${ORDERER_ADDR} --channelID ${CHANNEL_NAME} --name ${CHAINCODE_NAME} --version ${CHAINCODE_VERSION} --sequence ${CHAINCODE_SEQUENCE} --signature-policy \"${ENDORSEMENT_POLICY}\" --tls --cafile ${ORDERER_CA} --clientauth --certfile /crypto/organizations/peerOrganizations/orgj2.traceops.local/peers/peer0.orgj2.traceops.local/tls/server.crt --keyfile /crypto/organizations/peerOrganizations/orgj2.traceops.local/peers/peer0.orgj2.traceops.local/tls/server.key --peerAddresses ${PEER_J2_ADDR} --tlsRootCertFiles ${PEER_J2_TLS} --peerAddresses ${PEER_EM_ADDR} --tlsRootCertFiles ${PEER_EM_TLS} --waitForEventTimeout ${WAIT_FOR_EVENT_TIMEOUT}"

echo "[7/7] Querying committed definition"
run_peer_cli orgj2 "peer lifecycle chaincode querycommitted -C ${CHANNEL_NAME} --name ${CHAINCODE_NAME}"

if [ "${RUN_SMOKE_TEST}" = "true" ]; then
  echo "Running smoke test invoke/query"
  # Use unique IDs so smoke tests are repeatable across multiple runs
  smoke_id="smoke-$(date +%s)"
  payload='{"actor":"zone1","decision":"APPROVED","reason":"smoke-test"}'
  app_hash=$(python3 -c 'import hashlib, json; payload={"actor":"zone1","decision":"APPROVED","reason":"smoke-test"}; canon=json.dumps(payload, separators=(",", ":"), sort_keys=True); print(hashlib.sha256(canon.encode()).hexdigest())')
  payload_escaped=$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "${payload}")

  run_peer_cli orgj2 "peer chaincode invoke -o ${ORDERER_ADDR} --tls --cafile ${ORDERER_CA} --clientauth --certfile /crypto/organizations/peerOrganizations/orgj2.traceops.local/peers/peer0.orgj2.traceops.local/tls/server.crt --keyfile /crypto/organizations/peerOrganizations/orgj2.traceops.local/peers/peer0.orgj2.traceops.local/tls/server.key -C ${CHANNEL_NAME} -n ${CHAINCODE_NAME} --peerAddresses ${PEER_J2_ADDR} --tlsRootCertFiles ${PEER_J2_TLS} --peerAddresses ${PEER_EM_ADDR} --tlsRootCertFiles ${PEER_EM_TLS} -c '{\"Args\":[\"SubmitDecision\",\"${smoke_id}\",${payload_escaped},\"${app_hash}\"]}'"

  sleep 3
  run_peer_cli orgj2 "peer chaincode query -C ${CHANNEL_NAME} -n ${CHAINCODE_NAME} -c '{\"Args\":[\"QueryDecision\",\"${smoke_id}\"]}'"
fi

echo "Chaincode deployment completed for '${CHAINCODE_NAME}' on channel '${CHANNEL_NAME}'."
