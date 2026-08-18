// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IUniswapV4Router04} from "hookmate/interfaces/router/IUniswapV4Router04.sol";

import {LaunchFeeHook} from "../src/fee/LaunchFeeHook.sol";

/// @notice Token B-shaped MAX spot flow: 1800 ETH/day * 0.85^day, floor 40, 50/50 buy/sell.
/// @dev A 54 ETH pool cannot take 900 ETH one-way, so each day is buy/sell round-trips
///      of CHUNK, capped at MAX_RTS (120 ETH notional / day).
contract MaxMarketTrader {
    uint256 public constant TOKEN_B_START = 1800 ether;
    uint256 public constant TOKEN_B_FLOOR = 40 ether;
    uint256 public constant DECAY_NUM = 85;
    uint256 public constant DECAY_DEN = 100;
    uint256 public constant CHUNK = 2 ether;
    uint256 public constant MAX_RTS = 30;

    IUniswapV4Router04 public immutable router;
    LaunchFeeHook public immutable hook;

    address public token;
    uint24 public fee;
    int24 public tickSpacing;

    error NotInit();
    error Underfunded();
    error RefundFailed();

    constructor(address router_, address hook_) {
        router = IUniswapV4Router04(payable(router_));
        hook = LaunchFeeHook(payable(hook_));
    }

    receive() external payable {}

    function init(address token_, uint24 fee_, int24 tickSpacing_) external {
        token = token_;
        fee = fee_;
        tickSpacing = tickSpacing_;
        IERC20(token_).approve(address(router), type(uint256).max);
    }

    function dayVolumeWei(uint256 day) public pure returns (uint256 vol) {
        vol = TOKEN_B_START;
        for (uint256 i = 0; i < day; i++) {
            vol = (vol * DECAY_NUM) / DECAY_DEN;
        }
        if (vol < TOKEN_B_FLOOR) vol = TOKEN_B_FLOOR;
    }

    function dayBuyWei(uint256 day) public pure returns (uint256 buy) {
        buy = dayVolumeWei(day) / 2;
        uint256 cap = CHUNK * MAX_RTS;
        if (buy > cap) buy = cap;
    }

    function runDay(uint256 day) external payable {
        if (token == address(0)) revert NotInit();
        uint256 buyEth = dayBuyWei(day);
        if (msg.value < buyEth) revert Underfunded();

        PoolKey memory key = _key();
        uint256 remaining = buyEth;
        while (remaining > 0) {
            uint256 amt = remaining > CHUNK ? CHUNK : remaining;
            router.swapExactTokensForTokens{value: amt}(
                amt, 0, true, key, "", address(this), block.timestamp + 60
            );
            uint256 bal = IERC20(token).balanceOf(address(this));
            if (bal > 0) {
                router.swapExactTokensForTokens(bal, 0, false, key, "", address(this), block.timestamp + 60);
            }
            remaining -= amt;
        }
        hook.harvest(key);

        uint256 leftover = address(this).balance;
        if (leftover > 0) {
            (bool ok,) = payable(msg.sender).call{value: leftover}("");
            if (!ok) revert RefundFailed();
        }
    }

    function _key() internal view returns (PoolKey memory) {
        return PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(token),
            fee: fee,
            tickSpacing: tickSpacing,
            hooks: IHooks(address(hook))
        });
    }
}
