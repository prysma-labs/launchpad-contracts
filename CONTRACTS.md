# Contracts

Scope: Foundry in this repo (`prysma-labs/launchpad-contracts`). The launchpad web app reads chain via wagmi/viem. Public NatSpec overview: [README.md](./README.md). Product overview: [prysma-labs/launchpad](https://github.com/prysma-labs/launchpad).

## Goal

Permissionless **CCA + LBPStrategy** launches via Uniswap LiquidityLauncher → migrate into a Uniswap v4 pool with invite referrals and hook fee distribution.

## Stack

- Foundry + vendored `Uniswap/liquidity-launcher` + `Uniswap/continuous-clearing-auction`
- Base Sepolia: Uniswap LiquidityLauncher `0x00004c4c…`; we deploy LBPStrategy, CCA factory, fee/invite stack
- Anvil: full local v4 + LL + CCA

## Launch model

1. Creator calls `CcaLaunchFactory.createLaunch` (requires non-empty `extraData` with X verification)
2. Factory mints `UERC20` via `LiquidityLauncher.createToken(UERC20Factory, …)` and `distributeToken` → `LBPStrategy` → CCA
3. Platform operator mints more invites (`createInvitesFor`) or authorizes a wallet via EIP-712 (`createInvites`) after X is linked
4. Bidders `submitBid(..., hookData)` with invite (validation hook)
5. After end: permissionless `LBPStrategy.migrate` seeds pool (fee=0.1%, hook=`LaunchFeeHook`)
6. Swaps → hook fees → `harvest` → `FeeDistributor` (20% / 75% / 5%)

Defaults: **50/50** auction/LP · pool LP **0.1%** · hook **0.4%** · platform `0xBb6f397d9d8bf128dDa607005397F539B43CD710`

## Contracts

- `CcaLaunchFactory` (mints Uniswap `UERC20` with metadata `description` / `website` / `image` / `extraData`)
- `InviteRegistry`, `InviteValidationHook`
- `ReferrerNFT` (10k collection minted as Recruit; Scout+ at 0.5 ETH referred volume; tier/art upgrade with volume)
- `FeeDistributor`, `LaunchFeeHook` (InitializerHook + ETH hook fee on buy and sell)
- Uniswap: `LiquidityLauncher`, `UERC20Factory`, `LBPStrategy`, `ContinuousClearingAuctionFactory`, `CompoundingClaimRecipient`

## Tests / deploy

```bash
forge test --match-contract CcaLaunchTest
./scripts/deploy-cca.sh
```

## NatSpec docs (Vercel)

Docs are generated from Solidity NatSpec (`@notice`, `@dev`, …) on each deploy — edit comments in `src/`, push, and the docs site rebuilds.

Styling lives in [`docs-theme/`](./docs-theme/) and is applied after `forge doc` (generated `docs/natspec/` is gitignored).

```bash
# Local
./scripts/build-docs.sh
# open docs/natspec/book/index.html
```

Vercel project (separate from launchpad `web`):

- **Root Directory:** `.` (this repo)
- Uses [`vercel.json`](./vercel.json) → `scripts/build-docs.sh` → output `docs/natspec/book`
- `lib/` is gitignored, so the build script clones Foundry deps at build time (ignore the “Failed to fetch git submodules” warning)
