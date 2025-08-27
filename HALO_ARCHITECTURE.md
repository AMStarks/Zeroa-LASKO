# Halo Architecture

### Layers
- L1: Telestai blockchain (daemon + RPC proxy)
- L1.5: Halo bridge (Indexer + API + Storage + Metrics)
- L2: LASKO UI + Zeroa iOS wallet

### Components
- Indexer (port 3001): consumes Telestai blocks/txs, exposes query APIs
- Storage: Postgres (5432), Cassandra (9042) for time-series / scalability
- Cache/Queue: Redis (6380)
- Observability: Prometheus (9090), Grafana (3002)
- API Gateway: nginx 80/443, routes public APIs over HTTPS

### Identity/Token (planned)
- Challenge: GET `/v1/halo/challenge?address=<tlsAddress>`
- Verify: POST `/v1/halo/verify` `{ address, nonce, signature, pubkey }`
- JWKS: GET `/.well-known/jwks.json`
- Tokens: short-lived access + refresh; JWT (RS256)

### Messaging integration
- Switchboard Relay: `/api/v1/peer/*`, `/api/v1/message/relay`, WebSocket `/ws/{address}`
- Fallback-to-blockchain for message delivery

### Security
- Public endpoints via HTTPS only
- DB/Cassandra/Redis restricted to internal network
- Rate limiting and signature verification at the edge

### Nginx (target routes)
- `https://<domain>/halo/*` → Halo API
- `https://<domain>/switchboard/*` → Relay API
- `https://<domain>/.well-known/jwks.json` → JWKS
