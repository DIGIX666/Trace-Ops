#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)

# Preflight intentionally checks structure + syntax only (no network side effects)

PASS_COUNT=0
FAIL_COUNT=0

pass() {
  PASS_COUNT=$((PASS_COUNT + 1))
  printf "[PASS] %s\n" "$1"
}

fail() {
  FAIL_COUNT=$((FAIL_COUNT + 1))
  printf "[FAIL] %s\n" "$1"
}

check_file() {
  local file_path=$1
  local label=$2
  if [ -f "${file_path}" ]; then
    pass "${label}"
  else
    fail "${label} (missing: ${file_path})"
  fi
}

check_dir() {
  local dir_path=$1
  local label=$2
  if [ -d "${dir_path}" ]; then
    pass "${label}"
  else
    fail "${label} (missing: ${dir_path})"
  fi
}

check_non_empty_var() {
  local var_name=$1
  if [ -n "${!var_name:-}" ]; then
    pass "ca.env variable '${var_name}'"
  else
    fail "ca.env variable '${var_name}' is empty or undefined"
  fi
}

check_bash_syntax() {
  local file_path=$1
  local label=$2
  if bash -n "${file_path}" >/dev/null 2>&1; then
    pass "${label}"
  else
    fail "${label}"
  fi
}

check_yaml_syntax() {
  local file_path=$1
  local label=$2
  if command -v ruby >/dev/null 2>&1; then
    if ruby -e "require 'yaml'; YAML.load_file(ARGV[0])" "${file_path}" >/dev/null 2>&1; then
      pass "${label}"
    else
      fail "${label}"
    fi
    return
  fi

  fail "${label} (ruby not found for YAML validation)"
}

printf "Running Zone2 preflight checks...\n"

check_dir "${ROOT_DIR}/config" "config directory exists"
check_dir "${ROOT_DIR}/scripts" "scripts directory exists"

check_file "${ROOT_DIR}/config/ca.env" "ca.env exists"
check_file "${ROOT_DIR}/config/configtx.yaml" "configtx.yaml exists"
check_file "${ROOT_DIR}/config/core.yaml" "core.yaml exists"
check_file "${ROOT_DIR}/config/orderer.yaml" "orderer.yaml exists"
check_file "${ROOT_DIR}/config/orderer0.yaml" "orderer0.yaml exists"
check_file "${ROOT_DIR}/config/orderer1.yaml" "orderer1.yaml exists"
check_file "${ROOT_DIR}/scripts/ca-bootstrap.sh" "ca-bootstrap.sh exists"
check_file "${ROOT_DIR}/scripts/bootstrap-network.sh" "bootstrap-network.sh exists"
check_file "${ROOT_DIR}/scripts/generate-channel-artifacts.sh" "generate-channel-artifacts.sh exists"
check_file "${ROOT_DIR}/scripts/generate-connection-profiles.sh" "generate-connection-profiles.sh exists"
check_file "${ROOT_DIR}/scripts/deploy-chaincode.sh" "deploy-chaincode.sh exists"
check_file "${ROOT_DIR}/scripts/run-unit-tests.sh" "run-unit-tests.sh exists"

check_bash_syntax "${ROOT_DIR}/scripts/ca-bootstrap.sh" "ca-bootstrap.sh syntax"
check_bash_syntax "${ROOT_DIR}/scripts/bootstrap-network.sh" "bootstrap-network.sh syntax"
check_bash_syntax "${ROOT_DIR}/scripts/generate-channel-artifacts.sh" "generate-channel-artifacts.sh syntax"
check_bash_syntax "${ROOT_DIR}/scripts/generate-connection-profiles.sh" "generate-connection-profiles.sh syntax"
check_bash_syntax "${ROOT_DIR}/scripts/deploy-chaincode.sh" "deploy-chaincode.sh syntax"
check_bash_syntax "${ROOT_DIR}/scripts/run-unit-tests.sh" "run-unit-tests.sh syntax"
check_bash_syntax "${ROOT_DIR}/scripts/tests/preflight_test.sh" "preflight_test.sh syntax"

check_yaml_syntax "${ROOT_DIR}/config/configtx.yaml" "configtx.yaml YAML syntax"
check_yaml_syntax "${ROOT_DIR}/config/core.yaml" "core.yaml YAML syntax"
check_yaml_syntax "${ROOT_DIR}/config/orderer.yaml" "orderer.yaml YAML syntax"
check_yaml_syntax "${ROOT_DIR}/config/orderer0.yaml" "orderer0.yaml YAML syntax"
check_yaml_syntax "${ROOT_DIR}/config/orderer1.yaml" "orderer1.yaml YAML syntax"

set -a
. "${ROOT_DIR}/config/ca.env"
set +a

check_non_empty_var "CA_NAME"
check_non_empty_var "CA_HOST"
check_non_empty_var "CA_PORT"
check_non_empty_var "CA_SCHEME"
check_non_empty_var "DOMAIN"
check_non_empty_var "ORG_J2"
check_non_empty_var "ORG_EM"
check_non_empty_var "ORDERER0"
check_non_empty_var "ORDERER1"

printf "\nPreflight result: %d passed, %d failed\n" "${PASS_COUNT}" "${FAIL_COUNT}"

if [ "${FAIL_COUNT}" -ne 0 ]; then
  exit 1
fi
