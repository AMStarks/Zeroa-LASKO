# Reply to App Review

Hello App Review team,

Thank you for the feedback on Zeroa (`com.telestai.Zeroa`).

## Guideline 2.1(a) — App Completeness
We fixed the Switchboard attachment controls (**Photo**, **Camera**, **Document**, **Location**, **Audio**).

Each control now presents the appropriate system UI (`PHPickerViewController`, camera, `UIDocumentPickerViewController`, Core Location, and an in-app audio recorder) from the top-most view controller so the pickers work inside the messaging sheet on both iPhone and iPad (including popover/`formSheet` presentation on iPad). Permission denials show an alert with an **Open Settings** action. The Info.plist usage descriptions for Camera, Photo Library, Microphone, and Location When In Use are present with clear user-facing text.

## Guideline 2.3.3 — Accurate Metadata
We added a demo / screenshot launch mode (`-DEMO_MODE` / `-UI_TEST_SCREENSHOTS`) that opens the wallet home with demo balances and Switchboard contacts, plus UI tests that capture in-app screenshots (wallet, send/receive, AI, messages, attachments) for iPhone 6.9", iPhone 6.5", and 13" iPad. Updated App Store screenshots no longer show only the login screen.

## Transport security
Switchboard messaging no longer uses a raw IP over cleartext HTTP/WS; the app calls **`https://api.telestai.io`** (and WSS) with no ATS arbitrary-load exceptions.

## Guideline 5.1.1 / 5.1.2 — AI data sharing
Before any request to **xAI**, users see a one-time **Allow / Not now** consent that describes the data shared, names xAI as the third-party provider, and links to our Privacy Policy; Settings can grant or revoke consent, and declined users never trigger AI network calls.

## Resubmission
This build is **1.1.1 (4)**. Please use the Switchboard path: Messaging → Alice → **+** to exercise the attachment buttons, and the **AI** tab / Settings for consent.

Thank you,
Telestai / Zeroa team
