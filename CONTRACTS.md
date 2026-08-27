# Contracts

Scope: Foundry in this repo (`prysma-labs/launchpad-contracts`). The launchpad web app reads chain via wagmi/viem. Public docs: HonKit, sourced from [`docs/`](./docs/). Product app: [prysma-labs/launchpad](https://github.com/prysma-labs/launchpad).

## Goal

Permissionless **CCA + LBPStrategy** launches via Uniswap LiquidityLauncher → migrate into a Uniswap v4 pool with hook fee distribution.

## Stack

- Foundry + vendored `Uniswap/liquidity-launcher` + `Uniswap/continuous-clearing-auction`
- Base Sepolia: Uniswap LiquidityLauncher `0x00004c4c…`; we deploy LBPStrategy, CCA factory, fee stack
- Anvil: full local v4 + LL + CCA

## Launch model

1. Creator calls `CcaLaunchFactory.createLaunch` (requires non-empty `extraData` with X verification)
2. Factory mints `UERC20` via `LiquidityLauncher.createToken(UERC20Factory, …)` and `distributeToken` → `LBPStrategy` → CCA
3. Anyone can `submitBid` (no invite gate)
4. After end: permissionless `LBPStrategy.migrate` seeds pool (fee=0.1%, hook=`LaunchFeeHook`)
5. Swaps → hook fees → `harvest` → `FeeDistributor` (95% creator / 5% platform)

Defaults: **50/50** auction/LP · pool LP **0.1%** · hook **0.4%** · platform `0xBb6f397d9d8bf128dDa607005397F539B43CD710`

## Contracts

- `CcaLaunchFactory` (mints Uniswap `UERC20` with metadata `description` / `website` / `image` / `extraData`)
- `InviteRegistry`, `InviteValidationHook` (deployed, not wired into auctions)
- `ReferrerNFT` (10k collection minted as Recruit; no fee share yet)
- `FeeDistributor`, `LaunchFeeHook` (InitializerHook + ETH hook fee on buy and sell)
- Uniswap: `LiquidityLauncher`, `UERC20Factory`, `LBPStrategy`, `ContinuousClearingAuctionFactory`, `CompoundingClaimRecipient`

## Tests / deploy

```bash
forge test --match-contract CcaLaunchTest
./scripts/deploy-cca.sh
```

## Docs (HonKit)

Markdown lives in [`docs/`](./docs/). NatSpec API pages are generated from `src/` via `forge doc`. Preview with `pnpm docs`, or build with `pnpm docs:build`. Vercel publishes `_book/` to `docs.prysma.trade`.
