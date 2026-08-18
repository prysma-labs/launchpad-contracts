# Invite codes

Auctions are **invite-gated**: every CCA bid must include a valid invite code. That keeps early participation intentional, and it is how referrers earn a share of post-migrate hook fees.

## Why invites

- **Access control** — creators decide who can bid first by sharing codes; there is no open free-for-all at auction open.
- **Distribution** — anyone who links X can mint their own codes and grow the bidder set.
- **Referral economics** — each bid’s size is credited to the inviter’s referrer NFT (not the creator). After migrate, **75%** of hook fees go to those NFTs, split by [tier weight](distribution.md).

## Lifecycle

1. **Launch** — `CcaLaunchFactory.createLaunch` registers the auction on `InviteRegistry` and seeds the creator’s first invite. Creator-issued invites gate bids but do **not** mint a distributor NFT.
2. **Create invites** — only the platform operator can mint more codes, or authorize a wallet with an EIP-712 signature after X is linked.
3. **Share** — creators (and later participants) share a human-readable string. The app hashes it with `keccak256` to the onchain `bytes32` (or accepts a raw `0x…` hash).
4. **Bid** — `submitBid` passes the code as CCA `hookData` (exactly 32 bytes). `InviteValidationHook` decodes it and calls `InviteRegistry.useInvite`.
5. **Attribute volume** — every bid’s currency amount is credited to the bidder’s original inviter, except when that inviter is the auction creator. Repeat bids by the same address add more volume to that same referrer; the invite is not re-checked. Unknown or self-invites revert on first bid. Volume below 0.5 ETH stays pending; at Scout the NFT mints to the issuer.
6. **Grow the graph** — after linking X, an address may `createInvites` for that auction and share new codes. Bidding is not required.

## Onchain pieces

| Contract | Role |
|---|---|
| [`InviteRegistry`](../src/invite/InviteRegistry.sol/contract.InviteRegistry.md) | Stores codes → issuer and participation; credits `ReferrerNFT` |
| [`InviteValidationHook`](../src/invite/InviteValidationHook.sol/contract.InviteValidationHook.md) | CCA validation hook; requires `hookData` = invite `bytes32` |
| [`ReferrerNFT`](../src/nft/ReferrerNFT.sol/contract.ReferrerNFT.md) | Transferable claim NFT; mint at Scout, upgrade art/weight by volume |
| [`FeeDistributor`](../src/fee/FeeDistributor.sol/contract.FeeDistributor.md) | Pays NFT holders using `IReferralSource` tier weights |

Validation (simplified):

```solidity
function validate(..., bytes calldata hookData) external {
    if (hookData.length != 32) revert InvalidHookData();
    bytes32 code = abi.decode(hookData, (bytes32));
    registry.useInvite(msg.sender, owner, code, amount);
}
```

Offchain invite DBs in the web app are UX-only (listing codes, links with `?invite=`). **Authority is onchain** in `InviteRegistry`.
