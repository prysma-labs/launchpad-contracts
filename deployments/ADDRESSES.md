# Deployment addresses

| Network | File | Status |
|---|---|---|
| Local Anvil | [anvil.json](./anvil.json) / `*-cca.json` | local |
| **Base Sepolia** (84532) | [base-sepolia.json](./base-sepolia.json) / [base-sepolia-cca.json](./base-sepolia-cca.json) | **CCA deployed** |
| Robinhood Chain (4663) | [robinhood.json](./robinhood.json) | later |

## Quick reference — Base Sepolia (Uniswap)

| Contract | Address |
|---|---|
| Permit2 | `0x000000000022D473030F116dDEE9F6B43aC78BA3` |
| PoolManager | `0x05E73354cFDd6745C338b50BcFDfA3Aa6fA03408` |
| PositionManager | `0x4B2C77d209D3405F41a037Ec6c77F7F5b8e2ca80` |
| LiquidityLauncher | `0x00004c4ccc709Ef590F7C81102C0689F0263D4e9` |

### CCA launchpad (start block `45446073`)

| Contract | Address |
|---|---|
| CcaLaunchFactory | [`0x62BC6Cc08aE4240ee30A5e8226E3628aD146923C`](https://sepolia.basescan.org/address/0x62BC6Cc08aE4240ee30A5e8226E3628aD146923C) |
| LBPStrategy | [`0x4Eb8832b4118861e010750977e4329D9b5d9E000`](https://sepolia.basescan.org/address/0x4Eb8832b4118861e010750977e4329D9b5d9E000) |
| ContinuousClearingAuctionFactory | [`0x2a309aa22FaF71d3F0d593Be3fDA76E869D40415`](https://sepolia.basescan.org/address/0x2a309aa22FaF71d3F0d593Be3fDA76E869D40415) |
| LaunchFeeHook | [`0xc9921B2965473F1944a5697072DB799C1FABa044`](https://sepolia.basescan.org/address/0xc9921B2965473F1944a5697072DB799C1FABa044) |
| FeeDistributor | [`0xCF0378210c6Cda4526F29Af9e09e90267DE65068`](https://sepolia.basescan.org/address/0xCF0378210c6Cda4526F29Af9e09e90267DE65068) |
| InviteRegistry | [`0x768A252b399c7180aDDFDEb981518ba9cF236E89`](https://sepolia.basescan.org/address/0x768A252b399c7180aDDFDEb981518ba9cF236E89) |
| InviteValidationHook | [`0x6280531b9D85937fb54433A7E42cdA4fb214E2aB`](https://sepolia.basescan.org/address/0x6280531b9D85937fb54433A7E42cdA4fb214E2aB) |
| CompoundingClaimRecipient | [`0x26b279e4876784d7f62Add72A55D61E5E5c4119F`](https://sepolia.basescan.org/address/0x26b279e4876784d7f62Add72A55D61E5E5c4119F) |
| UERC20Factory | [`0x25805c1744de4C9f9d5548B7942256D97e8f016d`](https://sepolia.basescan.org/address/0x25805c1744de4C9f9d5548B7942256D97e8f016d) |
| Deployer | `0xf8543D5b72EF43D0F99b6471424CB2D8dE097324` |

```bash
./scripts/deploy-cca.sh
```
