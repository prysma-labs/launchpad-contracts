// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice Read distributor NFT weights for FeeDistributor claims.
interface IReferralSource {
    function referrerWeight(uint256 tokenId) external view returns (uint256);
    function totalReferrerWeight(address auction) external view returns (uint256);
    function referrerAuction(uint256 tokenId) external view returns (address);
    function referrerOwner(uint256 tokenId) external view returns (address);
}
