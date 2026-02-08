#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
CRYPTO_DIR="${ROOT_DIR}/crypto"
OUT_DIR="${ROOT_DIR}/config/connection-profiles"

# Connection profiles are generated artifacts for Zone1/Zone3 SDK clients

ZONE2_PUBLIC_HOST=${ZONE2_PUBLIC_HOST:-localhost}
ORDERER0_PORT=${ORDERER0_PORT:-7050}
ORDERER1_PORT=${ORDERER1_PORT:-8050}
PEER_J2_PORT=${PEER_J2_PORT:-7051}
PEER_EM_PORT=${PEER_EM_PORT:-9051}

ORDERER0_CA="${CRYPTO_DIR}/organizations/ordererOrganizations/traceops.local/orderers/orderer0.traceops.local/tls/ca.crt"
ORDERER1_CA="${CRYPTO_DIR}/organizations/ordererOrganizations/traceops.local/orderers/orderer1.traceops.local/tls/ca.crt"
PEER_J2_CA="${CRYPTO_DIR}/organizations/peerOrganizations/orgj2.traceops.local/peers/peer0.orgj2.traceops.local/tls/ca.crt"
PEER_EM_CA="${CRYPTO_DIR}/organizations/peerOrganizations/orgem.traceops.local/peers/peer0.orgem.traceops.local/tls/ca.crt"

for f in "${ORDERER0_CA}" "${ORDERER1_CA}" "${PEER_J2_CA}" "${PEER_EM_CA}"; do
  if [ ! -f "${f}" ]; then
    echo "Missing TLS CA file: ${f}" >&2
    echo "Run bootstrap-network.sh first." >&2
    exit 1
  fi
done

mkdir -p "${OUT_DIR}"

json_pem() {
  # Keep PEM content JSON-safe for inline tlsCACerts fields
  python3 -c 'import json,sys; print(json.dumps(open(sys.argv[1], encoding="utf-8").read()))' "$1"
}

ORDERER0_PEM=$(json_pem "${ORDERER0_CA}")
ORDERER1_PEM=$(json_pem "${ORDERER1_CA}")
PEER_J2_PEM=$(json_pem "${PEER_J2_CA}")
PEER_EM_PEM=$(json_pem "${PEER_EM_CA}")

ZONE1_OUT="${OUT_DIR}/zone1-write-connection.json"
ZONE3_OUT="${OUT_DIR}/zone3-read-connection.json"

cat > "${ZONE1_OUT}" <<EOF
{
  "name": "traceops-zone2-zone1-write",
  "version": "1.0.0",
  "client": {
    "organization": "OrgJ2MSP",
    "connection": {
      "timeout": {
        "peer": {
          "endorser": "300"
        },
        "orderer": "300"
      }
    }
  },
  "organizations": {
    "OrgJ2MSP": {
      "mspid": "OrgJ2MSP",
      "peers": [
        "peer0.orgj2.traceops.local"
      ]
    },
    "OrgEMMSP": {
      "mspid": "OrgEMMSP",
      "peers": [
        "peer0.orgem.traceops.local"
      ]
    }
  },
  "orderers": {
    "orderer0.traceops.local": {
      "url": "grpcs://${ZONE2_PUBLIC_HOST}:${ORDERER0_PORT}",
      "grpcOptions": {
        "ssl-target-name-override": "orderer0.traceops.local"
      },
      "tlsCACerts": {
        "pem": ${ORDERER0_PEM}
      }
    },
    "orderer1.traceops.local": {
      "url": "grpcs://${ZONE2_PUBLIC_HOST}:${ORDERER1_PORT}",
      "grpcOptions": {
        "ssl-target-name-override": "orderer1.traceops.local"
      },
      "tlsCACerts": {
        "pem": ${ORDERER1_PEM}
      }
    }
  },
  "peers": {
    "peer0.orgj2.traceops.local": {
      "url": "grpcs://${ZONE2_PUBLIC_HOST}:${PEER_J2_PORT}",
      "grpcOptions": {
        "ssl-target-name-override": "peer0.orgj2.traceops.local"
      },
      "tlsCACerts": {
        "pem": ${PEER_J2_PEM}
      }
    },
    "peer0.orgem.traceops.local": {
      "url": "grpcs://${ZONE2_PUBLIC_HOST}:${PEER_EM_PORT}",
      "grpcOptions": {
        "ssl-target-name-override": "peer0.orgem.traceops.local"
      },
      "tlsCACerts": {
        "pem": ${PEER_EM_PEM}
      }
    }
  },
  "channels": {
    "traceops": {
      "orderers": [
        "orderer0.traceops.local",
        "orderer1.traceops.local"
      ],
      "peers": {
        "peer0.orgj2.traceops.local": {},
        "peer0.orgem.traceops.local": {}
      }
    }
  }
}
EOF

cat > "${ZONE3_OUT}" <<EOF
{
  "name": "traceops-zone2-zone3-read",
  "version": "1.0.0",
  "client": {
    "organization": "OrgEMMSP",
    "connection": {
      "timeout": {
        "peer": {
          "endorser": "300"
        },
        "orderer": "300"
      }
    }
  },
  "organizations": {
    "OrgJ2MSP": {
      "mspid": "OrgJ2MSP",
      "peers": [
        "peer0.orgj2.traceops.local"
      ]
    },
    "OrgEMMSP": {
      "mspid": "OrgEMMSP",
      "peers": [
        "peer0.orgem.traceops.local"
      ]
    }
  },
  "orderers": {
    "orderer0.traceops.local": {
      "url": "grpcs://${ZONE2_PUBLIC_HOST}:${ORDERER0_PORT}",
      "grpcOptions": {
        "ssl-target-name-override": "orderer0.traceops.local"
      },
      "tlsCACerts": {
        "pem": ${ORDERER0_PEM}
      }
    },
    "orderer1.traceops.local": {
      "url": "grpcs://${ZONE2_PUBLIC_HOST}:${ORDERER1_PORT}",
      "grpcOptions": {
        "ssl-target-name-override": "orderer1.traceops.local"
      },
      "tlsCACerts": {
        "pem": ${ORDERER1_PEM}
      }
    }
  },
  "peers": {
    "peer0.orgj2.traceops.local": {
      "url": "grpcs://${ZONE2_PUBLIC_HOST}:${PEER_J2_PORT}",
      "grpcOptions": {
        "ssl-target-name-override": "peer0.orgj2.traceops.local"
      },
      "tlsCACerts": {
        "pem": ${PEER_J2_PEM}
      }
    },
    "peer0.orgem.traceops.local": {
      "url": "grpcs://${ZONE2_PUBLIC_HOST}:${PEER_EM_PORT}",
      "grpcOptions": {
        "ssl-target-name-override": "peer0.orgem.traceops.local"
      },
      "tlsCACerts": {
        "pem": ${PEER_EM_PEM}
      }
    }
  },
  "channels": {
    "traceops": {
      "orderers": [
        "orderer0.traceops.local",
        "orderer1.traceops.local"
      ],
      "peers": {
        "peer0.orgj2.traceops.local": {},
        "peer0.orgem.traceops.local": {}
      }
    }
  }
}
EOF

echo "Generated connection profiles:"
echo "- ${ZONE1_OUT}"
echo "- ${ZONE3_OUT}"
