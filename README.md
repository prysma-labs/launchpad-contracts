# Prysma Launchpad Documentation

Permissionless memecoin launches on Uniswap v4: creators open an invite-gated **Continuous Clearing Auction (CCA)**; on graduation, liquidity migrates into a locked v4 pool with hook fees split among creator, referrers, and the platform.

## How it fits together

1. **Launch** — `CcaLaunchFactory` mints a fixed-supply `LaunchToken`, seeds invites, and opens a CCA via LiquidityLauncher → LBPStrategy.
2. **Bid** — Participants submit CCA bids with invite `hookData`, validated by `InviteValidationHook` / `InviteRegistry`.
3. **Migrate** — After the auction ends and graduates, permissionless LBP migrate seeds a v4 ETH/token pool with `LaunchFeeHook`.
4. **Trade & claim** — Swaps accrue hook fees; `harvest` pushes balances to `FeeDistributor` for creator / referrer / platform claims.

Default economics: **50%** auction / **50%** LP · pool LP fee **0.1%** · hook fee **0.4%** (split **20% / 75% / 5%**).

## Contracts

| Contract | Role | Docs |
|---|---|---|
| [`CcaLaunchFactory`](src/strategy/CcaLaunchFactory.sol/contract.CcaLaunchFactory.md) | Create token + CCA/LBP launch | NatSpec |
| [`LaunchToken`](src/LaunchToken.sol/contract.LaunchToken.md) | Fixed-supply ERC-20 + metadata | NatSpec |
| [`InviteRegistry`](src/invite/InviteRegistry.sol/contract.InviteRegistry.md) | Invite codes + referral weights | NatSpec |
| [`InviteValidationHook`](src/invite/InviteValidationHook.sol/contract.InviteValidationHook.md) | CCA bid gate (`hookData`) | NatSpec |
| [`LaunchFeeHook`](src/fee/LaunchFeeHook.sol/contract.LaunchFeeHook.md) | Post-migrate swap hook fee | NatSpec |
| [`FeeDistributor`](src/fee/FeeDistributor.sol/contract.FeeDistributor.md) | Claimable 20/75/5 fee split | NatSpec |
| [`IReferralSource`](src/fee/IReferralSource.sol/interface.IReferralSource.md) | Referral weight interface | NatSpec |

Upstream Uniswap pieces used at runtime (not in this repo’s `src/`): LiquidityLauncher, LBPStrategy, Continuous Clearing Auction, CompoundingClaimRecipient.
