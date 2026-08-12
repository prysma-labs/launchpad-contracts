# Invite codes

Auctions are **invite-gated**: every CCA bid must include a valid invite code. That keeps early participation intentional, and it is how referrers earn a share of post-migrate hook fees.

## Why invites

- **Access control** — creators decide who can bid first by sharing codes; there is no open free-for-all at auction open.
- **Distribution** — participants who get in can mint their own codes and grow the bidder set.
- **Referral economics** — each bid’s size is credited to the inviter. After migrate, **75%** of hook fees go to referrers pro-rata by that volume (see [Fees](fees.md)).

## Lifecycle

1. **Launch** — `CcaLaunchFactory.createLaunch` registers the auction on `InviteRegistry`. It does **not** seed invites.
2. **Create invites** — the creator (or later a participant) calls `createInvites` with `bytes32` codes.
3. **Share** — creators (and later participants) share a human-readable string. The app hashes it with `keccak256` to the onchain `bytes32` (or accepts a raw `0x…` hash).
4. **Bid** — `submitBid` passes the code as CCA `hookData` (exactly 32 bytes). `InviteValidationHook` decodes it and calls `InviteRegistry.useInvite`.
5. **Attribute volume** — every bid’s currency amount is credited to the bidder’s original inviter. Repeat bids by the same address add more volume to that same referrer; the invite is not re-checked. Unknown or self-invites revert on first bid.
6. **Grow the graph** — after participating, an address may `createInvites` for that auction and share new codes.

## Onchain pieces

| Contract | Role |
|---|---|
| [`InviteRegistry`](../src/invite/InviteRegistry.sol/contract.InviteRegistry.md) | Stores codes → issuer, participation, referred bid volume |
| [`InviteValidationHook`](../src/invite/InviteValidationHook.sol/contract.InviteValidationHook.md) | CCA validation hook; requires `hookData` = invite `bytes32` |
| [`FeeDistributor`](../src/fee/FeeDistributor.sol/contract.FeeDistributor.md) | Pays referrers using `IReferralSource.referralVolume` |

Validation (simplified):

```solidity
function validate(..., bytes calldata hookData) external {
    if (hookData.length != 32) revert InvalidHookData();
    bytes32 code = abi.decode(hookData, (bytes32));
    registry.useInvite(msg.sender, owner, code, amount);
}
```

Offchain invite DBs in the web app are UX-only (listing codes, links with `?invite=`). **Authority is onchain** in `InviteRegistry`.
