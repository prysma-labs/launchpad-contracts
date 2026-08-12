# Verified creators

Launches on Prysma are tied to a **verified creator** — a public social identity linked to the deploying wallet — so every listing has a real person (or brand) behind it that participants can judge before they bid.

## Why verify creators

Open token factories make anonymous, throwaway launches trivial. Requiring a verified creator raises the stakes:

- **Accountability** — the creator’s public profile is shown with the token; reputation travels with the launch.
- **Signal** — buyers and invitees can evaluate who is shipping, not only what the ticker says.
- **Spam resistance** — farming disposable tokens from fresh wallets is less attractive when each launch burns social capital.

This is **attribution**, not KYC. We do not collect government ID. We require a durable public identity that the community can evaluate.

Today that identity is the creator’s **X (Twitter)** account. A **website** is optional metadata alongside it.

## How verification attaches to a launch

1. On `/launch`, the creator **links X** via OAuth (PKCE). The app holds a short-lived session with handle and user id.
2. Before `createLaunch`, the app requests a signed proof binding `{ handle, user id, wallet, issued-at }` (HMAC with `X_VERIFICATION_SECRET`).
3. That proof is packed into UERC20 `extraData` and submitted with the launch. `CcaLaunchFactory` **rejects** launches with empty `extraData`.

## UERC20 metadata

Tokens are Uniswap `UERC20`s. Metadata includes an opaque `extraData` field used for the creator proof:

```solidity
struct UERC20Metadata {
    string description;
    string website;   // optional
    string image;
    bytes extraData;  // opaque; not rendered in tokenURI JSON
}
```

`extraData` is stored onchain and readable via `token.metadata()`, but **not** included in the rendered `tokenURI` JSON. The launchpad encodes UTF-8 JSON as hex, for example:

```json
{
  "v": 1,
  "xVerificationToken": "<payload>.<sig>"
}
```

`website` is optional — only set when the creator provides one. The verified X profile is recovered from `extraData`, not from the website field.

Factory gate:

```solidity
if (params.metadata.extraData.length == 0) revert NeedXVerification();
```

## On the token page

Clients decode `metadata().extraData` and surface the verified creator’s X profile (and optional website) next to the listing so bidders see who stands behind the auction.
