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

import {InitializerHook} from "liquidity-launcher/src/periphery/hooks/InitializerHook.sol";
import {CurrencySettler} from "@openzeppelin/uniswap-hooks/src/utils/CurrencySettler.sol";

import {FeeDistributor} from "./FeeDistributor.sol";

/// @notice LBP-compatible InitializerHook that charges an afterSwap hook fee into FeeDistributor.
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
            beforeSwap: false,
            afterSwap: true,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: false,
            afterSwapReturnDelta: true,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    function _afterSwap(
        address sender,
        PoolKey calldata key,
        SwapParams calldata params,
        BalanceDelta delta,
        bytes calldata
    ) internal override returns (bytes4, int128) {
        (Currency unspecified, int128 unspecifiedAmount) = (params.amountSpecified < 0 == params.zeroForOne)
            ? (key.currency1, delta.amount1())
            : (key.currency0, delta.amount0());

        if (unspecifiedAmount == 0) return (IHooks.afterSwap.selector, 0);
        if (unspecifiedAmount < 0) unspecifiedAmount = -unspecifiedAmount;

        uint24 hookFee = feeConfigured[key.toId()] ? hookFeeOf[key.toId()] : defaultHookFee;
        if (hookFee == 0) return (IHooks.afterSwap.selector, 0);
        if (hookFee > MAX_HOOK_FEE) revert HookFeeTooLarge();

        uint256 feeAmount = FullMath.mulDiv(uint256(uint128(unspecifiedAmount)), hookFee, MAX_HOOK_FEE);
        unspecified.take(poolManager, address(this), feeAmount, true);

        if (unspecified == key.currency0) {
            emit HookFee(PoolId.unwrap(key.toId()), sender, feeAmount.toUint128(), 0);
        } else {
            emit HookFee(PoolId.unwrap(key.toId()), sender, 0, feeAmount.toUint128());
        }

        return (IHooks.afterSwap.selector, feeAmount.toInt128());
    }

    function harvest(PoolKey calldata key) external {
        Currency[] memory currencies = new Currency[](2);
        currencies[0] = key.currency0;
        currencies[1] = key.currency1;
        poolManager.unlock(abi.encode(key.toId(), currencies));
    }

    function unlockCallback(bytes calldata data) external onlyPoolManager returns (bytes memory) {
        (PoolId poolId, Currency[] memory currencies) = abi.decode(data, (PoolId, Currency[]));

        for (uint256 i = 0; i < currencies.length; i++) {
            Currency currency = currencies[i];
            uint256 amount = poolManager.balanceOf(address(this), currency.toId());
            if (amount == 0) continue;

            address currencyAddr = Currency.unwrap(currency);
            currency.settle(poolManager, address(this), amount, true);
            if (currency.isAddressZero()) {
                currency.take(poolManager, address(this), amount, false);
                distributor.notifyFee{value: amount}(poolId, address(0), amount);
            } else {
                currency.take(poolManager, address(distributor), amount, false);
                distributor.notifyFee(poolId, currencyAddr, amount);
            }
        }
        return "";
    }

    receive() external payable {}
}
