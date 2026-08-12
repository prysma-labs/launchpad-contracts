// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

/// @notice Read referral weights for FeeDistributor claims.
interface IReferralSource {
    /// @notice Bid currency volume attributed to `referrer` for `auction`.
    function referralVolume(address auction, address referrer) external view returns (uint256);

    /// @notice Total attributed bid currency volume for `auction`.
    function totalReferralVolume(address auction) external view returns (uint256);
}
