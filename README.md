# Trace-OPS - Decision Traceability POC
![FoxyHack](imagesReadme/image.png)

## Context
Participation in FoxyHack 2026: the hackathon supporting digital sovereignty
</br>
- *Dec 15, 2025 - Jan 31, 2026: remote research and preparation phase*
- *Feb 8 - 10, 2026: on-site hackathon in Evreux*

## Teams 
- [Thox](https://github.com/DIGIX666) : Théo Dubois - Dev Fullstack, Blockchain
- [Simon](https://github.com/SLecureu) : Simon Lecureux - Dev Fullstack 

## Vision
Trace-OPS aims to provide a trusted trace across the operational decision chain, from field alert reporting to J2 pre-analysis, J3/EM human decision, and after-action review (RETEX). The POC demonstrates technical feasibility without connecting to classified information systems and using only fictional data.

## POC Objectives
- Prove traceability of human decisions through an append-only ledger.
- Illustrate an end-to-end flow: alert -> pre-analysis -> decision -> anchoring -> timeline.
- Verify network-zone separation and secure data flows.
- Deliver a clear and reproducible demo in a test environment.

## Functional Scope
1. Information intake: alert injection interface.
2. J2 pre-analysis: scoring and synthesis engine.
3. EM decision: validation/rejection/arbitration with role-based controls.
4. Traceability ledger: anchoring decision fingerprints.
5. Timeline/RETEX: chronological reconstruction of decisions.

Out of POC scope
- Interconnection with real operational information systems.
- AI-automated decision-making.
- Post-quantum encryption.

## Target Architecture (POC)
The information system is segmented into three isolated network zones controlled by firewalls.

Detailed diagram (services, infrastructure, security)

```
                            Utilisateurs
                                 |
                              HTTPS 443
                                 v
                    +---------------------------+
                    | Ingress / Reverse Proxy   |
                    | (Traefik, TLS)            |
                    +---------------------------+
                                 |
                                 v
    +---------------------------------------------------------+
    | Zone 1 - User/Analyst network                            |
    |                                                         |
    |  +-------------+    REST/TLS    +-------------------+   |
    |  | Alert UI    |--------------->| FastAPI API (J2/EM)|  |
    |  +-------------+                | - scoring J2       |  |
    |          ^                      | - decisions EM     |  |
    |          |                      +-------------------+   |
    |      HTTPS 443                           |              |
    |  +-------------+                         | gRPC/TLS 7050|
    |  |    EM /     |<------------------------+              |
    |  | Decision UI |                                        |
    |  +-------------+                                        |
    |                                                         |
    |  +-------------+                                        |
    |  | IAM / SSO   |<---- OIDC/JWT -----> API               |
    |  | (Keycloak)  |                                        |
    |  +-------------+                                        |
    +---------------------------------------------------------+
                                 |
                                 v
    +---------------------------------------------------------+
    | Zone 2 - Ledger/Infrastructure network                  |
    |  +-----------------+   +-----------------------------+  |
    |  | Fabric CA       |   | Fabric Orderer + Peers       | |
    |  +-----------------+   +-----------------------------+  |
    |            |                     |                      |
    |            +----> World State (CouchDB/LevelDB)         |
    +---------------------------------------------------------+
                                 |
                                 v
    +---------------------------------------------------------+
    | Zone 3 - RETEX network                                  |
    |  +-----------------+   gRPC/TLS 7051                    |
    |  | Timeline Service |<---------------------------------+|
    |  +-----------------+                                    |
    |          | HTTPS 443                                    |
    |          v                                              |
    |  +-----------------+                                    |
    |  | Timeline UI     |                                    |
    |  +-----------------+                                    |
    +---------------------------------------------------------+

Security notes
- TLS everywhere, mTLS for ledger access.
- No outbound internet traffic.
- Firewall segmentation between zones.
```

### Zones
- Zone 1 - User/Analyst network: alert app, J2 engine, EM interface.
- Zone 2 - Ledger/Infrastructure network: Hyperledger Fabric + world state database.
- Zone 3 - RETEX network: Timeline service (ledger read access).

### Services
- Alert intake service: web UI to submit alerts.
- J2 pre-analysis service: scoring + synthesis through REST API.
- EM decision service: UI for validation/rejection/arbitration.
- Ledger service: fingerprint recording and timestamping.
- Timeline/RETEX service: chronology and review.

### Flux principaux
- Alert UI -> J2 engine: HTTP/REST (internal, TLS if inter-container).
- EM interface -> Ledger: gRPC/TLS (7050) for anchoring.
- Ledger -> Timeline: gRPC/TLS (7051) for reads.
- Timeline -> EM UI: HTTPS (443) for consultation.

## Selected Technology Stack
- User portal and decision interface: Vue.js (MIT).
- Decision API and orchestration: FastAPI (Python).
- Traceability ledger: Hyperledger Fabric v2.5 (Apache 2.0).
- Metadata database: PostgreSQL.
- IAM/SSO: Keycloak (OIDC, RBAC).
- TLS reverse proxy: Traefik.
- Observability: Prometheus + Grafana + Loki.

## POC Assumptions and Constraints
- Fictional data only.
- No outbound internet traffic.
- TLS everywhere, mTLS for ledger.
- Demo environment disconnected from real networks.
- POC sizing based on Ubuntu Server 22.04 VMs.

## Expected Deliverables
- End-to-end functional POC.
- README + dated roadmap.
- Demo script and fictional alert dataset.
- Reference diagrams/flows and network parameters.

## Roadmap

### Phase 1 - Foundations (until February 7)
Objective: scope, secure, and lock down technical and functional foundations.

Work items
- Final functional scope + user journeys (alerts, J2, EM, RETEX).
- Data model: alert, analysis, decision, fingerprint.
- API contracts (OpenAPI) and role model (J2/J3/EM/SA).
- Minimal ledger schema (decision transaction + SHA-256 hash).
- Finalized network architecture (ports, zones, flows).
- POC infrastructure plan (VMs, containers, volumes, TLS, mTLS).
- Fictional datasets + demo scenario.

Work split (2-person team)
- Person A: user journeys, POC UI, demo dataset.
- Person B: API/ledger, data model, infrastructure and security.

Sync checkpoint
- End of phase: mock demo (UI + mocked API + validated ledger schema).

### Phase 2 - POC Build (February 9-10)
Objective: assemble the full flow and deliver a reliable demo.

Work items
- Alert UI + EM UI + timeline (demo version).
- FastAPI API: ingestion, basic scoring, decision handling.
- Ledger integration: fingerprint write and read.
- Timeline: extraction and visualization.
- Reverse proxy and TLS setup.
- Minimal observability (logs + metrics).
- Demo run with complete chronology.

Success criteria
- An observer can follow an alert, view analysis, decision, then trace it in the timeline.
- The fingerprint is verifiable and linked to a human decision.
- Flows comply with network-zone boundaries and TLS.

## POC Limitations
- No representative production-level load.
- No interconnection with operational information systems.
- AI limited to synthesis assistance, no autonomous decision-making.

## Possible Next Steps
1) Add richer, configurable J2 business rules.
2) Strengthen security (HSM, advanced mTLS policies).
3) Prepare integration with a third-party information system in an isolated environment.
