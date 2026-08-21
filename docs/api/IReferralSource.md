# IReferralSource
[Git Source](https://github.com/prysma-labs/launchpad-contracts/blob/3528c3a546aa4da6c3de1ec8f4ab563f3a4a2c69/src/fee/IReferralSource.sol)

Read distributor NFT weights for FeeDistributor claims.


## Functions
### referrerWeight


```
function referrerWeight(uint256 tokenId, address auction) external view returns (uint256);
```

### totalReferrerWeight


```
function totalReferrerWeight(address auction) external view returns (uint256);
```

### referrerOwner


```
function referrerOwner(uint256 tokenId) external view returns (address);
```

