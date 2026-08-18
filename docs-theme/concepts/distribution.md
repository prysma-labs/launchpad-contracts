# How does distribution work

Distributors grow an auction by sharing invite codes. Referred **bid volume** sets your tier. After the token lists, you claim a share of hook fees.

You start as a **Member**. You do not earn until referred volume hits **Scout (0.5 ETH)** — that mints a transferable NFT. Higher volume upgrades the badge and the fee weight.

Link X in the app to mint your own codes. You do not have to bid first. Creator-issued invites gate access but never mint this NFT (the creator already has the 20% creator claim). See [invite codes](invite-codes.md).

## How you get paid

After migrate, swaps pay a **0.4%** hook fee in ETH. That fee is split **20% creator / 75% distributors / 5% platform**. Full rates and a $10M example live on [Fees](fees.md).

The **75%** pool is split by **tier weight**, not raw volume:

`your weight / Σ (people in each tier × that tier’s weight)`

Same tier, same check. Extra ETH inside a tier does not raise the reward. A Partner is **35×** a Scout.

The **holder** of the NFT claims. Transfer the NFT, transfer unclaimed and future claims.

## Tiers

| Tier | Min ETH referred | Weight |
|---|---|---|
| Member | — | 0 (not minted) |
| Scout | 0.5 | 1 |
| Promoter | 1 | 2 |
| Advocate | 5 | 10 |
| Ambassador | 10 | 20 |
| Partner | 25 | 35 |

Example: one Partner and one Scout share the pool **35 : 1**. If the distributor pool is $30,000, the Partner claims about $29,167 and the Scout about $833.

## Lifecycle

1. Link X and become a distributor for that auction.
2. Share your code. Bids that use it credit **you** (not the creator).
3. Volume below 0.5 ETH stays pending. At 0.5 ETH the Scout NFT mints to you.
4. Crossing the next floor upgrades art and weight.
5. After migrate and harvest, claim as the current NFT holder.

## Onchain

| Contract | Role |
|---|---|
| [`ReferrerNFT`](../src/nft/ReferrerNFT.sol/contract.ReferrerNFT.md) | Mint at Scout; upgrade tier/art/weight with volume |
| [`InviteRegistry`](../src/invite/InviteRegistry.sol/contract.InviteRegistry.md) | Codes and attribution; credits the NFT |
| [`FeeDistributor`](../src/fee/FeeDistributor.sol/contract.FeeDistributor.md) | Holder claims `weight / totalWeight` of the 75% pool |
