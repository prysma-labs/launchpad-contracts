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

### CCA launchpad (start block `46085020`)

| Contract | Address |
|---|---|
| CcaLaunchFactory | [`0x129E7c71b0fd7e1B795487e7B09D4b7b05b28B1C`](https://sepolia.basescan.org/address/0x129E7c71b0fd7e1B795487e7B09D4b7b05b28B1C) |
| LBPStrategy | [`0xe62458f660556f259b737bc28b7B284AF28fe000`](https://sepolia.basescan.org/address/0xe62458f660556f259b737bc28b7B284AF28fe000) |
| ContinuousClearingAuctionFactory | [`0x95397c93C417f90850c008c1BD5abE0766467A6B`](https://sepolia.basescan.org/address/0x95397c93C417f90850c008c1BD5abE0766467A6B) |
| LaunchFeeHook | [`0x6489F6Efbf7B8df6D5662eB8E560e690aeCC20Cc`](https://sepolia.basescan.org/address/0x6489F6Efbf7B8df6D5662eB8E560e690aeCC20Cc) |
| FeeDistributor | [`0x899197e24c3D7FB722c9103106ceF7e197e5f981`](https://sepolia.basescan.org/address/0x899197e24c3D7FB722c9103106ceF7e197e5f981) |
| InviteRegistry | [`0xEa75Af8746af9d71681bCcC0aAb55ad8a7EfEdaC`](https://sepolia.basescan.org/address/0xEa75Af8746af9d71681bCcC0aAb55ad8a7EfEdaC) |
| InviteValidationHook | [`0x754f1B5fc53B0063E0DA0BfbE85DBb4F284fC7Ac`](https://sepolia.basescan.org/address/0x754f1B5fc53B0063E0DA0BfbE85DBb4F284fC7Ac) |
| ReferrerNFT | [`0xA5f4a4830d09f7c95A87d085CB549e0c7583A829`](https://sepolia.basescan.org/address/0xA5f4a4830d09f7c95A87d085CB549e0c7583A829) |
| CompoundingClaimRecipient | [`0xCA155E2e8f25Da2e0aeAE55Aa625459026548818`](https://sepolia.basescan.org/address/0xCA155E2e8f25Da2e0aeAE55Aa625459026548818) |
| UERC20Factory | [`0xfE0661f1E8987935a271761756AA02B04E30d46B`](https://sepolia.basescan.org/address/0xfE0661f1E8987935a271761756AA02B04E30d46B) |
| Deployer | `0xf8543D5b72EF43D0F99b6471424CB2D8dE097324` |

```bash
./scripts/deploy-cca.sh
```
