# Fees

Defaults (overridable at launch where noted):

| Parameter | Default | Notes |
|---|---|---|
| Token split | **50%** auction / **50%** LP | `auctionSupplyBps`; remainder reserved for the post-migrate position |
| Pool LP fee | **0.1%** | Accrues to the locked LP NFT; autocompounded back into the pool via `CompoundingClaimRecipient` |
| Hook fee | **0.4%** | Taken by `LaunchFeeHook` in **ETH** on both sides: buys via `beforeSwap` (specified ETH), sells via `afterSwap` (ETH out) |
| Hook fee split | **20%** creator / **75%** distributors / **5%** platform | Fixed in `FeeDistributor`. How the 75% is split is in [How does distribution work](distribution.md). |

The 20/75/5 hook-fee split is fixed in `FeeDistributor`. The auction/LP token split and fee rates can be overridden at launch.

## Example — $10M trading volume

Assume a **$50k** auction raise seeds the locked LP (default 50/50 auction/LP split).

| Fee | Rate | On $10M volume |
|---|---|---|
| Pool LP fee (autocompounded) | 0.1% | **$10,000** reinvested into the position → liquidity **$50k → $60k** |
| Hook fee (distributed) | 0.4% | **$40,000** harvested into `FeeDistributor` |

Hook fee split of that **$40,000**:

- Creator claims **$8,000** (20%)
- Platform claims **$2,000** (5%)
- Distributor pool gets **$30,000** (75%), split by [tier weight](distribution.md).
