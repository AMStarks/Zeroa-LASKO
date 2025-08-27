# HALO LAYER 1.5 BRIDGE — PROJECT STATUS

### Snapshot
- Telestai L1 (daemon `telestaid`) running on infra; RPC proxy active behind nginx
- Halo L1.5 stack running in Docker:
  - halo-indexer (port 3001), halo-redis (6380), halo-cassandra (9042), halo-postgres (5432)
  - Observability: halo-prometheus (9090), halo-grafana (3002)
- Zeroa app BIP-39/44 aligned for Telestai at m/44'/10117'/0'/0/0; strict mnemonic→address match enforced
- LASKO ↔ Zeroa auth: signed canonical message with Telestai key; TTL 120s; compressed pubkey included

### Current Architecture
- Layer 1: Telestai blockchain (daemon + RPC proxy)
- Layer 1.5: Halo bridge (indexer + API + storage + metrics)
- Layer 2: LASKO frontend + Zeroa iOS wallet

### Status by Capability
- Wallet/Identity
  - [x] BIP-39 seed + BIP-44 derivation (Telestai 10117)
  - [x] Message signing (DER, Base64)
  - [ ] Halo challenge/verify client in-app (token issuance)
- Halo Services
  - [x] Indexer container up (needs /health route)
  - [x] Redis/Postgres/Cassandra up
  - [x] Prometheus/Grafana reachable
  - [ ] Public API gateway documented + proxied via nginx (HTTPS)
  - [ ] Token service (challenge/verify) live
- Messaging
  - [x] Switchboard relay healthy; WebSocket path available
  - [ ] E2E key exchange for direct P2P
  - [ ] Unified client path (remove mock data)
- Content/Stamping
  - [ ] TLS block write function
  - [ ] Post stamping semantics (hashing, fee policy)
  - [ ] Live/not-live flag propagation

### Sequential Code Format
- Prefix: `LAS#`
- Example: `LAS#0000000000000000000000000000001`
- Rule: Extend digit width as needed; include timestamp + user_address + nonce for uniqueness where required

### Key Decisions (recent)
- Use SLIP-0044 coin type 10117 for Telestai
- Enforce strict mnemonic→address match; remove non-BIP fallbacks
- LASKO auth message: `LASKO|<nonce>|<ttl>|<bundleId>`; TTL=120s
- Prefer HTTPS via nginx for public endpoints; keep DB/Redis/Cassandra internal

### Risks / Issues
- Indexer lacks explicit `/health` endpoint (returns 404); add minimal health route
- Port 9999 (Node RPC proxy) not reachable externally; clarify intent (prefer proxy via nginx:443)
- Public exposure of DB/Redis/Cassandra via host ports: review firewall/ingress

### Current Focus
- Implement Halo challenge/verify endpoints (server) and iOS `HaloService.swift` integration.

### Next Steps (short)
1. Finalize Halo API contracts (challenge/verify, JWKS)
2. Add nginx routes for Halo API and enforce HTTPS
3. Implement `HaloService.swift` client and thread token into LASKO session
4. Wire Prometheus scraping for API; confirm `/api/health` up in prod
5. Implement TLS block write and stamping path
