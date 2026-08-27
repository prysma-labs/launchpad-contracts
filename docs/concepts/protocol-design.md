# Protocol Design

Open token launches on Uniswap v4. Creators open a [Continuous Clearing Auction (CCA)](https://developers.uniswap.org/docs/liquidity/liquidity-launchpad/concepts/cca); after graduation, proceeds seed a locked v4 pool. This repo adds a [hook](https://developers.uniswap.org/docs/protocols/v4/concepts/hooks)-based fee split on top of Uniswap’s [Liquidity Launchpad](https://developers.uniswap.org/docs/liquidity/liquidity-launchpad/overview).

## Mechanics

Launches use Uniswap’s [CCA](https://developers.uniswap.org/docs/liquidity/liquidity-launchpad/concepts/cca): bidders set a budget and max price; each block, a release schedule allocates tokens to active bids at a uniform clearing price. Early participation is rewarded and last-minute sniping is ineffective — see the [CCA overview](https://developers.uniswap.org/docs/liquidity/liquidity-launchpad/overview) and [whitepaper](https://developers.uniswap.org/whitepaper_cca.pdf).

Flow in this stack:

1. **Launch** — `CcaLaunchFactory` mints a fixed-supply Uniswap `UERC20` (with required X verification in `extraData`) and opens a CCA via [LiquidityLauncher → LBPStrategy](https://developers.uniswap.org/docs/liquidity/liquidity-launchpad/concepts/liquidity-strategies).
2. **Bid** — Anyone can `submitBid`. There is no invite gate.
3. **Migrate** — After the auction ends, anyone can call LBP [`migrate`](https://developers.uniswap.org/docs/liquidity/liquidity-launchpad/concepts/liquidity-strategies) to seed an ETH/token v4 pool at the discovered price, with `LaunchFeeHook` attached.
4. **Trade & claim** — Swaps accrue hook fees; `harvest` pushes balances to `FeeDistributor` for creator / platform claims. Auction winners claim tokens after the configured claim block.

## Concepts

| Concept | What it covers |
|---|---|
| [Fees](fees.md) | Auction/LP split, hook fee, 95/5 claims |
| [How does distribution work](distribution.md) | Distributor NFTs (currently unused for fees) |
| [Verified creators](verified-creators.md) | Why launches require a public creator identity, and how the proof is stored in UERC20 `extraData` |
| [Invite codes](invite-codes.md) | Invites are not live; auctions are open |

## API Reference

| Contract | Role |
|---|---|
| [`CcaLaunchFactory`](../api/CcaLaunchFactory.md) | Create UERC20 + CCA/LBP launch (requires `extraData` X verification) |
| [`InviteRegistry`](../api/InviteRegistry.md) | Unused invite registry (later referrals) |
| [`InviteValidationHook`](../api/InviteValidationHook.md) | Unused CCA bid gate |
| [`ReferrerNFT`](../api/ReferrerNFT.md) | Transferable distributor NFT (no fee share yet) |
| [`LaunchFeeHook`](../api/LaunchFeeHook.md) | Post-migrate swap hook fee |
| [`FeeDistributor`](../api/FeeDistributor.md) | Claimable 95/5 fee split |
| [`IReferralSource`](../api/IReferralSource.md) | NFT tier-weight interface |

Upstream Uniswap pieces used at runtime (not in this repo’s `src/`): LiquidityLauncher, LBPStrategy, Continuous Clearing Auction, CompoundingClaimRecipient, UERC20Factory / UERC20.
