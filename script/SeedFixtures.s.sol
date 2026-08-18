// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {IContinuousClearingAuction} from "continuous-clearing-auction/interfaces/IContinuousClearingAuction.sol";
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
    uint256 constant TESTER_1 =
        0x98eab43565a8e2d51079f1818ef9ce4c0c2f91d4f772768ad81c2fa6a15951ba;
    address constant TESTER_1_ADDR = 0x530bf56676Af5bdf5B0104Db8CD3d4588AA80735;

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
    /// Base Sepolia Megapot `0x27Cb…BB15`
    bytes constant MEGAPOT_EXTRA =
        '{"v":1,"xVerificationToken":"eyJ4X2hhbmRsZSI6InVuZWViYWdoIiwieF91c2VyX2lkIjoiNjk4MzIxNTQiLCJ3YWxsZXRfYWRkcmVzcyI6IjB4QmI2ZjM5N2Q5ZDhiZjEyOGREYTYwNzAwNTM5N0Y1MzlCNDNDRDcxMCIsImlhdCI6MTc4Njc0NzM1OH0.UDAi-cmhR-hHeBNYllYf1sYs9wSHTb4Scr6iXktvz1s","xAvatarUrl":"https://pbs.twimg.com/profile_images/2081802220605980672/2ERTQR1q_bigger.jpg"}';

    /// @dev Punks / Megapot are stamped 1 day ago by anvil-up.sh (`evm_setNextBlockTimestamp`).
    function createEnded() public {
        (CcaLaunchFactory factory,, uint256 creatorKey,,) = _load();
        vm.startBroadcast(creatorKey);
        factory.createLaunch(_punksFailed());
        factory.createLaunch(_virtuosoGrad());
        factory.createLaunch(_megapotFailed());
        vm.stopBroadcast();
    }

    /// @dev 25 owners, 242.5124 ETH total, over the 100 ETH target.
    ///      Tester `0x530b…0735` bids 10 ETH.
    function bidGrad() public {
        (CcaLaunchFactory factory,, uint256 creatorKey,,) = _load();
        address auction = factory.getLaunch(2).auction;
        require(auction != address(0), "no auction");
        bytes32 invite = keccak256("grad-invite");

        vm.startBroadcast(creatorKey);
        for (uint256 i = 0; i < 24; i++) {
            address bidder = vm.addr(uint256(keccak256(abi.encodePacked("virtuoso-bidder", i + 1))));
            uint128 amount = _virtuosoBidAmount(i);
            IContinuousClearingAuction(auction).submitBid{value: amount, gas: 2_000_000}(
                _punksMaxPrice(i), amount, bidder, abi.encode(invite)
            );
        }
        vm.stopBroadcast();

        vm.startBroadcast(TESTER_1);
        IContinuousClearingAuction(auction).submitBid{value: 10 ether, gas: 2_000_000}(
            _maxPrice(), 10 ether, TESTER_1_ADDR, abi.encode(invite)
        );
        vm.stopBroadcast();
    }

    /// @dev 57 owners, 68.13742 ETH total, under the 100 ETH target.
    function bidFailed() public {
        (CcaLaunchFactory factory,, uint256 creatorKey,,) = _load();
        address auction = factory.getLaunch(1).auction;
        require(auction != address(0), "no auction");
        bytes32 invite = keccak256("failed-invite");

        vm.startBroadcast(creatorKey);
        for (uint256 i = 0; i < 57; i++) {
            address bidder = vm.addr(uint256(keccak256(abi.encodePacked("punks-bidder", i + 1))));
            uint128 amount = _punksBidAmount(i);
            IContinuousClearingAuction(auction).submitBid{value: amount, gas: 2_000_000}(
                _punksMaxPrice(i), amount, bidder, abi.encode(invite)
            );
        }
        vm.stopBroadcast();
    }

    /// @dev 13 owners, 28.124135 ETH total, under the 50 ETH target.
    ///      Tester `0x530b…0735` bids 0.4 ETH so the UI refund path can be exercised.
    function bidMegapot() public {
        (CcaLaunchFactory factory,, uint256 creatorKey,,) = _load();
        address auction = factory.getLaunch(3).auction;
        require(auction != address(0), "no auction");
        bytes32 invite = keccak256("megapot-invite");

        vm.startBroadcast(creatorKey);
        for (uint256 i = 0; i < 12; i++) {
            address bidder = vm.addr(uint256(keccak256(abi.encodePacked("megapot-bidder", i + 1))));
            uint128 amount = _megapotBidAmount(i);
            IContinuousClearingAuction(auction).submitBid{value: amount, gas: 2_000_000}(
                _punksMaxPrice(i), amount, bidder, abi.encode(invite)
            );
        }
        vm.stopBroadcast();

        vm.startBroadcast(TESTER_1);
        IContinuousClearingAuction(auction).submitBid{value: 0.4 ether, gas: 2_000_000}(
            _maxPrice(), 0.4 ether, TESTER_1_ADDR, abi.encode(invite)
        );
        vm.stopBroadcast();
    }

    function finalizeEnded() public {
        (CcaLaunchFactory factory, ILBPStrategy lbp, uint256 creatorKey,,) = _load();
        address failedAuction = factory.getLaunch(1).auction;
        address gradAuction = factory.getLaunch(2).auction;
        address megapotAuction = factory.getLaunch(3).auction;

        vm.startBroadcast(creatorKey);
        IContinuousClearingAuction(failedAuction).checkpoint();
        IContinuousClearingAuction(gradAuction).checkpoint();
        IContinuousClearingAuction(megapotAuction).checkpoint();
        require(!IContinuousClearingAuction(failedAuction).isGraduated(), "failed graduated");
        require(IContinuousClearingAuction(gradAuction).isGraduated(), "grad not graduated");
        require(!IContinuousClearingAuction(megapotAuction).isGraduated(), "megapot graduated");
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
        _bid(4, keccak256("prysma"), 0.05 ether);
    }

    function createEnding() public {
        (CcaLaunchFactory factory,, uint256 creatorKey,,) = _load();
        vm.startBroadcast(creatorKey);
        factory.createLaunch(_lootEnding());
        vm.stopBroadcast();
        console2.log("fixtures");
        console2.log("  1 Failed Raise  Punks/PUNKS          68.13742 ETH / 57 bids  invite=failed-invite");
        console2.log("  2 Graduated     Virtuoso Club        242.5124 ETH / 25 bids  invite=grad-invite");
        console2.log("  3 Failed Raise  Megapot/MEGAPOT      28.124135 ETH / 13 bids invite=megapot-invite");
        console2.log("  4 Live Auction  Prysma/PRYSMA        invite=prysma");
        console2.log("  5 Ending Soon   Loot Genie/LOOT      invite=ending-invite");
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

    function _extra(string memory key, bytes memory fallbackExtra)
        internal
        view
        returns (bytes memory)
    {
        string memory path = "./deployments/anvil-x-extras.json";
        if (vm.exists(path)) {
            return bytes(vm.readFile(path).readString(string.concat(".", key)));
        }
        return fallbackExtra;
    }

    function _punksFailed() internal view returns (CcaLaunchFactory.CreateParams memory) {
        return _launch(
            "Punks",
            "PUNKS",
            "Prysma-flavored Punks",
            "ipfs://bafkreigj7zufqtfn3qyzxzysajwkpci5ebhc4xbubeed2vldqojbq5bzza",
            "",
            _extra("punks", PUNKS_EXTRA),
            250,
            100 ether,
            keccak256("failed-invite"),
            1
        );
    }

    function _megapotFailed() internal view returns (CcaLaunchFactory.CreateParams memory) {
        return _launch(
            "Megapot",
            "MEGAPOT",
            "Onchain lottery that grows over time",
            "ipfs://bafkreidfv2t4bp7qtl2oa5c53dzmgflubsrecldtzptwanh7ld2vmy5l5a",
            "https://megapot.io/",
            _extra("megapot", MEGAPOT_EXTRA),
            250,
            50 ether,
            keccak256("megapot-invite"),
            5
        );
    }

    function _virtuosoGrad() internal view returns (CcaLaunchFactory.CreateParams memory) {
        return _launch(
            "Virtuoso Club",
            "VIRTUOSO",
            "Experiment for web3 chess",
            "ipfs://bafkreie4fazbsjq6piob4akopxxk22umzjeyc35t3lt4jas3n6b2cklici",
            "https://virtuoso.club/",
            _extra("virtuoso", VIRTUOSO_EXTRA),
            250,
            100 ether,
            keccak256("grad-invite"),
            2
        );
    }

    function _prysmaLive() internal view returns (CcaLaunchFactory.CreateParams memory) {
        return _launch(
            "Prysma",
            "PRYSMA",
            "New kind of launchpad",
            "ipfs://bafkreid7qybjikrzndvhonc2rmkkp2gpvm3el5ktmkwp423jb33hasjjb4",
            "https://prysma.trade/",
            _extra("prysma", PRYSMA_EXTRA),
            10_000,
            100 ether,
            keccak256("prysma"),
            3
        );
    }

    function _lootEnding() internal view returns (CcaLaunchFactory.CreateParams memory) {
        return _launch(
            "Loot Genie",
            "LOOT",
            "Gambling onchain",
            "ipfs://bafkreicgeiv2z5suw5yqop22ygfy6gbuq7fhom3lz35h43kel62msajpl4",
            "https://lootgenie.com/",
            _extra("loot", LOOT_EXTRA),
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

    uint256 constant BID_TICKS_ABOVE_FLOOR = 1_000_000;
    uint256 constant FLOOR_PRICE = 0x2405bc873c7bfab5c;
    uint256 constant TICK_SPACING_Q96 = 0x05c37a5313eae06f;

    function _punksMaxPrice(uint256 i) internal pure returns (uint256) {
        return FLOOR_PRICE + TICK_SPACING_Q96 * (BID_TICKS_ABOVE_FLOOR + i);
    }

    function _punksBidAmount(uint256 i) internal pure returns (uint128) {
        if (i < 12) return 0.25 ether;
        if (i < 24) return 0.5 ether;
        if (i < 36) return 1 ether;
        if (i < 46) return 1.5 ether;
        if (i < 52) return 2 ether;
        if (i < 55) return 3 ether;
        if (i == 55) return 5 ether;
        return 6.13742 ether;
    }

    function _virtuosoBidAmount(uint256 i) internal pure returns (uint128) {
        if (i < 6) return 5 ether;
        if (i < 12) return 8 ether;
        if (i < 17) return 10 ether;
        if (i < 21) return 15 ether;
        if (i < 23) return 20 ether;
        return 4.5124 ether;
    }

    function _megapotBidAmount(uint256 i) internal pure returns (uint128) {
        if (i < 4) return 1.5 ether;
        if (i < 8) return 2 ether;
        if (i < 11) return 3 ether;
        return 4.724135 ether;
    }

    function _maxPrice() internal pure returns (uint256) {
        return FLOOR_PRICE + TICK_SPACING_Q96 * BID_TICKS_ABOVE_FLOOR;
    }
}
