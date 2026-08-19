// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import {IReferralSource} from "./IReferralSource.sol";

/// @notice Accrues hook fees and pays creator / referrers / platform via claim.
/// @dev Split: 20% creator, 75% referrers (NFT tier weights), 5% platform.
contract FeeDistributor {
    using SafeERC20 for IERC20;

    address public constant PLATFORM = 0xBb6f397d9d8bf128dDa607005397F539B43CD710;
    uint16 public constant CREATOR_BPS = 2_000;
    uint16 public constant REFERRERS_BPS = 7_500;
    uint16 public constant PLATFORM_BPS = 500;
    uint16 public constant BPS_DENOM = 10_000;

    IReferralSource public referrals;
    address public hook;
    address public registrar;

    struct PoolInfo {
        address creator;
        address auction;
        bool registered;
    }

    mapping(PoolId => PoolInfo) public pools;
    mapping(PoolId => mapping(address => uint256)) public creatorOwed;
    mapping(PoolId => mapping(address => uint256)) public platformOwed;
    mapping(PoolId => mapping(address => uint256)) public referrerPool;
    mapping(PoolId => mapping(address => mapping(uint256 => uint256))) public referrerClaimed;

    error NotAuthorized();
    error NotHook();
    error NotRegistered();
    error NothingToClaim();
    error InvalidAmount();
    error TransferFailed();
    error AlreadySet();

    event ReferralsSet(address indexed referrals);
    event HookSet(address indexed hook);
    event RegistrarSet(address indexed registrar);
    event PoolRegistered(PoolId indexed poolId, address indexed auction, address indexed creator);
    event FeeNotified(PoolId indexed poolId, address indexed currency, uint256 amount);
    event Claimed(PoolId indexed poolId, address indexed currency, address indexed to, uint256 amount);

    modifier onlyHook() {
        if (msg.sender != hook) revert NotHook();
        _;
    }

    receive() external payable {}

    function setReferrals(address referrals_) external {
        if (address(referrals) != address(0)) revert AlreadySet();
        if (referrals_ == address(0)) revert InvalidAmount();
        referrals = IReferralSource(referrals_);
        emit ReferralsSet(referrals_);
    }

    function setHook(address hook_) external {
        if (hook != address(0)) revert AlreadySet();
        if (hook_ == address(0)) revert InvalidAmount();
        hook = hook_;
        emit HookSet(hook_);
    }

    function setRegistrar(address registrar_) external {
        if (registrar != address(0)) revert AlreadySet();
        if (registrar_ == address(0)) revert InvalidAmount();
        registrar = registrar_;
        emit RegistrarSet(registrar_);
    }

    function registerPool(PoolId poolId, address auction, address creator) external {
        if (msg.sender != hook && msg.sender != registrar) revert NotAuthorized();
        if (creator == address(0) || auction == address(0)) revert InvalidAmount();
        PoolInfo storage info = pools[poolId];
        if (info.registered) return;
        info.creator = creator;
        info.auction = auction;
        info.registered = true;
        emit PoolRegistered(poolId, auction, creator);
    }

    function notifyFee(PoolId poolId, address currency, uint256 amount) external payable onlyHook {
        if (amount == 0) revert InvalidAmount();
        PoolInfo storage info = pools[poolId];
        if (!info.registered) revert NotRegistered();

        if (currency == address(0)) {
            if (msg.value != amount) revert InvalidAmount();
        } else if (msg.value != 0) {
            revert InvalidAmount();
        }

        uint256 toCreator = (amount * CREATOR_BPS) / BPS_DENOM;
        uint256 toPlatform = (amount * PLATFORM_BPS) / BPS_DENOM;
        uint256 toReferrers = amount - toCreator - toPlatform;

        creatorOwed[poolId][currency] += toCreator;
        platformOwed[poolId][currency] += toPlatform;
        referrerPool[poolId][currency] += toReferrers;

        emit FeeNotified(poolId, currency, amount);
    }

    function claimCreator(PoolId poolId, address currency) external returns (uint256 amount) {
        PoolInfo storage info = pools[poolId];
        if (!info.registered) revert NotRegistered();
        if (msg.sender != info.creator) revert NothingToClaim();

        amount = creatorOwed[poolId][currency];
        if (amount == 0) revert NothingToClaim();
        creatorOwed[poolId][currency] = 0;
        _pay(currency, msg.sender, amount);
        emit Claimed(poolId, currency, msg.sender, amount);
    }

    function claimPlatform(PoolId poolId, address currency) external returns (uint256 amount) {
        if (msg.sender != PLATFORM) revert NothingToClaim();
        if (!pools[poolId].registered) revert NotRegistered();

        amount = platformOwed[poolId][currency];
        if (amount == 0) revert NothingToClaim();
        platformOwed[poolId][currency] = 0;
        _pay(currency, msg.sender, amount);
        emit Claimed(poolId, currency, msg.sender, amount);
    }

    function claimReferrer(PoolId poolId, address currency, uint256 tokenId) external returns (uint256 amount) {
        PoolInfo storage info = pools[poolId];
        if (!info.registered) revert NotRegistered();
        if (referrals.referrerOwner(tokenId) != msg.sender) revert NothingToClaim();

        uint256 total = referrals.totalReferrerWeight(info.auction);
        if (total == 0) revert NothingToClaim();

        uint256 weight = referrals.referrerWeight(tokenId, info.auction);
        if (weight == 0) revert NothingToClaim();

        uint256 entitled = (referrerPool[poolId][currency] * weight) / total;
        uint256 already = referrerClaimed[poolId][currency][tokenId];
        if (entitled <= already) revert NothingToClaim();

        amount = entitled - already;
        referrerClaimed[poolId][currency][tokenId] = entitled;
        _pay(currency, msg.sender, amount);
        emit Claimed(poolId, currency, msg.sender, amount);
    }

    function pendingReferrer(PoolId poolId, address currency, uint256 tokenId) external view returns (uint256) {
        PoolInfo storage info = pools[poolId];
        if (!info.registered) return 0;
        uint256 total = referrals.totalReferrerWeight(info.auction);
        if (total == 0) return 0;
        uint256 weight = referrals.referrerWeight(tokenId, info.auction);
        if (weight == 0) return 0;
        uint256 entitled = (referrerPool[poolId][currency] * weight) / total;
        uint256 already = referrerClaimed[poolId][currency][tokenId];
        return entitled > already ? entitled - already : 0;
    }

    function _pay(address currency, address to, uint256 amount) internal {
        if (currency == address(0)) {
            (bool ok,) = to.call{value: amount}("");
            if (!ok) revert TransferFailed();
        } else {
            IERC20(currency).safeTransfer(to, amount);
        }
    }
}
