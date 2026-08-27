# IReferralSource
[Git Source](https://github.com/prysma-labs/launchpad-contracts/blob/5581699504b49b43ecb36ba097021e1d689dd2d0/src/fee/IReferralSource.sol)

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

