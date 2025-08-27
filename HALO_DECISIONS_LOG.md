# Halo Decisions Log

### Entries
- Derivation: Use SLIP-0044 coin type 10117 for Telestai (BIP-44 path `m/44'/10117'/0'/0/0`) — Rationale: alignment with Telestai coin type
- Strict wallet import: Require mnemonic→address match; remove fallback — Rationale: correctness/security
- LASKO auth message: `LASKO|<nonce>|<ttl>|<bundleId>` TTL=120s — Rationale: replay protection and scoping
- Networking: Prefer HTTPS via nginx for public endpoints; keep DB/Redis/Cassandra internal — Rationale: security posture
- Indexer health: Add `/health` endpoint to halo-indexer — Rationale: monitoring and automation

### Pending
- Halo token format (JWT RS256) and JWKS publishing domain
- Nginx route map for Halo and Switchboard under a single domain
- Exposure policy for Node RPC proxy (9999) — proxy via 443 or keep internal
