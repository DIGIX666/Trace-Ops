#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CONFIG_ENV="${ROOT_DIR}/config/ca.env"

if [ -f "${CONFIG_ENV}" ]; then
  set -a
  . "${CONFIG_ENV}"
  set +a
fi

CA_NAME=${CA_NAME:-ca-traceops}
CA_HOST=${CA_HOST:-ca.traceops.local}
CA_PORT=${CA_PORT:-7054}
CA_SCHEME=${CA_SCHEME:-http}
CA_ADMIN=${CA_ADMIN:-admin}
CA_ADMIN_PW=${CA_ADMIN_PW:-adminpw}

DOMAIN=${DOMAIN:-traceops.local}
ORG_J2=${ORG_J2:-orgj2}
ORG_EM=${ORG_EM:-orgem}
ORDERER_ORG=${ORDERER_ORG:-orderer}
ORDERER0=${ORDERER0:-orderer0}
ORDERER1=${ORDERER1:-orderer1}

CRYPTO_DIR="${ROOT_DIR}/crypto"
ORG_DIR="${CRYPTO_DIR}/organizations"
CA_TLS_CERT=${CA_TLS_CERT:-"/crypto/ca/ca-cert.pem"}
CA_TLS_CERT_HOST=${CA_TLS_CERT_HOST:-"${CRYPTO_DIR}/ca/ca-cert.pem"}
CA_URL="${CA_SCHEME}://${CA_ADMIN}:${CA_ADMIN_PW}@${CA_HOST}:${CA_PORT}"
TOOLS_IMAGE=${TOOLS_IMAGE:-"hyperledger/fabric-ca:1.5.16"}
NETWORK_NAME=${NETWORK_NAME:-"traceops"}

command -v docker >/dev/null 2>&1 || {
  echo "docker not found in PATH" >&2
  exit 1
}

TLS_ARGS=()
if [ "${CA_SCHEME}" = "https" ]; then
  if [ ! -f "${CA_TLS_CERT_HOST}" ]; then
    echo "CA TLS cert not found at ${CA_TLS_CERT_HOST}" >&2
    exit 1
  fi
  TLS_ARGS=(--tls.certfiles "${CA_TLS_CERT}")
fi

run_ca_client() {
  local client_home=$1
  shift
  docker run --rm \
    --network "${NETWORK_NAME}" \
    -v "${CRYPTO_DIR}:/crypto" \
    -v "${ROOT_DIR}/config:/config" \
    -e FABRIC_CA_CLIENT_HOME="${client_home}" \
    "${TOOLS_IMAGE}" \
    fabric-ca-client "$@"
}

mkdir -p "${CRYPTO_DIR}/fabric-ca-client"
run_ca_client "/crypto/fabric-ca-client" enroll -u "${CA_URL}" --caname "${CA_NAME}" "${TLS_ARGS[@]}"

register_id() {
  local name=$1
  local secret=$2
  local type=$3
  run_ca_client "/crypto/fabric-ca-client" register \
    --caname "${CA_NAME}" \
    --id.name "${name}" \
    --id.secret "${secret}" \
    --id.type "${type}" \
    "${TLS_ARGS[@]}"
}

register_id "${ORG_J2}admin" "${ORG_J2}adminpw" admin
register_id "peer0.${ORG_J2}" "peer0${ORG_J2}pw" peer
register_id "${ORG_EM}admin" "${ORG_EM}adminpw" admin
register_id "peer0.${ORG_EM}" "peer0${ORG_EM}pw" peer
register_id "${ORDERER_ORG}admin" "${ORDERER_ORG}adminpw" admin
register_id "${ORDERER0}" "${ORDERER0}pw" orderer
register_id "${ORDERER1}" "${ORDERER1}pw" orderer

