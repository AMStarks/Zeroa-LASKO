# App Privacy — domains & data (Zeroa 1.1.1)

Use this to align **App Store Connect → App Privacy** with the binary.

## External domains the app calls

| Domain | Purpose |
|--------|---------|
| `halo.telestai.io` | Halo auth / API (`https://halo.telestai.io/api`) |
| `api.telestai.io` | Switchboard Layer-2 messaging HTTPS + WSS (**placeholder** until DNS/TLS is live; replaces former `43.224.35.187:8000`) |
| `telestai.cryptoscope.io` | TLS address / chain lookups |
| `api.coingecko.com` | Coin prices & charts |
| `api.coinpaprika.com` | TLS price fallback |
| `api.coincap.io` | TLS price / history fallback |
| `api.x.ai` | AI chat completions (Nova / assistant) — **only after user consent** |
| `blockstream.info` | Bitcoin address / fee / broadcast APIs |
| `api.blockcypher.com` | Litecoin address / tx APIs |
| `api.kaspa.org` | Kaspa address / tx APIs |
| `explorer.runonflux.io` | Flux explorer APIs |
| `api.runonflux.io` | Flux balance APIs |
| `docs.telestai.com` | In-app docs + privacy policy link |
| `discord.gg` | Community support link |
| `support@telestai.com` | Support email (mailto) |

Optional / related product surfaces (not always hit from Zeroa UI in this build):
- PowDEX hosts such as `powdex.andrewstarkey.net` are not called from this Zeroa binary path; omit from App Privacy unless a future build embeds PowDEX networking.

## AI / third-party sharing (xAI)

| Item | Detail |
|------|--------|
| **Provider** | xAI (`https://api.x.ai/v1/chat/completions`) |
| **Data types** | User prompt / message text; optional app-built context such as displayed TLS balance |
| **Not sent** | Recovery phrases, private keys, photos, camera captures, Switchboard attachments, precise location |
| **Purpose** | App functionality — generate AI assistant responses |
| **Linked to identity?** | Not used as an account identifier; prompts are not tied to Halo login in the request body. Treat as **Data Not Linked to You** unless you later attach a stable user id. |
| **Used for tracking?** | **No** |
| **Consent** | One-time Allow / Not now sheet before first AI use; toggle in **Settings → AI data sharing**; revocable |

## Data types collected / used

| Data | Collected? | Linked to identity? | Used for |
|------|------------|---------------------|----------|
| Wallet address / public key | Yes (on-device + sent to Halo / chain explorers / Switchboard for balance & auth) | Yes (wallet identity) | App functionality |
| Recovery phrase / private keys | Yes — **Keychain / App Group on device only**; never sent to xAI (client-side guard) or Switchboard as raw secrets | N/A (on-device secret) | App functionality |
| Photos / camera images | Yes — user-selected Switchboard drafts | No | App functionality |
| Audio recordings | Yes — Switchboard voice notes | No | App functionality |
| Precise location | Yes — only when user taps **Location** in Switchboard | No | App functionality |
| AI prompts | Yes — only after consent, to xAI | No (default label) | App functionality |
| Product interaction / diagnostics | Minimal (local logs); Halo token storage | Partially (wallet address for Halo) | App functionality / auth |
| Contact info (email) | Only if user initiates `mailto:` support | No | Support |

## Privacy Nutrition Label suggestions
- **Contact Info**: optional (support email only if declared)
- **Location**: Precise Location — App Functionality — Switchboard share only
- **User Content**: Photos/Videos, Audio — App Functionality; Other User Content for AI prompts if you declare them
- **Identifiers**: wallet address used as account identifier for Halo / Switchboard
- **Usage Data**: none beyond functional API calls
- **Diagnostics**: Crash data only if Organizer crash reports are enabled

Declare **Data Not Linked to You** for media/location/AI prompts unless you later bind them to a user account backend.
