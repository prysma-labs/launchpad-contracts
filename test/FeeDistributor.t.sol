// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PoolId} from "@uniswap/v4-core/src/types/PoolId.sol";

import {FeeDistributor} from "../src/fee/FeeDistributor.sol";

contract FeeDistributorTest is Test {
    FeeDistributor distributor;
    address hook = makeAddr("hook");
    address registrar = makeAddr("registrar");
    address creator = makeAddr("creator");
    address auction = makeAddr("auction");
    PoolId poolId = PoolId.wrap(bytes32(uint256(1)));

    function setUp() public {
        distributor = new FeeDistributor();
        distributor.setHook(hook);
        distributor.setRegistrar(registrar);

        vm.prank(registrar);
        distributor.registerPool(poolId, auction, creator);
    }

    function test_notifyAndClaim_split() public {
        vm.deal(hook, 10 ether);
        vm.prank(hook);
        distributor.notifyFee{value: 10 ether}(poolId, address(0), 10 ether);

        vm.prank(creator);
        uint256 c = distributor.claimCreator(poolId, address(0));
        assertEq(c, 9.5 ether);

        address platform = distributor.PLATFORM();
        vm.prank(platform);
        uint256 p = distributor.claimPlatform(poolId, address(0));
        assertEq(p, 0.5 ether);
    }
}
