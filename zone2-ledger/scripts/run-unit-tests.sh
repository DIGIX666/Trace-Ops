#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)

echo "[1/2] Running chaincode unit tests"
(cd "${ROOT_DIR}/chaincode/decision" && go test ./...)

echo "[2/2] Running critical script tests"
"${ROOT_DIR}/scripts/tests/generate_connection_profiles_test.sh"

echo "All unit tests passed."
