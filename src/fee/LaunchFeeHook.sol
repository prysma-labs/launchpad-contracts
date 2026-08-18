// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IUnlockCallback} from "@uniswap/v4-core/src/interfaces/callback/IUnlockCallback.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency, CurrencyLibrary} from "@uniswap/v4-core/src/types/Currency.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {SwapParams} from "@uniswap/v4-core/src/types/PoolOperation.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {SafeCast} from "@uniswap/v4-core/src/libraries/SafeCast.sol";
import {FullMath} from "@uniswap/v4-core/src/libraries/FullMath.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {BeforeSwapDelta, toBeforeSwapDelta} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";

import {InitializerHook} from "liquidity-launcher/src/periphery/hooks/InitializerHook.sol";
import {CurrencySettler} from "@openzeppelin/uniswap-hooks/src/utils/CurrencySettler.sol";

import {FeeDistributor} from "./FeeDistributor.sol";

/// @notice LBP-compatible InitializerHook that charges a hook fee in ETH into FeeDistributor.
/// @dev ETH is always currency0. Buys take 0.4% of specified ETH in beforeSwap; sells take 0.4% of
///      unspecified ETH out in afterSwap. Token fees are never taken.
contract LaunchFeeHook is InitializerHook, IUnlockCallback {
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;
    using CurrencySettler for Currency;
    using SafeCast for uint256;
    using SafeCast for int128;

    uint24 internal constant MAX_HOOK_FEE = 1e6;

    FeeDistributor public immutable distributor;
    uint24 public immutable defaultHookFee;

    mapping(PoolId => uint24) public hookFeeOf;
    mapping(PoolId => bool) public feeConfigured;

    error InvalidFee();
    error HookFeeTooLarge();

    event PoolHookFeeSet(PoolId indexed poolId, uint24 fee);
    event HookFee(bytes32 indexed poolId, address indexed sender, uint128 feeAmount0, uint128 feeAmount1);

    constructor(
        IPoolManager poolManager_,
        address authorized_,
        FeeDistributor distributor_,
        uint24 defaultHookFee_
    ) InitializerHook(poolManager_, authorized_) {
        if (defaultHookFee_ > MAX_HOOK_FEE) revert InvalidFee();
        if (address(distributor_) == address(0)) revert InvalidFee();
        distributor = distributor_;
        defaultHookFee = defaultHookFee_;
    }

    function setPoolHookFee(PoolId poolId, uint24 fee) external {
        if (msg.sender != authorized) revert InvalidFee();
        if (fee > MAX_HOOK_FEE) revert InvalidFee();
        hookFeeOf[poolId] = fee;
        feeConfigured[poolId] = true;
        emit PoolHookFeeSet(poolId, fee);
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: true,
            afterInitialize: false,
            beforeAddLiquidity: false,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: true,
            afterSwapReturnDelta: true,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    /// @dev When ETH is specified (exact-in buy / exact-out sell), take 0.4% of that ETH.
    function _beforeSwap(address sender, PoolKey calldata key, SwapParams calldata params, bytes calldata)
        internal
        override
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        if (!_ethIsSpecified(key, params)) {
            return (IHooks.beforeSwap.selector, toBeforeSwapDelta(0, 0), 0);
        }

        uint256 specifiedAbs =
            params.amountSpecified < 0 ? uint256(-params.amountSpecified) : uint256(params.amountSpecified);
        uint256 feeAmount = _ethFee(key.toId(), specifiedAbs);
        if (feeAmount == 0) return (IHooks.beforeSwap.selector, toBeforeSwapDelta(0, 0), 0);

        key.currency0.take(poolManager, address(this), feeAmount, true);
        emit HookFee(PoolId.unwrap(key.toId()), sender, feeAmount.toUint128(), 0);
        return (IHooks.beforeSwap.selector, toBeforeSwapDelta(feeAmount.toInt128(), 0), 0);
    }

    /// @dev When ETH is unspecified (exact-in sell / exact-out buy), take 0.4% of ETH out/in.
    function _afterSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata
    ) internal override returns (bytes4, int128) {
        if (_ethIsSpecified(key, params)) return (IHooks.afterSwap.selector, 0);

        int128 ethAmount = delta.amount0();
        if (ethAmount == 0) return (IHooks.afterSwap.selector, 0);
        if (ethAmount < 0) ethAmount = -ethAmount;

        uint256 feeAmount = _ethFee(key.toId(), uint256(uint128(ethAmount)));
        if (feeAmount == 0) return (IHooks.afterSwap.selector, 0);

        key.currency0.take(poolManager, address(this), feeAmount, true);
        emit HookFee(PoolId.unwrap(key.toId()), sender, feeAmount.toUint128(), 0);
        return (IHooks.afterSwap.selector, feeAmount.toInt128());
    }

    function harvest(PoolKey calldata key) external {
        Currency[] memory currencies = new Currency[](1);
        currencies[0] = key.currency0;
        poolManager.unlock(abi.encode(key.toId(), currencies));
    }

    function unlockCallback(bytes calldata data) external onlyPoolManager returns (bytes memory) {
        (PoolId poolId, Currency[] memory currencies) = abi.decode(data, (PoolId, Currency[]));

        for (uint256 i = 0; i < currencies.length; i++) {
            Currency currency = currencies[i];
            uint256 amount = poolManager.balanceOf(address(this), currency.toId());
            if (amount == 0) continue;

            currency.settle(poolManager, address(this), amount, true);
            if (!currency.isAddressZero()) revert InvalidFee();
            currency.take(poolManager, address(this), amount, false);
            distributor.notifyFee{value: amount}(poolId, address(0), amount);
        }
        return "";
    }

    /// @dev Specified currency is currency0 when (amountSpecified < 0) == zeroForOne.
    function _ethIsSpecified(PoolKey calldata key, SwapParams calldata params) internal pure returns (bool) {
        if (!key.currency0.isAddressZero()) return false;
        return params.amountSpecified < 0 == params.zeroForOne;
    }

    function _ethFee(PoolId poolId, uint256 ethAmount) internal view returns (uint256) {
        uint24 hookFee = feeConfigured[poolId] ? hookFeeOf[poolId] : defaultHookFee;
        if (hookFee == 0) return 0;
        if (hookFee > MAX_HOOK_FEE) revert HookFeeTooLarge();
        return FullMath.mulDiv(ethAmount, hookFee, MAX_HOOK_FEE);
    }

    receive() external payable {}
}