setup_tls_files() {
  local tls_dir=$1
  local ca_file
  local signcert
  local keystore

  ca_file=$(ls "${tls_dir}/tlscacerts" | head -n 1)
  signcert=$(ls "${tls_dir}/signcerts" | head -n 1)
  keystore=$(ls "${tls_dir}/keystore" | head -n 1)

  cp "${tls_dir}/tlscacerts/${ca_file}" "${tls_dir}/ca.crt"
  cp "${tls_dir}/signcerts/${signcert}" "${tls_dir}/server.crt"
  cp "${tls_dir}/keystore/${keystore}" "${tls_dir}/server.key"
}

setup_org_tls_ca() {
  local org_root=$1
  local tls_source_dir=$2
  local ca_file
  ca_file=$(ls "${tls_source_dir}/tlscacerts" | head -n 1)
  mkdir -p "${org_root}/tlscacerts" "${org_root}/msp/tlscacerts"
  cp "${tls_source_dir}/tlscacerts/${ca_file}" "${org_root}/tlscacerts/ca.crt"
  cp "${tls_source_dir}/tlscacerts/${ca_file}" "${org_root}/msp/tlscacerts/ca.crt"
}

setup_node_tls_ca() {
  local node_msp_dir=$1
  local node_tls_dir=$2
  local ca_file

  ca_file=$(ls "${node_tls_dir}/tlscacerts" | head -n 1)
  mkdir -p "${node_msp_dir}/tlscacerts"
  cp "${node_tls_dir}/tlscacerts/${ca_file}" "${node_msp_dir}/tlscacerts/ca.crt"
}

create_org_msp() {
  local org=$1
  local org_domain="${org}.${DOMAIN}"
  local peer="peer0.${org_domain}"
  local org_root="${ORG_DIR}/peerOrganizations/${org_domain}"
  local org_root_in_container="/crypto/organizations/peerOrganizations/${org_domain}"

  mkdir -p "${org_root}"

  run_ca_client "/crypto/organizations/peerOrganizations/${org_domain}" enroll -u "${CA_SCHEME}://${org}admin:${org}adminpw@${CA_HOST}:${CA_PORT}" \
    --caname "${CA_NAME}" \
    "${TLS_ARGS[@]}"

  local ca_cert_file
  ca_cert_file=$(ls "${org_root}/msp/cacerts")

  cat > "${org_root}/msp/config.yaml" <<EOF
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/${ca_cert_file}
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/${ca_cert_file}
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/${ca_cert_file}
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/${ca_cert_file}
    OrganizationalUnitIdentifier: orderer
EOF

  mkdir -p "${org_root}/peers/${peer}/msp"
  run_ca_client "/crypto/organizations/peerOrganizations/${org_domain}" enroll -u "${CA_SCHEME}://peer0.${org}:peer0${org}pw@${CA_HOST}:${CA_PORT}" \
    --caname "${CA_NAME}" \
    "${TLS_ARGS[@]}" \
    --mspdir "${org_root_in_container}/peers/${peer}/msp"

  cp "${org_root}/msp/config.yaml" "${org_root}/peers/${peer}/msp/config.yaml"

  run_ca_client "/crypto/organizations/peerOrganizations/${org_domain}" enroll -u "${CA_SCHEME}://peer0.${org}:peer0${org}pw@${CA_HOST}:${CA_PORT}" \
    --caname "${CA_NAME}" \
    "${TLS_ARGS[@]}" \
    --enrollment.profile tls \
    --csr.hosts "${peer}" \
    --csr.hosts "localhost" \
    --mspdir "${org_root_in_container}/peers/${peer}/tls"

  setup_tls_files "${org_root}/peers/${peer}/tls"
  setup_node_tls_ca "${org_root}/peers/${peer}/msp" "${org_root}/peers/${peer}/tls"

  mkdir -p "${org_root}/users/Admin@${org_domain}/msp"
  run_ca_client "/crypto/organizations/peerOrganizations/${org_domain}" enroll -u "${CA_SCHEME}://${org}admin:${org}adminpw@${CA_HOST}:${CA_PORT}" \
    --caname "${CA_NAME}" \
    "${TLS_ARGS[@]}" \
    --mspdir "${org_root_in_container}/users/Admin@${org_domain}/msp"

  cp "${org_root}/msp/config.yaml" "${org_root}/users/Admin@${org_domain}/msp/config.yaml"

  setup_org_tls_ca "${org_root}" "${org_root}/peers/${peer}/tls"
}

