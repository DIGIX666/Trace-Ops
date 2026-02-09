#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
SOURCE_SCRIPT="${ROOT_DIR}/scripts/generate-connection-profiles.sh"

fail() {
  printf "[FAIL] %s\n" "$1" >&2
  exit 1
}

pass() {
  printf "[PASS] %s\n" "$1"
}

make_cert() {
  local file_path=$1
  mkdir -p "$(dirname "${file_path}")"
  # Static test cert content is enough for JSON generation checks
  cat > "${file_path}" <<'EOF'
-----BEGIN CERTIFICATE-----
MIIBwzCCAWmgAwIBAgIUZ2VuZXJhdGVkLXRlc3QtY2VydDAKBggqhkjOPQQDAjAa
MRgwFgYDVQQDDA90ZXN0LWxvY2FsLUNBMB4XDTI2MDEwMTAwMDAwMFoXDTM2MDEw
MTAwMDAwMFowGjEYMBYGA1UEAwwPdGVzdC1sb2NhbC1DQTBaMBMGByqGSM49AgEG
CCqGSM49AwEHA0IABM3tY6M5y0fD4m8lD4iM7jVw1+QJc7mU+6f5t4Q3fWnJwP8W
f2a2W4j7K9nJ1M6s2dP5Qz8m3gqj4sBf1w2wY0qjUzBRMB0GA1UdDgQWBBS+2e1v
L1vA9f4W9jQ4g8D2m4Hk9jAfBgNVHSMEGDAWgBS+2e1vL1vA9f4W9jQ4g8D2m4Hk
9jAPBgNVHRMBAf8EBTADAQH/MAoGCCqGSM49BAMCA0gAMEUCIF5P0gqM8g2J3m4e
0kQm4w8HjJpR8S7kW4Vf5xWJx6wPAiEA8z1X7Y5M3f1a3qVh4fJ0Z2n7m2v9a6kN
0j9b7f3m2kQ=
-----END CERTIFICATE-----
EOF
}

assert_json_file() {
  local file_path=$1
  python3 -c 'import json,sys; json.load(open(sys.argv[1], encoding="utf-8")); print("ok")' "${file_path}" >/dev/null
}

tmp_dir=$(mktemp -d)
trap 'rm -rf "${tmp_dir}"' EXIT

# Run tests in a temp sandbox to avoid mutating repository files

sandbox_root="${tmp_dir}/zone2-ledger"
script_path="${sandbox_root}/scripts/generate-connection-profiles.sh"

mkdir -p "${sandbox_root}/scripts"
cp "${SOURCE_SCRIPT}" "${script_path}"
chmod +x "${script_path}"

make_cert "${sandbox_root}/crypto/organizations/ordererOrganizations/traceops.local/orderers/orderer0.traceops.local/tls/ca.crt"
make_cert "${sandbox_root}/crypto/organizations/ordererOrganizations/traceops.local/orderers/orderer1.traceops.local/tls/ca.crt"
make_cert "${sandbox_root}/crypto/organizations/peerOrganizations/orgj2.traceops.local/peers/peer0.orgj2.traceops.local/tls/ca.crt"
make_cert "${sandbox_root}/crypto/organizations/peerOrganizations/orgem.traceops.local/peers/peer0.orgem.traceops.local/tls/ca.crt"

mkdir -p "${tmp_dir}/zone1" "${tmp_dir}/zone3"

ORDERER0_HOST="ord0.internal" \
ORDERER1_HOST="ord1.internal" \
PEER_J2_HOST="peerj2.internal" \
PEER_EM_HOST="peerem.internal" \
"${script_path}"

zone1_profile="${sandbox_root}/config/connection-profiles/zone1-write-connection.json"
zone3_profile="${sandbox_root}/config/connection-profiles/zone3-read-connection.json"
zone1_mirror="${tmp_dir}/zone1/connection-profiles/zone1-write-connection.json"
zone3_mirror="${tmp_dir}/zone3/connection-profiles/zone3-read-connection.json"

[ -f "${zone1_profile}" ] || fail "zone1 profile was not generated"
[ -f "${zone3_profile}" ] || fail "zone3 profile was not generated"
[ -f "${zone1_mirror}" ] || fail "zone1 mirror profile was not copied"
[ -f "${zone3_mirror}" ] || fail "zone3 mirror profile was not copied"

assert_json_file "${zone1_profile}" || fail "zone1 profile is not valid JSON"
assert_json_file "${zone3_profile}" || fail "zone3 profile is not valid JSON"
assert_json_file "${zone1_mirror}" || fail "zone1 mirror profile is not valid JSON"
assert_json_file "${zone3_mirror}" || fail "zone3 mirror profile is not valid JSON"

python3 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); assert d["orderers"]["orderer0.traceops.local"]["url"]=="grpcs://ord0.internal:7050"; assert d["orderers"]["orderer1.traceops.local"]["url"]=="grpcs://ord1.internal:8050"; assert d["peers"]["peer0.orgj2.traceops.local"]["url"]=="grpcs://peerj2.internal:7051"; assert d["peers"]["peer0.orgem.traceops.local"]["url"]=="grpcs://peerem.internal:9051"; print("ok")' "${zone1_profile}" >/dev/null || fail "zone1 profile host overrides mismatch"
python3 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); pem=d["orderers"]["orderer0.traceops.local"]["tlsCACerts"]["pem"]; assert "BEGIN CERTIFICATE" in pem; print("ok")' "${zone3_profile}" >/dev/null || fail "zone3 profile missing inline cert"

rm -f "${sandbox_root}/crypto/organizations/peerOrganizations/orgem.traceops.local/peers/peer0.orgem.traceops.local/tls/ca.crt"
if "${script_path}" >/dev/null 2>&1; then
  fail "script should fail when a required TLS CA file is missing"
fi

pass "generate-connection-profiles script tests"
