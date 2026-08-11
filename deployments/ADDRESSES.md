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

### CCA launchpad (start block `45321260`)

| Contract | Address |
|---|---|
| CcaLaunchFactory | [`0x4e9E19F019e5C9f1bDF5bEA8F449AF1947Dc6982`](https://sepolia.basescan.org/address/0x4e9E19F019e5C9f1bDF5bEA8F449AF1947Dc6982) |
| LBPStrategy | [`0x877A69aC75Ae3fe1ca4bdCdBA02c0e424e886000`](https://sepolia.basescan.org/address/0x877A69aC75Ae3fe1ca4bdCdBA02c0e424e886000) |
| ContinuousClearingAuctionFactory | [`0xFD7D3B0865c2eEe3E1eDE156b584f07e53138229`](https://sepolia.basescan.org/address/0xFD7D3B0865c2eEe3E1eDE156b584f07e53138229) |
| LaunchFeeHook | [`0x8BE7748Bfa399A4771db7bC619bE5e492bd8e044`](https://sepolia.basescan.org/address/0x8BE7748Bfa399A4771db7bC619bE5e492bd8e044) |
| FeeDistributor | [`0x7B59E019eFF830DC4A82D647cA8Fe355Fc6FC3FD`](https://sepolia.basescan.org/address/0x7B59E019eFF830DC4A82D647cA8Fe355Fc6FC3FD) |
| InviteRegistry | [`0x1295C3A28b6251aB2C07C1EE3D0bf58d3b95a876`](https://sepolia.basescan.org/address/0x1295C3A28b6251aB2C07C1EE3D0bf58d3b95a876) |
| InviteValidationHook | [`0x4F63F3d49a5e342f5541265339294C923421173f`](https://sepolia.basescan.org/address/0x4F63F3d49a5e342f5541265339294C923421173f) |
| CompoundingClaimRecipient | [`0xd7dfF278E3cD79a4C8AC0aA708e53253e174A99a`](https://sepolia.basescan.org/address/0xd7dfF278E3cD79a4C8AC0aA708e53253e174A99a) |
| Deployer | `0x4D529f34198c6aAFc63e9fA5f34d2d95eFa1e11b` |

```bash
cd contracts
source .env
./scripts/deploy-cca.sh
```