create_orderer_org_msp() {
  local org_domain="${DOMAIN}"
  local org_root="${ORG_DIR}/ordererOrganizations/${org_domain}"
  local org_root_in_container="/crypto/organizations/ordererOrganizations/${org_domain}"

  mkdir -p "${org_root}"

  run_ca_client "/crypto/organizations/ordererOrganizations/${org_domain}" enroll -u "${CA_SCHEME}://${ORDERER_ORG}admin:${ORDERER_ORG}adminpw@${CA_HOST}:${CA_PORT}" \
    --caname "${CA_NAME}" \
    "${TLS_ARGS[@]}"

  local ca_cert_file
  ca_cert_file=$(ls "${org_root}/msp/cacerts")

  cat > "${org_root}/msp/config.yaml" <<EOF
NodeOUs:
  Enable: true
  ClientOUIdentifier:
    Certificate: cacerts/${ca_cert_file}
    OrganizationalUnitIdentifier: client
  PeerOUIdentifier:
    Certificate: cacerts/${ca_cert_file}
    OrganizationalUnitIdentifier: peer
  AdminOUIdentifier:
    Certificate: cacerts/${ca_cert_file}
    OrganizationalUnitIdentifier: admin
  OrdererOUIdentifier:
    Certificate: cacerts/${ca_cert_file}
    OrganizationalUnitIdentifier: orderer
EOF

  create_orderer() {
    local orderer_name=$1
    local orderer_fqdn="${orderer_name}.${org_domain}"
    local orderer_dir="${org_root}/orderers/${orderer_fqdn}"
    local orderer_dir_in_container="${org_root_in_container}/orderers/${orderer_fqdn}"

    mkdir -p "${orderer_dir}/msp"
    run_ca_client "/crypto/organizations/ordererOrganizations/${org_domain}" enroll -u "${CA_SCHEME}://${orderer_name}:${orderer_name}pw@${CA_HOST}:${CA_PORT}" \
      --caname "${CA_NAME}" \
      "${TLS_ARGS[@]}" \
      --mspdir "${orderer_dir_in_container}/msp"

    cp "${org_root}/msp/config.yaml" "${orderer_dir}/msp/config.yaml"

    run_ca_client "/crypto/organizations/ordererOrganizations/${org_domain}" enroll -u "${CA_SCHEME}://${orderer_name}:${orderer_name}pw@${CA_HOST}:${CA_PORT}" \
      --caname "${CA_NAME}" \
      "${TLS_ARGS[@]}" \
      --enrollment.profile tls \
      --csr.hosts "${orderer_fqdn}" \
      --csr.hosts "localhost" \
      --mspdir "${orderer_dir_in_container}/tls"

    setup_tls_files "${orderer_dir}/tls"
    setup_node_tls_ca "${orderer_dir}/msp" "${orderer_dir}/tls"
  }

  create_orderer "${ORDERER0}"
  create_orderer "${ORDERER1}"

  mkdir -p "${org_root}/users/Admin@${org_domain}/msp"
  run_ca_client "/crypto/organizations/ordererOrganizations/${org_domain}" enroll -u "${CA_SCHEME}://${ORDERER_ORG}admin:${ORDERER_ORG}adminpw@${CA_HOST}:${CA_PORT}" \
    --caname "${CA_NAME}" \
    "${TLS_ARGS[@]}" \
    --mspdir "${org_root_in_container}/users/Admin@${org_domain}/msp"

  cp "${org_root}/msp/config.yaml" "${org_root}/users/Admin@${org_domain}/msp/config.yaml"

  setup_org_tls_ca "${org_root}" "${org_root}/orderers/${ORDERER0}.${org_domain}/tls"
}

create_org_msp "${ORG_J2}"
create_org_msp "${ORG_EM}"
create_orderer_org_msp
