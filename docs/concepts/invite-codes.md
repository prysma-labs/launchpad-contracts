# Invite codes

Auctions are **open**. Anyone can `submitBid` without an invite. `CcaLaunchFactory` deploys each CCA with `validationHook = address(0)`.

`InviteRegistry` and `InviteValidationHook` remain in the repo for a later referral program. They are **not wired into launches** and do not gate bids or pay fees.

## Current bidding

1. **Launch** — `CcaLaunchFactory.createLaunch` mints the token and opens a CCA. No invite is seeded.
2. **Bid** — `submitBid` with empty `hookData`. There is no onchain invite check.
3. **Migrate** — After the auction, permissionless migrate seeds the v4 pool. Hook fees go to the creator and platform. See [Fees](fees.md).

Offchain invite tables in the web app (`?invite=`, acceptances) are unused for access control.
