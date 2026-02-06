#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CONFIG_DIR="${ROOT_DIR}/config"
CRYPTO_DIR="${ROOT_DIR}/crypto"
ARTIFACTS_DIR="${CRYPTO_DIR}/channel-artifacts"

CHANNEL_NAME=${CHANNEL_NAME:-traceops}
GENESIS_PROFILE=${GENESIS_PROFILE:-TwoOrgsOrdererGenesis}
CHANNEL_PROFILE=${CHANNEL_PROFILE:-TwoOrgsChannel}

TOOLS_IMAGE=${TOOLS_IMAGE:-hyperledger/fabric-tools:2.5}

CONFIGTX_PATH_IN_CONTAINER="/workspace/config"
CRYPTO_PATH_IN_CONTAINER="/crypto"
ARTIFACTS_PATH_IN_CONTAINER="/crypto/channel-artifacts"

command -v docker >/dev/null 2>&1 || {
  echo "docker not found in PATH" >&2
  exit 1
}

if [ ! -f "${CONFIG_DIR}/configtx.yaml" ]; then
  echo "Missing configtx.yaml at ${CONFIG_DIR}/configtx.yaml" >&2
  exit 1
fi

if [ ! -d "${CRYPTO_DIR}/organizations" ]; then
  echo "Missing crypto organizations at ${CRYPTO_DIR}/organizations" >&2
  echo "Run CA bootstrap first to generate MSP/TLS materials." >&2
  exit 1
fi

mkdir -p "${ARTIFACTS_DIR}"

run_configtxgen() {
  docker run --rm \
    -v "${CONFIG_DIR}:${CONFIGTX_PATH_IN_CONTAINER}" \
    -v "${CRYPTO_DIR}:${CRYPTO_PATH_IN_CONTAINER}" \
    -e FABRIC_CFG_PATH="${CONFIGTX_PATH_IN_CONTAINER}" \
    "${TOOLS_IMAGE}" \
    configtxgen "$@"
}

run_configtxgen \
  -profile "${GENESIS_PROFILE}" \
  -channelID "system-channel" \
  -outputBlock "${ARTIFACTS_PATH_IN_CONTAINER}/genesis.block"

run_configtxgen \
  -profile "${CHANNEL_PROFILE}" \
  -channelID "${CHANNEL_NAME}" \
  -outputCreateChannelTx "${ARTIFACTS_PATH_IN_CONTAINER}/${CHANNEL_NAME}.tx"

run_configtxgen \
  -profile "${CHANNEL_PROFILE}" \
  -channelID "${CHANNEL_NAME}" \
  -outputAnchorPeersUpdate "${ARTIFACTS_PATH_IN_CONTAINER}/OrgJ2MSPanchors.tx" \
  -asOrg "OrgJ2MSP"

run_configtxgen \
  -profile "${CHANNEL_PROFILE}" \
  -channelID "${CHANNEL_NAME}" \
  -outputAnchorPeersUpdate "${ARTIFACTS_PATH_IN_CONTAINER}/OrgEMMSPanchors.tx" \
  -asOrg "OrgEMMSP"

echo "Generated artifacts:"
echo "- ${ARTIFACTS_DIR}/genesis.block"
echo "- ${ARTIFACTS_DIR}/${CHANNEL_NAME}.tx"
echo "- ${ARTIFACTS_DIR}/OrgJ2MSPanchors.tx"
echo "- ${ARTIFACTS_DIR}/OrgEMMSPanchors.tx"
