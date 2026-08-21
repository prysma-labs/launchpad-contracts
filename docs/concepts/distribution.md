# How does distribution work

Distributors grow an auction by sharing invite codes. Referred **bid volume** sets your tier. After the token lists, you claim a share of hook fees.

A **10,000** collection is minted separately as **Recruit**. Holding one makes you a distributor on every auction — you do not need an invite to join, and you can create codes. Recruit has **weight 0** and does not earn. Referred volume of **0.5 ETH** upgrades the same NFT to **Scout** and fee share starts. Higher volume upgrades the badge and the fee weight.

Wallets without the NFT cannot generate invite codes. If a creator also holds an NFT and issues invites, those codes gate access but never earn this NFT’s fee share (the creator already has the 20% creator claim). See [invite codes](invite-codes.md).

## How you get paid

After migrate, swaps pay a **0.4%** hook fee in ETH. That fee is split **20% creator / 75% distributors / 5% platform**. Full rates and a $10M example live on [Fees](fees.md).

The **75%** pool is split by **tier weight**, not raw volume:

`your weight / Σ (people in each tier × that tier’s weight)`

Same tier, same check. Extra ETH inside a tier does not raise the reward. A Partner is **35×** a Scout.

The **holder** of the NFT claims. Transfer the NFT, transfer unclaimed and future claims.

## Tiers

| Tier | Min ETH referred | Weight |
|---|---|---|
| Recruit | minted | 0 (no fees) |
| Scout | 0.5 | 1 |
| Promoter | 1 | 2 |
| Advocate | 5 | 10 |
| Ambassador | 10 | 20 |
| Partner | 25 | 35 |

Example: one Partner and one Scout share the pool **35 : 1**. If the distributor pool is $30,000, the Partner claims about $29,167 and the Scout about $833.

## Lifecycle

1. Mint a Recruit NFT from the 10,000 collection (or receive one).
2. Open any auction — you are already a distributor. Share your code. Bids that use it credit **you** (not the creator).
3. Volume below 0.5 ETH stays Recruit (weight 0). At 0.5 ETH the same NFT upgrades to Scout.
4. Crossing the next floor upgrades art and weight.
5. After migrate and harvest, claim as the current NFT holder.

## Onchain

| Contract | Role |
|---|---|
| [`ReferrerNFT`](../api/ReferrerNFT.md) | 10k Recruit mint; upgrade tier/art/weight with per-auction volume |
| [`InviteRegistry`](../api/InviteRegistry.md) | Codes and attribution; only NFT holders mint codes |
| [`FeeDistributor`](../api/FeeDistributor.md) | Holder claims `weight / totalWeight` of the 75% pool |
