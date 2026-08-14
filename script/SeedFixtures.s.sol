// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {IContinuousClearingAuction} from "continuous-clearing-auction/interfaces/IContinuousClearingAuction.sol";
import {FixedPoint96} from "continuous-clearing-auction/libraries/FixedPoint96.sol";
import {ILBPStrategy} from "liquidity-launcher/src/interfaces/ILBPStrategy.sol";
import {ILBPInitializer} from "liquidity-launcher/src/interfaces/ILBPInitializer.sol";

import {CcaLaunchFactory} from "../src/strategy/CcaLaunchFactory.sol";

/// @notice Seeds Anvil with live / ending / failed / graduated auctions.
/// @dev Metadata copied from Base Sepolia launches. Run via scripts/anvil-up.sh
///      so `anvil_mine` happens between steps.
contract SeedFixturesScript is Script {
    using stdJson for string;

    uint256 constant ANVIL_0 =
        0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80;
    uint256 constant ANVIL_1 =
        0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d;

    /// Base Sepolia Punks `0xE8E9…9df2`
    bytes constant PUNKS_EXTRA =
        '{"v":1,"xVerificationToken":"eyJ4X2hhbmRsZSI6InVuZWViYWdoIiwieF91c2VyX2lkIjoiNjk4MzIxNTQiLCJ3YWxsZXRfYWRkcmVzcyI6IjB4QmI2ZjM5N2Q5ZDhiZjEyOGREYTYwNzAwNTM5N0Y1MzlCNDNDRDcxMCIsImlhdCI6MTc4NjY4NjcyM30.r_1dGwgnM-YWHrbYgeh2p_Uu0Pi7PZz_Oun1iYgdHzI"}';
    /// Base Sepolia Prysma `0x800c…d5CC`
    bytes constant PRYSMA_EXTRA =
        '{"v":1,"xVerificationToken":"eyJ4X2hhbmRsZSI6InByeXNtYUhRIiwieF91c2VyX2lkIjoiMTk2MjIwNjM3MDA3MTIyMDIyNCIsIndhbGxldF9hZGRyZXNzIjoiMHhCYjZmMzk3ZDlkOGJmMTI4ZERhNjA3MDA1Mzk3RjUzOUI0M0NENzEwIiwiaWF0IjoxNzg2Njg4NDI2fQ.Ti5hbytmznVwAtuyz9zVRDqfD4xNI6Q7D1hHsSiVS1A"}';
    /// Base Sepolia Virtuoso Club `0x5f3D…59dA`
    bytes constant VIRTUOSO_EXTRA =
        '{"v":1,"xVerificationToken":"eyJ4X2hhbmRsZSI6InZpcnR1b3NvX2NsdWIiLCJ4X3VzZXJfaWQiOiIxNjY0NDU2MjI1MTc2NjcwMjEwIiwid2FsbGV0X2FkZHJlc3MiOiIweEJiNmYzOTdkOWQ4YmYxMjhkRGE2MDcwMDUzOTdGNTM5QjQzQ0Q3MTAiLCJpYXQiOjE3ODY2ODg1NDF9.qDjPf4Ct2HvCZCCMI4KbDgcEA40-eKDVB1MW2x19NDA"}';
    /// Base Sepolia Loot Genie `0xef3F…CF74`
    bytes constant LOOT_EXTRA =
        '{"v":1,"xVerificationToken":"eyJ4X2hhbmRsZSI6Imxvb3RnZW5pZSIsInhfdXNlcl9pZCI6IjE4Mzg5ODgwNjQyMzQwMjA4NjQiLCJ3YWxsZXRfYWRkcmVzcyI6IjB4QmI2ZjM5N2Q5ZDhiZjEyOGREYTYwNzAwNTM5N0Y1MzlCNDNDRDcxMCIsImlhdCI6MTc4NjY4ODU5Mn0.VhNycdzGvWQ6KOm50abfMLUjXjM-Ex_436wj_10pRkU"}';

    function createEnded() public {
        (CcaLaunchFactory factory,, uint256 creatorKey,,) = _load();
        vm.startBroadcast(creatorKey);
        factory.createLaunch(_punksFailed());
        factory.createLaunch(_virtuosoGrad());
        vm.stopBroadcast();
    }

    function bidGrad() public {
        _bid(2, keccak256("grad-invite"), 1 ether);
    }

    function finalizeEnded() public {
        (CcaLaunchFactory factory, ILBPStrategy lbp, uint256 creatorKey,,) = _load();
        address failedAuction = factory.getLaunch(1).auction;
        address gradAuction = factory.getLaunch(2).auction;

        vm.startBroadcast(creatorKey);
        IContinuousClearingAuction(failedAuction).checkpoint();
        IContinuousClearingAuction(gradAuction).checkpoint();
        require(!IContinuousClearingAuction(failedAuction).isGraduated(), "failed graduated");
        require(IContinuousClearingAuction(gradAuction).isGraduated(), "grad not graduated");
        lbp.migrate(ILBPInitializer(gradAuction));
        vm.stopBroadcast();
    }

    function createLive() public {
        (CcaLaunchFactory factory,, uint256 creatorKey,,) = _load();
        vm.startBroadcast(creatorKey);
        factory.createLaunch(_prysmaLive());
        vm.stopBroadcast();
    }

    function bidLive() public {
        _bid(3, keccak256("live-invite"), 0.05 ether);
    }

    function createEnding() public {
        (CcaLaunchFactory factory,, uint256 creatorKey,,) = _load();
        vm.startBroadcast(creatorKey);
        factory.createLaunch(_lootEnding());
        vm.stopBroadcast();
        console2.log("fixtures");
        console2.log("  1 Failed Raise  Punks/PUNKS          invite=failed-invite");
        console2.log("  2 Graduated     Virtuoso Club        invite=grad-invite");
        console2.log("  3 Live Auction  Prysma/PRYSMA        invite=live-invite");
        console2.log("  4 Ending Soon   Loot Genie/LOOT      invite=ending-invite");
    }

    function _bid(uint256 id, bytes32 invite, uint128 amount) internal {
        (CcaLaunchFactory factory,,, uint256 bidderKey, address bidder) = _load();
        address auction = factory.getLaunch(id).auction;
        require(auction != address(0), "no auction");
        vm.startBroadcast(bidderKey);
        IContinuousClearingAuction(auction).submitBid{value: amount}(
            _maxPrice(), amount, bidder, abi.encode(invite)
        );
        vm.stopBroadcast();
    }

    function _load()
        internal
        view
        returns (
            CcaLaunchFactory factory,
            ILBPStrategy lbp,
            uint256 creatorKey,
            uint256 bidderKey,
            address bidder
        )
    {
        creatorKey = vm.envOr("PRIVATE_KEY", ANVIL_0);
        bidderKey = vm.envOr("BIDDER_KEY", ANVIL_1);
        bidder = vm.addr(bidderKey);
        string memory json = vm.readFile("./deployments/anvil-cca.json");
        factory = CcaLaunchFactory(json.readAddress(".cca.factory"));
        lbp = ILBPStrategy(json.readAddress(".cca.lbpStrategy"));
    }

    function _punksFailed() internal pure returns (CcaLaunchFactory.CreateParams memory) {
        return _launch(
            "Punks",
            "PUNKS",
            "Prysma-flavored Punks",
            "ipfs://bafkreigj7zufqtfn3qyzxzysajwkpci5ebhc4xbubeed2vldqojbq5bzza",
            "",
            PUNKS_EXTRA,
            4,
            100 ether,
            keccak256("failed-invite"),
            1
        );
    }

    function _virtuosoGrad() internal pure returns (CcaLaunchFactory.CreateParams memory) {
        return _launch(
            "Virtuoso Club",
            "VIRTUOSO",
            "Experiment for web3 chess",
            "ipfs://bafkreie4fazbsjq6piob4akopxxk22umzjeyc35t3lt4jas3n6b2cklici",
            "https://virtuoso.club/",
            VIRTUOSO_EXTRA,
            4,
            0.001 ether,
            keccak256("grad-invite"),
            2
        );
    }

    function _prysmaLive() internal pure returns (CcaLaunchFactory.CreateParams memory) {
        return _launch(
            "Prysma",
            "PRYSMA",
            "New kind of launchpad",
            "ipfs://bafkreid7qybjikrzndvhonc2rmkkp2gpvm3el5ktmkwp423jb33hasjjb4",
            "https://prysma.trade/",
            PRYSMA_EXTRA,
            10_000,
            1 ether,
            keccak256("live-invite"),
            3
        );
    }

    function _lootEnding() internal pure returns (CcaLaunchFactory.CreateParams memory) {
        return _launch(
            "Loot Genie",
            "LOOT",
            "Gambling onchain",
            "ipfs://bafkreicgeiv2z5suw5yqop22ygfy6gbuq7fhom3lz35h43kel62msajpl4",
            "https://lootgenie.com/",
            LOOT_EXTRA,
            100,
            1 ether,
            keccak256("ending-invite"),
            4
        );
    }

    function _launch(
        string memory name,
        string memory symbol,
        string memory description,
        string memory image,
        string memory website,
        bytes memory extraData,
        uint64 auctionBlocks,
        uint128 minRaise,
        bytes32 inviteCode,
        uint256 saltN
    ) internal pure returns (CcaLaunchFactory.CreateParams memory params) {
        params = CcaLaunchFactory.CreateParams({
            metadata: CcaLaunchFactory.Metadata({
                name: name,
                symbol: symbol,
                description: description,
                image: image,
                website: website,
                extraData: extraData
            }),
            auctionBlocks: auctionBlocks,
            minRaise: minRaise,
            auctionSupplyBps: 5_000,
            salt: bytes32(saltN),
            inviteCode: inviteCode
        });
    }

    function _maxPrice() internal pure returns (uint256) {
        uint256 floor = 1000 << FixedPoint96.RESOLUTION;
        uint256 tickSpacing = 100 << FixedPoint96.RESOLUTION;
        return floor + tickSpacing;
    }
}
