# Halo Implementation Plan

### Phase 1: Public API + Edge
- Define OpenAPI for `/v1/halo/challenge`, `/v1/halo/verify`, `/.well-known/jwks.json`
- Implement lightweight service (FastAPI/Express) behind nginx 443
- Add `/health` on indexer and API
- Lock down DB/Redis/Cassandra to internal networks

### Phase 2: iOS Client Integration
- Add `HaloService.swift` with:
  - `getChallenge(address)`
  - `verify(address, nonce, signature, pubkey)`
  - Token storage/refresh via Keychain
- Thread `haloAccessToken` into `LASKOAuthSession`
- Add error UX and retry/backoff

### Phase 3: Observability + Ops
- Prometheus scrape configs; Grafana dashboards (API latency, errors, token issuance)
- Structured logs + request IDs
- Alerts on health and error rates

### Phase 4: Stamping + TLS Write
- Implement TLS block write path with fee policy
- Post stamping (hashing, canonicalization)
- Live/not-live flags propagation

### Phase 5: Messaging Hardening
- E2E key exchange for P2P
- Unify client path (remove mock data); reliable delivery and retries

### Deliverables
- Public Halo API (HTTPS), JWKS
- iOS Halo client integrated into auth flow
- Dashboards + alerts
- Stamping and TLS write functions

### Acceptance
- End-to-end LASKO sign-in uses Halo token verified by server
- Health endpoints green; dashboards populated
- Stamped posts visible via indexer
