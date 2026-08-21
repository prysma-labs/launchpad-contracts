---
description: "Invite-gated bidding, referral attribution, and how codes map to hookData."
icon: ticket
---

# Invite codes

Auctions are **invite-gated**: every CCA bid must include a valid invite code, unless the bidder is the creator or already holds a distributor NFT. That keeps early participation intentional, and it is how referrers earn a share of post-migrate hook fees.

## Why invites

- **Access control** — auctions are invite-gated; there is no open free-for-all at auction open. The creator is not a distributor and cannot mint codes unless they separately hold a Recruit NFT.
- **Distribution** — wallets that hold a Recruit NFT can mint their own codes and grow the bidder set. Wallets without the NFT cannot generate codes.
- **Referral economics** — each bid’s size is credited to the inviter’s referrer NFT (not the creator). After migrate, **75%** of hook fees go to those NFTs, split by [tier weight](distribution.md). Recruit weight is 0; Scout+ earns.

## Lifecycle

1. **Launch** — `CcaLaunchFactory.createLaunch` registers the auction on `InviteRegistry`. No invite is seeded for the creator.
2. **Create invites** — only the platform operator can mint codes, or authorize a wallet with an EIP-712 signature. The issuer must hold a distributor NFT.
3. **Share** — NFT holders share a human-readable string. The app hashes it with `keccak256` to the onchain `bytes32` (or accepts a raw `0x…` hash).
4. **Bid** — `submitBid` passes the code as CCA `hookData` (exactly 32 bytes). `InviteValidationHook` decodes it and calls `InviteRegistry.useInvite`. NFT holders and the creator may bid without a valid code.
5. **Attribute volume** — every bid’s currency amount is credited to the bidder’s original inviter, except when that inviter is the auction creator. Repeat bids by the same address add more volume to that same referrer; the invite is not re-checked. Unknown or self-invites revert on first bid unless the bidder holds an NFT. Volume below 0.5 ETH stays Recruit; at Scout the same NFT upgrades and starts earning.
6. **Grow the graph** — an NFT holder may `createInvites` for that auction and share new codes. Bidding is not required.

## Onchain pieces

| Contract | Role |
|---|---|
| [`InviteRegistry`](https://github.com/prysma-labs/launchpad-contracts/blob/main/src/invite/InviteRegistry.sol) | Stores codes → issuer and participation; credits `ReferrerNFT` |
| [`InviteValidationHook`](https://github.com/prysma-labs/launchpad-contracts/blob/main/src/invite/InviteValidationHook.sol) | CCA validation hook; requires `hookData` = invite `bytes32` |
| [`ReferrerNFT`](https://github.com/prysma-labs/launchpad-contracts/blob/main/src/nft/ReferrerNFT.sol) | 10k transferable claim NFT; mint as Recruit, upgrade art/weight by volume |
| [`FeeDistributor`](https://github.com/prysma-labs/launchpad-contracts/blob/main/src/fee/FeeDistributor.sol) | Pays NFT holders using `IReferralSource` tier weights |

Validation (simplified):

```solidity
function validate(..., bytes calldata hookData) external {
    if (hookData.length != 32) revert InvalidHookData();
    bytes32 code = abi.decode(hookData, (bytes32));
    registry.useInvite(msg.sender, owner, code, amount);
}
```

Offchain invite DBs in the web app are UX-only (listing codes, links with `?invite=`). **Authority is onchain** in `InviteRegistry`.
