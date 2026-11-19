# App Privacy — domains & data (Zeroa 1.1.1)

Use this to align **App Store Connect → App Privacy** with the binary.

This build is **wallet-only**: Switchboard messaging and AI / xAI features are gated off and are not reachable in the UI.

## External domains the app may call

| Domain | Purpose |
|--------|---------|
| `halo.telestai.io` | Halo auth / API (`https://halo.telestai.io/api`) |
| `telestai.cryptoscope.io` | TLS address / chain lookups |
| `api.coingecko.com` | Coin prices & charts |
| `api.coinpaprika.com` | TLS price fallback |
| `api.coincap.io` | TLS price / history fallback |
| `blockstream.info` | Bitcoin address / fee / broadcast APIs |
| `api.blockcypher.com` | Litecoin address / tx APIs |
| `api.kaspa.org` | Kaspa address / tx APIs |
| `explorer.runonflux.io` | Flux explorer APIs |
| `api.runonflux.io` | Flux balance APIs |
| `docs.telestai.com` | In-app docs + privacy policy link |
| `discord.gg` | Community support link |
| `support@telestai.com` | Support email (mailto) |

**Not used in this build (gated off):**
- `api.telestai.io` — Switchboard messaging (disabled)
- `api.x.ai` — AI chat completions (disabled)

## Data types collected / used

| Data | Collected? | Linked to identity? | Used for |
|------|------------|---------------------|----------|
| Wallet address / public key | Yes (on-device + sent to Halo / chain explorers for balance & auth) | Yes (wallet identity) | App functionality |
| Recovery phrase / private keys | Yes — **Keychain / App Group on device only**; never sent to third parties | N/A (on-device secret) | App functionality |
| Photos / camera images | Optional profile photo from Photo Library only | No | App functionality |
| Audio / precise location / AI prompts | **No** in this build | — | — |
| Product interaction / diagnostics | Minimal (local logs); Halo token storage | Partially (wallet address for Halo) | App functionality / auth |
| Contact info (email) | Only if user initiates `mailto:` support | No | Support |

## Privacy Nutrition Label suggestions
- **Contact Info**: optional (support email only if declared)
- **Location**: none for this build
- **User Content**: Photos (optional profile) if declared; no messaging attachments
- **Identifiers**: wallet address used as account identifier for Halo
- **Usage Data**: none beyond functional API calls
- **Diagnostics**: Crash data only if Organizer crash reports are enabled

Declare only what the shipping binary actually uses.
