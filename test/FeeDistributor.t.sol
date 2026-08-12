// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Test} from "forge-std/Test.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";

import {FeeDistributor} from "../src/fee/FeeDistributor.sol";
import {IReferralSource} from "../src/fee/IReferralSource.sol";

contract MockReferrals is IReferralSource {
    mapping(address => mapping(address => uint256)) public volumes;
    mapping(address => uint256) public totals;

    function set(address auction, address referrer, uint256 volume) external {
        totals[auction] = totals[auction] - volumes[auction][referrer] + volume;
        volumes[auction][referrer] = volume;
    }

    function referralVolume(address auction, address referrer) external view returns (uint256) {
        return volumes[auction][referrer];
    }

    function totalReferralVolume(address auction) external view returns (uint256) {
        return totals[auction];
    }
}

contract FeeDistributorTest is Test {
    FeeDistributor distributor;
    MockReferrals referrals;
    address hook = makeAddr("hook");
    address registrar = makeAddr("registrar");
    address creator = makeAddr("creator");
    address referrer = makeAddr("referrer");
    address referrerBig = makeAddr("referrerBig");
    address auction = makeAddr("auction");
    PoolId poolId = PoolId.wrap(bytes32(uint256(1)));

    function setUp() public {
        distributor = new FeeDistributor();
        referrals = new MockReferrals();
        distributor.setReferrals(address(referrals));
        distributor.setHook(hook);
        distributor.setRegistrar(registrar);

        vm.prank(registrar);
        distributor.registerPool(poolId, auction, creator);
        referrals.set(auction, referrer, 1 ether);
    }

    function test_notifyAndClaim_split() public {
        vm.deal(hook, 10 ether);
        vm.prank(hook);
        distributor.notifyFee{value: 10 ether}(poolId, address(0), 10 ether);

        // 20% creator, 5% platform, 75% referrers
        vm.prank(creator);
        uint256 c = distributor.claimCreator(poolId, address(0));
        assertEq(c, 2 ether);

        address platform = distributor.PLATFORM();
        vm.prank(platform);
        uint256 p = distributor.claimPlatform(poolId, address(0));
        assertEq(p, 0.5 ether);

        vm.prank(referrer);
        uint256 r = distributor.claimReferrer(poolId, address(0));
        assertEq(r, 7.5 ether);
    }

    function test_claimReferrer_proRataByVolume() public {
        referrals.set(auction, referrer, 1 ether);
        referrals.set(auction, referrerBig, 100 ether);

        vm.deal(hook, 10.1 ether);
        vm.prank(hook);
        distributor.notifyFee{value: 10.1 ether}(poolId, address(0), 10.1 ether);

        uint256 referrerPool = (10.1 ether * 7_500) / 10_000;
        vm.prank(referrerBig);
        uint256 big = distributor.claimReferrer(poolId, address(0));
        assertEq(big, (referrerPool * 100) / 101);

        vm.prank(referrer);
        uint256 small = distributor.claimReferrer(poolId, address(0));
        assertEq(small, referrerPool - big);
    }
}
