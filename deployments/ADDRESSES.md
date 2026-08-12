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

### CCA launchpad (start block `45401600`)

| Contract | Address |
|---|---|
| CcaLaunchFactory | [`0x938363129afd4Df7b441696fc436657aD637260f`](https://sepolia.basescan.org/address/0x938363129afd4Df7b441696fc436657aD637260f) |
| LBPStrategy | [`0x7F28ef707f36EE05Fc576c62b3B5c2EaeD55A000`](https://sepolia.basescan.org/address/0x7F28ef707f36EE05Fc576c62b3B5c2EaeD55A000) |
| ContinuousClearingAuctionFactory | [`0x643c96A46fB316A73679d2BCd7F821BE272B2b07`](https://sepolia.basescan.org/address/0x643c96A46fB316A73679d2BCd7F821BE272B2b07) |
| LaunchFeeHook | [`0x26ba4C6Ebd4f34F3db58403bADF50352620D2044`](https://sepolia.basescan.org/address/0x26ba4C6Ebd4f34F3db58403bADF50352620D2044) |
| FeeDistributor | [`0x1480495034830b70921B3F6F7E69d7A853B5ac86`](https://sepolia.basescan.org/address/0x1480495034830b70921B3F6F7E69d7A853B5ac86) |
| InviteRegistry | [`0x954d0F9A3b06Ac217F759060A78750b0b03b5e2C`](https://sepolia.basescan.org/address/0x954d0F9A3b06Ac217F759060A78750b0b03b5e2C) |
| InviteValidationHook | [`0x8EF88BAA513BC3145EdeDe2C349A123Fe00594e1`](https://sepolia.basescan.org/address/0x8EF88BAA513BC3145EdeDe2C349A123Fe00594e1) |
| CompoundingClaimRecipient | [`0xb74EC2BE203487477a862E19EE979C7173fa35C4`](https://sepolia.basescan.org/address/0xb74EC2BE203487477a862E19EE979C7173fa35C4) |
| UERC20Factory | [`0x25805c1744de4C9f9d5548B7942256D97e8f016d`](https://sepolia.basescan.org/address/0x25805c1744de4C9f9d5548B7942256D97e8f016d) |
| Deployer | `0xf8543D5b72EF43D0F99b6471424CB2D8dE097324` |

```bash
./scripts/deploy-cca.sh
```
