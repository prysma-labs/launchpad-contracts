# Fees

Defaults (overridable at launch where noted):

| Parameter | Default | Notes |
|---|---|---|
| Token split | **50%** auction / **50%** LP | `auctionSupplyBps`; remainder reserved for the post-migrate position |
| Pool LP fee | **0.1%** | Accrues to the locked LP NFT; autocompounded back into the pool via `CompoundingClaimRecipient` |
| Hook fee | **0.4%** | Taken by `LaunchFeeHook` on the unspecified swap amount (`afterSwap`) |
| Hook fee split | **20%** creator / **75%** referrers / **5%** platform | Fixed in `FeeDistributor`; referrers share pro-rata by referred bid volume |

## Example — $10M trading volume

Assume a **$50k** auction raise seeds the locked LP (default 50/50 auction/LP split).

| Fee | Rate | On $10M volume |
|---|---|---|
| Pool LP fee (autocompounded) | 0.1% | **$10,000** reinvested into the position → liquidity **$50k → $60k** |
| Hook fee (distributed) | 0.4% | **$40,000** harvested into `FeeDistributor` |

Hook fee split of that **$40,000**:

- Creator claims **$8,000** (20%)
- Platform claims **$2,000** (5%)
- Referrer pool gets **$30,000** (75%). Shared pro-rata across referrers by the bid volume they brought — if Alice referred **$1** of bids and Bob referred **$100**, Bob claims **$30,000 × 100/101** and Alice claims the rest.
