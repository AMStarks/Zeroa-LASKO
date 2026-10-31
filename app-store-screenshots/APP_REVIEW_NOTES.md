# Notes for App Review — Zeroa 1.1.1 (4)

## Demo / screenshot mode
Launch with argument **`-DEMO_MODE`** or **`-UI_TEST_SCREENSHOTS`** (already used by our UI tests).

In demo mode the app:
- Skips the empty login gate and opens the wallet home
- Seeds a demo TLS wallet / balances for screenshots
- Shows Switchboard contacts (Alice, Bob, Carol) so messaging is reachable without backend signup
- **Pre-grants AI data-sharing consent** so screenshot automation is not blocked by the consent sheet

## How to reach each feature
1. **Wallet balances** — Home screen after launch (demo mode opens here automatically).
2. **Send / Receive** — Home → **Send** or **Receive**.
3. **Messages (Switchboard)** — Bottom **messaging** tab, or Menu → **Hybrid Messaging**. Open **Alice** for a conversation.
4. **Attachments** — In a Switchboard conversation, tap **+** to expand Photo, Camera, Document, Location, Audio.
5. **AI features & consent** — Bottom **AI** tab opens **AI Features**.
   - First launch (non-demo): **Allow** / **Not now** consent explains that prompts go to **xAI**, links to the Privacy Policy, and lists what is / isn’t sent.
   - **Not now** blocks AI network calls and shows a gentle enable prompt.
   - **Settings → AI data sharing** toggle grants or revokes consent anytime.
6. **PowDEX** — Not shipped as a standalone tab in this Zeroa build.

## Why each permission is requested
| Permission | Purpose |
|------------|---------|
| **Camera** | Attach a photo taken in-app to a Switchboard message |
| **Photo Library** | Attach an existing image to a Switchboard message |
| **Microphone** | Record a short voice clip for a Switchboard message |
| **Location When In Use** | Share the user’s current coordinates in a Switchboard message |

Denials show an alert with **Open Settings**.

## Networking notes for reviewers
- Switchboard uses **`https://api.telestai.io`** (WSS for realtime). No raw IP endpoints and no ATS arbitrary-load exceptions in the app Info.plist.
- AI calls go only to **`https://api.x.ai`** after consent; recovery phrases / private keys are blocked client-side.

## Suggested review path (2 minutes)
1. Launch (demo mode if provided via TestFlight notes).
2. Confirm home balances are visible.
3. Open Switchboard → Alice → tap **+** → Photo / Document / Location / Audio (Camera on device).
4. Open **AI** tab (demo: consent already granted) or decline/allow once on a clean install; confirm Settings toggle.
