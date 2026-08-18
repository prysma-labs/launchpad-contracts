// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";

import {IContinuousClearingAuction} from "continuous-clearing-auction/interfaces/IContinuousClearingAuction.sol";
import {ILBPStrategy} from "liquidity-launcher/src/interfaces/ILBPStrategy.sol";
import {ILBPInitializer} from "liquidity-launcher/src/interfaces/ILBPInitializer.sol";

import {CcaLaunchFactory} from "../src/strategy/CcaLaunchFactory.sol";
import {InviteRegistry} from "../src/invite/InviteRegistry.sol";
import {MaxMarketTrader} from "./MaxMarketTrader.sol";

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
    /// Base Sepolia Max Market `0x62bf…aaca` — creator is tester `0x530b…0735`
    bytes constant MAX_EXTRA =
        '{"v":1,"xVerificationToken":"eyJ4X2hhbmRsZSI6Il9tYXh0YWxrcyIsInhfdXNlcl9pZCI6IjE4NzU2MDIyNjMxMTQzODc0NTYiLCJ3YWxsZXRfYWRkcmVzcyI6IjB4NTMwYmY1NjY3NkFmNWJkZjVCMDEwNERiOENEM2Q0NTg4QUE4MDczNSIsImlhdCI6MX0.EVYN2QOJ8wXe5EN7n2DddHcKpS2S0VGIxB8xgjpYIMA","xAvatarUrl":"https://pbs.twimg.com/profile_images/1899943050362970114/bOFt7r-I_bigger.jpg"}';

    uint256 constant ID_MAX = 1;
    uint256 constant ID_PUNKS = 2;
    uint256 constant ID_VIRTUOSO = 3;
    uint256 constant ID_MEGAPOT = 4;
    uint256 constant ID_PRYSMA = 5;

    /// @dev Punks / Virtuoso / Megapot are stamped 1 day ago by anvil-up.sh.
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
        address auction = factory.getLaunch(ID_VIRTUOSO).auction;
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
        address auction = factory.getLaunch(ID_PUNKS).auction;
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
        address auction = factory.getLaunch(ID_MEGAPOT).auction;
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
        address failedAuction = factory.getLaunch(ID_PUNKS).auction;
        address gradAuction = factory.getLaunch(ID_VIRTUOSO).auction;
        address megapotAuction = factory.getLaunch(ID_MEGAPOT).auction;

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

    function finalizeMaxMarket() public {
        (CcaLaunchFactory factory, ILBPStrategy lbp, uint256 creatorKey,,) = _load();
        address maxAuction = factory.getLaunch(ID_MAX).auction;
        vm.startBroadcast(creatorKey);
        IContinuousClearingAuction(maxAuction).checkpoint();
        require(IContinuousClearingAuction(maxAuction).isGraduated(), "max not graduated");
        lbp.migrate(ILBPInitializer(maxAuction));
        vm.stopBroadcast();
    }

    function deployMaxMarketTrader() public {
        (CcaLaunchFactory factory,,, uint256 payerKey,) = _load();
        CcaLaunchFactory.Launch memory launch = factory.getLaunch(ID_MAX);
        require(launch.token != address(0), "no max token");
        string memory json = vm.readFile("./deployments/anvil-cca.json");
        address router = json.readAddress(".cca.swapRouter");
        address feeHook = json.readAddress(".cca.feeHook");

        vm.startBroadcast(payerKey);
        MaxMarketTrader trader = new MaxMarketTrader(router, feeHook);
        trader.init(launch.token, launch.poolLpFee, 60);
        vm.stopBroadcast();
        vm.writeFile("./deployments/anvil-max-trader.txt", vm.toString(address(trader)));
        console2.log("maxMarketTrader", address(trader));
    }

    function createLive() public {
        (CcaLaunchFactory factory,, uint256 creatorKey,,) = _load();
        vm.startBroadcast(creatorKey);
        factory.createLaunch(_prysmaLive());
        vm.stopBroadcast();
    }

    function bidLive() public {
        _bid(ID_PRYSMA, keccak256("prysma"), 0.05 ether);
    }

    /// @dev Stamped 30 days ago by anvil-up.sh. Invite mint is a separate
    ///      broadcast — forge view-calls in the same script still see the
    ///      simulated auction address, not the mined one.
    function createMaxMarket() public {
        (CcaLaunchFactory factory,,,,) = _load();
        vm.startBroadcast(TESTER_1);
        factory.createLaunch(_maxMarketGrad());
        vm.stopBroadcast();
    }

    function seedMaxMarketDistributors() public {
        (CcaLaunchFactory factory,, uint256 operatorKey,,) = _load();
        address auction = factory.getLaunch(ID_MAX).auction;
        require(auction != address(0), "no auction");
        InviteRegistry registry = _registry();
        vm.startBroadcast(operatorKey);
        for (uint256 i = 0; i < 5; i++) {
            bytes32[] memory codes = new bytes32[](1);
            codes[0] = _maxDistInvite(i);
            registry.createInvitesFor(auction, _maxDistIssuer(i), codes);
        }
        vm.stopBroadcast();
    }

    /// @dev 12 owners / 5 distributors, 54.123 ETH total, over the 50 ETH target.
    function bidMaxMarket() public {
        (CcaLaunchFactory factory,, uint256 payerKey,,) = _load();
        address auction = factory.getLaunch(ID_MAX).auction;
        require(auction != address(0), "no auction");

        vm.startBroadcast(payerKey);
        for (uint256 i = 0; i < 12; i++) {
            uint128 amount = _maxBidAmount(i);
            IContinuousClearingAuction(auction).submitBid{value: amount, gas: 2_000_000}(
                _punksMaxPrice(i), amount, _maxDistBidder(i), abi.encode(_maxDistInvite(_maxDistForBidder(i)))
            );
        }
        vm.stopBroadcast();
    }

    function createEnding() public {
        (CcaLaunchFactory factory,, uint256 creatorKey,,) = _load();
        vm.startBroadcast(creatorKey);
        factory.createLaunch(_lootEnding());
        vm.stopBroadcast();
        console2.log("fixtures");
        console2.log("  1 Graduated     Max Market/MAX       54.123 ETH / 12 bids / 5 dists / 30d Token B flow");
        console2.log("  2 Failed Raise  Punks/PUNKS          68.13742 ETH / 57 bids  invite=failed-invite");
        console2.log("  3 Graduated     Virtuoso Club        242.5124 ETH / 25 bids  invite=grad-invite");
        console2.log("  4 Failed Raise  Megapot/MEGAPOT      28.124135 ETH / 13 bids invite=megapot-invite");
        console2.log("  5 Live Auction  Prysma/PRYSMA        invite=prysma");
        console2.log("  6 Ending Soon   Loot Genie/LOOT      invite=ending-invite");
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

    function _registry() internal view returns (InviteRegistry) {
        return InviteRegistry(vm.readFile("./deployments/anvil-cca.json").readAddress(".cca.inviteRegistry"));
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

    function _maxMarketGrad() internal view returns (CcaLaunchFactory.CreateParams memory) {
        return _launch(
            "Max Market",
            "MAX",
            "AI agent with uncanny ability to figure out market trends",
            "ipfs://bafkreidhl63aktbuaosmhiffbgw6wsp3qr3vbmdrikducgvawdiavejrwa",
            "",
            _extra("maxmarket", MAX_EXTRA),
            250,
            50 ether,
            keccak256("max-invite"),
            6
        );
    }

    function _maxDistInvite(uint256 i) internal pure returns (bytes32) {
        if (i == 0) return keccak256("max-dist-1");
        if (i == 1) return keccak256("max-dist-2");
        if (i == 2) return keccak256("max-dist-3");
        if (i == 3) return keccak256("max-dist-4");
        return keccak256("max-dist-5");
    }

    function _maxDistIssuer(uint256 i) internal pure returns (address) {
        return vm.addr(uint256(keccak256(abi.encodePacked("max-dist-issuer", i + 1))));
    }

    function _maxDistBidder(uint256 i) internal pure returns (address) {
        return vm.addr(uint256(keccak256(abi.encodePacked("max-dist-bidder", i + 1))));
    }

    function _maxDistForBidder(uint256 i) internal pure returns (uint256) {
        if (i < 3) return 0;
        if (i < 6) return 1;
        if (i < 8) return 2;
        if (i < 10) return 3;
        return 4;
    }

    function _maxBidAmount(uint256 i) internal pure returns (uint128) {
        if (i == 0) return 10 ether;
        if (i == 1) return 8 ether;
        if (i == 2) return 7 ether;
        if (i == 3) return 4 ether;
        if (i == 4) return 3 ether;
        if (i == 5) return 3 ether;
        if (i == 6) return 5 ether;
        if (i == 7) return 3 ether;
        if (i == 8) return 3.5 ether;
        if (i == 9) return 2.5 ether;
        if (i == 10) return 3 ether;
        return 2.123 ether;
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
