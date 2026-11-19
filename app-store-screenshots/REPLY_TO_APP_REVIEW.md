# Reply to App Review

Hello App Review team,

Thank you for the feedback on Zeroa (`com.zeroa.wallet`).

## Guideline 2.1(a) — App Completeness
For this resubmission we are shipping a **wallet-only** build.

**Switchboard messaging** (including Photo / Camera / Document / Location / Audio attachments) and **AI / xAI features** are **not included** in this binary. Those entry points are removed from navigation, and their network clients are gated off so they cannot be reached during review.

The app focuses on core wallet flows: balances, Send, and Receive.

## Guideline 2.3.3 — Accurate Metadata
We added a demo / screenshot launch mode (`-DEMO_MODE` / `-UI_TEST_SCREENSHOTS`) that opens the wallet home with demo balances, plus UI tests that capture in-app screenshots (wallet home, Send, Receive) for iPhone 6.9", iPhone 6.5", and 13" iPad. Updated App Store screenshots no longer show only the login screen and no longer depict messaging or AI screens.

## Transport security
This build does not dial the former raw-IP messaging host. There are no ATS arbitrary-load exceptions in the app Info.plist.

## Resubmission
This build is **1.1.1 (6)**. Please review the wallet path: Home → **Send** / **Receive**, and Menu → Settings / Support.

Thank you,
Telestai / Zeroa team
