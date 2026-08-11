// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice Read referral weights for FeeDistributor claims.
interface IReferralSource {
    function referralCount(address auction, address referrer) external view returns (uint256);
    function totalReferralCount(address auction) external view returns (uint256);
}
