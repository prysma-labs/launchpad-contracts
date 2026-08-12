# Overview

Invite-gated token launches on Uniswap v4. Creators open a [Continuous Clearing Auction (CCA)](https://developers.uniswap.org/docs/liquidity/liquidity-launchpad/concepts/cca); after graduation, proceeds seed a locked v4 pool. This repo adds invite validation and [hook](https://developers.uniswap.org/docs/protocols/v4/concepts/hooks)-based fee distribution on top of Uniswap’s [Liquidity Launchpad](https://developers.uniswap.org/docs/liquidity/liquidity-launchpad/overview).

## Mechanics

Launches use Uniswap’s [CCA](https://developers.uniswap.org/docs/liquidity/liquidity-launchpad/concepts/cca): bidders set a budget and max price; each block, a release schedule allocates tokens to active bids at a uniform clearing price. Early participation is rewarded and last-minute sniping is ineffective — see the [CCA overview](https://developers.uniswap.org/docs/liquidity/liquidity-launchpad/overview) and [whitepaper](https://developers.uniswap.org/whitepaper_cca.pdf).

Flow in this stack:

1. **Launch** — `CcaLaunchFactory` mints a fixed-supply Uniswap `UERC20` (with required X verification in `extraData`), seeds invite codes, and opens a CCA via [LiquidityLauncher → LBPStrategy](https://developers.uniswap.org/docs/liquidity/liquidity-launchpad/concepts/liquidity-strategies).
2. **Bid** — Participants `submitBid` with invite `hookData`, checked by `InviteValidationHook` / `InviteRegistry` (referral weight is recorded for later fee claims).
3. **Migrate** — After the auction ends, anyone can call LBP [`migrate`](https://developers.uniswap.org/docs/liquidity/liquidity-launchpad/concepts/liquidity-strategies) to seed an ETH/token v4 pool at the discovered price, with `LaunchFeeHook` attached.
4. **Trade & claim** — Swaps accrue hook fees; `harvest` pushes balances to `FeeDistributor` for creator / referrer / platform claims. Auction winners claim tokens after the configured claim block.

## Fees

Defaults (overridable at launch where noted):

| Parameter | Default | Notes |
|---|---|---|
| Token split | **50%** auction / **50%** LP | `auctionSupplyBps`; remainder reserved for the post-migrate position |
| Pool LP fee | **0.1%** | Accrues to the locked LP NFT; autocompounded back into the pool via `CompoundingClaimRecipient` |
| Hook fee | **0.4%** | Taken by `LaunchFeeHook` on the unspecified swap amount (`afterSwap`) |
| Hook fee split | **20%** creator / **75%** referrers / **5%** platform | Fixed in `FeeDistributor`; referrers share pro-rata by invite count |

**Example — $10M trading volume**

Assume a **$50k** auction raise seeds the locked LP (default 50/50 auction/LP split).

| Fee | Rate | On $10M volume |
|---|---|---|
| Pool LP fee (autocompounded) | 0.1% | **$10,000** reinvested into the position → liquidity **$50k → $60k** |
| Hook fee (distributed) | 0.4% | **$40,000** harvested into `FeeDistributor` |

Hook fee split of that **$40,000**:

- Creator claims **$8,000** (20%)
- Platform claims **$2,000** (5%)
- Referrer pool gets **$30,000** (75%). Shared pro-rata across referrers by invite count — with **100** equal-weight referrers, each can claim **$300**.

## Contracts

| Contract | Role |
|---|---|
| [`CcaLaunchFactory`](src/strategy/CcaLaunchFactory.sol/contract.CcaLaunchFactory.md) | Create UERC20 + CCA/LBP launch (requires `extraData` X verification) |
| [`InviteRegistry`](src/invite/InviteRegistry.sol/contract.InviteRegistry.md) | Invite codes + referral weights |
| [`InviteValidationHook`](src/invite/InviteValidationHook.sol/contract.InviteValidationHook.md) | CCA bid gate (`hookData`) |
| [`LaunchFeeHook`](src/fee/LaunchFeeHook.sol/contract.LaunchFeeHook.md) | Post-migrate swap hook fee |
| [`FeeDistributor`](src/fee/FeeDistributor.sol/contract.FeeDistributor.md) | Claimable 20/75/5 fee split |
| [`IReferralSource`](src/fee/IReferralSource.sol/interface.IReferralSource.md) | Referral weight interface |

Upstream Uniswap pieces used at runtime (not in this repo’s `src/`): LiquidityLauncher, LBPStrategy, Continuous Clearing Auction, CompoundingClaimRecipient, UERC20Factory / UERC20.
