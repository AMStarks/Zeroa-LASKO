# Notes for App Review — Zeroa 1.1.1 (8)

## Scope of this build
This build is wallet-only.

- Included: create or restore a wallet, view balances, Send, Receive, Settings, Support, Delete Account
- Not in this build: Switchboard messaging, AI / Nova / xAI, Network Stats

Messaging and AI are not in the menu. Their network clients stay off.

## Account deletion (Guideline 5.1.1)
1. Create an account, or sign in with a recovery phrase.
2. Open the bottom menu, then **Settings**, then **Delete Account**. The same button is on **Profile**.
3. The screen says deleting the account does not affect on-chain funds, and it asks the user to back up the recovery phrase.
4. Turn on **I have written down my recovery phrase**, tap **Delete Account**, then confirm.
5. The app signs a Halo challenge and calls `POST https://halo.telestai.io/api/halo/account/delete`. That deletes the Halo account data for the wallet address (sign-in material and indexed posts). It does not move coins.
6. After Halo accepts the deletion, the app wipes the wallet from this device and returns to the login screen.

There is no website step. Deletion finishes in the app.

## Demo / screenshot mode
Launch with `-DEMO_MODE` or `-UI_TEST_SCREENSHOTS` for screenshots. A normal App Review install does not use that mode.

## How to reach each feature
1. Wallet balances — home after sign-in.
2. Send / Receive — home buttons. Send does not broadcast a transaction in this version and says so. It does not show a fake success.
3. Settings / Support — bottom menu.
4. Delete Account — menu → Settings → Delete Account.

## Support URL
`https://telestai.org/faq` does not resolve from this network. `https://docs.telestai.io` returns HTTP 200. In-app support is Support & Help, plus `mailto:support@telestai.com`.
