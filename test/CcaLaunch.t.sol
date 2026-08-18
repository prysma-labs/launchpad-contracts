// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "@uniswap/v4-periphery/src/utils/HookMiner.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import {LiquidityLauncher} from "liquidity-launcher/src/LiquidityLauncher.sol";
import {LBPStrategy} from "liquidity-launcher/src/strategies/lbp/LBPStrategy.sol";
import {IDistributorFactory} from "liquidity-launcher/src/interfaces/IDistributorFactory.sol";
import {ILiquidityLauncher} from "liquidity-launcher/src/interfaces/ILiquidityLauncher.sol";
import {ILBPStrategy} from "liquidity-launcher/src/interfaces/ILBPStrategy.sol";
import {ILBPInitializer} from "liquidity-launcher/src/interfaces/ILBPInitializer.sol";
import {ContinuousClearingAuctionFactory} from "continuous-clearing-auction/ContinuousClearingAuctionFactory.sol";
import {IContinuousClearingAuction} from "continuous-clearing-auction/interfaces/IContinuousClearingAuction.sol";
import {UERC20Factory} from "@uniswap/uerc20-factory/src/factories/UERC20Factory.sol";
import {BaseUERC20} from "@uniswap/uerc20-factory/src/tokens/BaseUERC20.sol";

import {BaseTest} from "./utils/BaseTest.sol";
import {FeeDistributor} from "../src/fee/FeeDistributor.sol";
import {LaunchFeeHook} from "../src/fee/LaunchFeeHook.sol";
import {InviteRegistry} from "../src/invite/InviteRegistry.sol";
import {InviteValidationHook} from "../src/invite/InviteValidationHook.sol";
import {ReferrerNFT} from "../src/nft/ReferrerNFT.sol";
import {CcaLaunchFactory} from "../src/strategy/CcaLaunchFactory.sol";

contract CcaLaunchTest is BaseTest {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    uint24 constant HOOK_FEE = 4_000;
    uint64 constant AUCTION_BLOCKS = 10; // 1e7 % 10 == 0
    uint256 constant BID_TICKS_ABOVE_FLOOR = 1_000_000;
    uint256 constant FLOOR_PRICE = 0x2405bc873c7bfab5c;
    uint256 constant TICK_SPACING_Q96 = 0x05c37a5313eae06f;

    LiquidityLauncher launcher;
    ContinuousClearingAuctionFactory ccaFactory;
    LBPStrategy lbp;
    FeeDistributor distributor;
    InviteRegistry registry;
    ReferrerNFT referrerNft;
    InviteValidationHook inviteHook;
    LaunchFeeHook feeHook;
    UERC20Factory uerc20Factory;
    CcaLaunchFactory factory;

    address creator = makeAddr("creator");
    address bidder = makeAddr("bidder");
    address stranger = makeAddr("stranger");
    uint256 operatorKey = 0xA11CE;
    address operator = vm.addr(operatorKey);

    bytes32 inviteCode = keccak256("invite-1");
    bytes constant X_EXTRA =
        '{"v":1,"xVerificationToken":"eyJ4X2hhbmRsZSI6InRlc3QifQ.sig"}';

    function setUp() public {
        deployArtifactsAndLabel();

        launcher = new LiquidityLauncher(IAllowanceTransfer(address(permit2)));
        ccaFactory = new ContinuousClearingAuctionFactory(address(0));
        uerc20Factory = new UERC20Factory();

        bytes memory lbpArgs = abi.encode(address(positionManager), address(poolManager), address(ccaFactory));
        (address lbpAddr, bytes32 lbpSalt) =
            HookMiner.find(address(this), Hooks.BEFORE_INITIALIZE_FLAG, type(LBPStrategy).creationCode, lbpArgs);
        lbp = new LBPStrategy{salt: lbpSalt}(
            positionManager, poolManager, IDistributorFactory(address(ccaFactory))
        );
        assertEq(address(lbp), lbpAddr);

        distributor = new FeeDistributor();
        registry = new InviteRegistry();
        referrerNft = new ReferrerNFT("https://launchpad.test/api/nft/");
        referrerNft.setRegistry(address(registry));
        registry.setReferrerNft(address(referrerNft));
        inviteHook = new InviteValidationHook(registry);
        registry.setValidationHook(address(inviteHook));

        bytes memory hookArgs = abi.encode(address(poolManager), address(lbp), address(distributor), HOOK_FEE);
        uint160 flags = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
                | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG
        );
        (address hookAddr, bytes32 salt) =
            HookMiner.find(address(this), flags, type(LaunchFeeHook).creationCode, hookArgs);
        feeHook = new LaunchFeeHook{salt: salt}(poolManager, address(lbp), distributor, HOOK_FEE);
        assertEq(address(feeHook), hookAddr);

        distributor.setReferrals(address(referrerNft));
        distributor.setHook(address(feeHook));

        factory = new CcaLaunchFactory(
            ILiquidityLauncher(address(launcher)),
            ILBPStrategy(address(lbp)),
            IDistributorFactory(address(ccaFactory)),
            registry,
            distributor,
            feeHook,
            address(this),
            address(uerc20Factory)
        );
        registry.setFactory(address(factory));
        registry.setOperator(operator);
        distributor.setRegistrar(address(factory));

        vm.deal(bidder, 1000 ether);
        vm.deal(stranger, 100 ether);
        vm.deal(creator, 1 ether);
        vm.deal(address(this), 100 ether);
    }

    function test_createLaunch_registersAuctionAndOpensCca() public {
        (uint256 launchId, address token, address auction) = _create(1 ether);

        CcaLaunchFactory.Launch memory launch = factory.getLaunch(launchId);
        assertEq(launch.creator, creator);
        assertEq(launch.token, token);
        assertEq(launch.auction, auction);
        assertEq(launch.poolLpFee, 1_000);
        assertEq(launch.hookFee, HOOK_FEE);
        assertEq(registry.creatorOf(auction), creator);
        assertEq(registry.inviteIssuer(auction, inviteCode), creator);
        assertEq(address(IContinuousClearingAuction(auction).validationHook()), address(inviteHook));
        assertEq(IContinuousClearingAuction(auction).fundsRecipient(), address(lbp));
        assertEq(
            IContinuousClearingAuction(auction).tokensRecipient(),
            0x000000000000000000000000000000000000dEaD
        );
        assertEq(launch.claimBlock, launch.endBlock);

        (,,, bytes memory extraData) = BaseUERC20(token).metadata();
        assertEq(extraData, X_EXTRA);
    }

    function test_operatorCanCreateInvitesFor() public {
        (,, address auction) = _create(1 ether);
        bytes32 extra = keccak256("invite-2");
        bytes32[] memory extraCodes = new bytes32[](1);
        extraCodes[0] = extra;

        vm.prank(stranger);
        vm.expectRevert(InviteRegistry.NotAuthorized.selector);
        registry.createInvitesFor(auction, stranger, extraCodes);

        vm.prank(operator);
        registry.createInvitesFor(auction, stranger, extraCodes);
        assertEq(registry.inviteIssuer(auction, extra), stranger);
    }

    function test_createInvites_requiresOperatorSignature() public {
        (,, address auction) = _create(1 ether);
        bytes32[] memory codes = new bytes32[](1);
        codes[0] = keccak256("signed-invite");
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _signCreateInvites(auction, stranger, codes, 0, deadline);

        vm.prank(stranger);
        registry.createInvites(auction, codes, deadline, sig);
        assertEq(registry.inviteIssuer(auction, codes[0]), stranger);
        assertEq(registry.nonces(stranger), 1);
    }

    function test_createInvites_rejectsBadSignature() public {
        (,, address auction) = _create(1 ether);
        bytes32[] memory codes = new bytes32[](1);
        codes[0] = keccak256("signed-invite");
        uint256 deadline = block.timestamp + 1 hours;
        bytes memory sig = _signCreateInvites(auction, bidder, codes, 0, deadline);

        vm.prank(stranger);
        vm.expectRevert(InviteRegistry.InvalidSignature.selector);
        registry.createInvites(auction, codes, deadline, sig);
    }

    function test_createLaunch_revertsWithoutXVerification() public {
        CcaLaunchFactory.CreateParams memory params = CcaLaunchFactory.CreateParams({
            metadata: CcaLaunchFactory.Metadata({
                name: "Test",
                symbol: "TST",
                description: "d",
                image: "",
                website: "",
                extraData: ""
            }),
            auctionBlocks: AUCTION_BLOCKS,
            minRaise: 1 ether,
            auctionSupplyBps: 5_000,
            salt: bytes32(uint256(2)),
            inviteCode: inviteCode
        });

        vm.prank(creator);
        vm.expectRevert(CcaLaunchFactory.NeedXVerification.selector);
        factory.createLaunch(params);
    }

    function test_createLaunch_revertsWithoutInvite() public {
        CcaLaunchFactory.CreateParams memory params = CcaLaunchFactory.CreateParams({
            metadata: CcaLaunchFactory.Metadata({
                name: "Test",
                symbol: "TST",
                description: "d",
                image: "",
                website: "",
                extraData: X_EXTRA
            }),
            auctionBlocks: AUCTION_BLOCKS,
            minRaise: 1 ether,
            auctionSupplyBps: 5_000,
            salt: bytes32(uint256(3)),
            inviteCode: bytes32(0)
        });

        vm.prank(creator);
        vm.expectRevert(CcaLaunchFactory.NeedInvite.selector);
        factory.createLaunch(params);
    }

    function test_bid_revertsWithoutInvite() public {
        (,, address auction) = _create(1 ether);
        vm.roll(block.number + 1);

        vm.prank(stranger);
        vm.expectRevert();
        IContinuousClearingAuction(auction).submitBid{value: 1 ether}(_maxPrice(), 1 ether, stranger, "");
    }

    function test_creator_canBidWithoutInvite() public {
        (,, address auction) = _create(1 ether);
        vm.roll(block.number + 1);
        vm.deal(creator, 2 ether);

        vm.prank(creator);
        IContinuousClearingAuction(auction).submitBid{value: 1 ether}(
            _maxPrice(), 1 ether, creator, abi.encode(bytes32(0))
        );
        assertTrue(registry.participated(auction, creator));
        assertEq(registry.referrerOf(auction, creator), address(0));
        assertEq(referrerNft.tokenOf(auction, creator), 0);
        assertEq(referrerNft.totalWeightOf(auction), 0);
    }

    function test_bid_withCreatorInvite_doesNotMintNft() public {
        (,, address auction) = _create(1 ether);
        vm.roll(block.number + 1);

        vm.prank(bidder);
        IContinuousClearingAuction(auction).submitBid{value: 1 ether}(
            _maxPrice(), 1 ether, bidder, abi.encode(inviteCode)
        );
        assertTrue(registry.participated(auction, bidder));
        assertEq(registry.referrerOf(auction, bidder), creator);
        assertEq(referrerNft.tokenOf(auction, creator), 0);
        assertEq(referrerNft.pendingVolume(auction, creator), 0);
        assertEq(referrerNft.totalWeightOf(auction), 0);
    }

    function test_bid_withOutbound_doesNotMintInvite() public {
        (,, address auction) = _create(1 ether);
        vm.roll(block.number + 1);

        bytes32 outbound = keccak256("bidder-outbound");
        vm.prank(bidder);
        IContinuousClearingAuction(auction).submitBid{value: 1 ether}(
            _maxPrice(), 1 ether, bidder, abi.encode(inviteCode, outbound)
        );

        assertEq(registry.inviteIssuer(auction, outbound), address(0));
        assertEq(registry.referrerOf(auction, bidder), creator);
        assertTrue(registry.participated(auction, bidder));
    }

    function test_distributor_mintsNftAtScoutAndUpgrades() public {
        (,, address auction) = _create(1 ether);
        vm.roll(block.number + 1);

        bytes32[] memory codes = new bytes32[](1);
        codes[0] = keccak256("bidder-invite");
        vm.prank(operator);
        registry.createInvitesFor(auction, bidder, codes);

        vm.deal(stranger, 200 ether);
        vm.prank(stranger);
        IContinuousClearingAuction(auction).submitBid{value: 0.4 ether}(
            _maxPrice(), 0.4 ether, stranger, abi.encode(codes[0])
        );
        assertEq(referrerNft.tokenOf(auction, bidder), 0);
        assertEq(referrerNft.pendingVolume(auction, bidder), 0.4 ether);

        address other = makeAddr("other");
        vm.deal(other, 2 ether);
        vm.prank(other);
        IContinuousClearingAuction(auction).submitBid{value: 0.2 ether}(
            _maxPrice(), 0.2 ether, other, abi.encode(codes[0])
        );
        uint256 tokenId = referrerNft.tokenOf(auction, bidder);
        assertEq(tokenId, 1);
        assertEq(referrerNft.ownerOf(tokenId), bidder);
        assertEq(referrerNft.volumeOf(tokenId), 0.6 ether);
        (ReferrerNFT.Tier tier, uint256 weight) = referrerNft.tierOf(0.6 ether);
        assertEq(uint256(tier), uint256(ReferrerNFT.Tier.Scout));
        assertEq(referrerNft.weightOf(tokenId), weight);
        assertEq(referrerNft.totalWeightOf(auction), 1);

        vm.prank(stranger);
        IContinuousClearingAuction(auction).submitBid{value: 5 ether}(
            _maxPrice(), 5 ether, stranger, abi.encode(codes[0])
        );
        assertEq(referrerNft.volumeOf(tokenId), 5.6 ether);
        assertEq(uint256(referrerNft.tier(tokenId)), uint256(ReferrerNFT.Tier.Advocate));
        assertEq(referrerNft.weightOf(tokenId), 10);
        assertEq(referrerNft.totalWeightOf(auction), 10);
    }

    function test_claimReferrer_followsNft() public {
        (uint256 launchId, address token, address auction) = _create(1 ether);
        CcaLaunchFactory.Launch memory launch = factory.getLaunch(launchId);
        vm.roll(launch.startBlock + 1);

        bytes32[] memory codes = new bytes32[](1);
        codes[0] = keccak256("dist-invite");
        vm.prank(operator);
        registry.createInvitesFor(auction, bidder, codes);

        vm.deal(stranger, 60 ether);
        vm.prank(stranger);
        IContinuousClearingAuction(auction).submitBid{value: 50 ether}(
            _maxPrice(), 50 ether, stranger, abi.encode(codes[0])
        );
        uint256 tokenId = referrerNft.tokenOf(auction, bidder);
        assertEq(tokenId, 1);
        assertEq(referrerNft.ownerOf(tokenId), bidder);
        assertEq(uint256(referrerNft.tier(tokenId)), uint256(ReferrerNFT.Tier.Partner));

        vm.roll(launch.endBlock);
        IContinuousClearingAuction(auction).checkpoint();
        assertTrue(IContinuousClearingAuction(auction).isGraduated());
        vm.roll(launch.endBlock + 1);
        lbp.migrate(ILBPInitializer(auction));

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(token),
            fee: 1_000,
            tickSpacing: 60,
            hooks: IHooks(address(feeHook))
        });
        uint256 swapIn = 1 ether;
        swapRouter.swapExactTokensForTokens{value: swapIn}(
            swapIn, 0, true, key, "", address(this), block.timestamp + 60
        );
        feeHook.harvest(key);

        uint256 hookFeeAmount = (swapIn * HOOK_FEE) / 1e6;
        uint256 expectedReferrer = (hookFeeAmount * 7_500) / 10_000;
        uint256 before = bidder.balance;
        vm.prank(bidder);
        uint256 claimed = distributor.claimReferrer(key.toId(), address(0), tokenId);
        assertEq(claimed, expectedReferrer);
        assertEq(bidder.balance, before + claimed);

        vm.prank(bidder);
        referrerNft.transferFrom(bidder, stranger, tokenId);
        assertEq(referrerNft.ownerOf(tokenId), stranger);
        assertEq(referrerNft.tokensOfOwner(bidder).length, 0);
        assertEq(referrerNft.tokensOfOwner(stranger)[0], tokenId);

        uint256 tokenBal = IERC20(token).balanceOf(address(this));
        IERC20(token).approve(address(swapRouter), tokenBal);
        swapRouter.swapExactTokensForTokens(tokenBal / 2, 0, false, key, "", address(this), block.timestamp + 60);
        feeHook.harvest(key);

        vm.prank(bidder);
        vm.expectRevert(FeeDistributor.NothingToClaim.selector);
        distributor.claimReferrer(key.toId(), address(0), tokenId);

        vm.prank(stranger);
        assertGt(distributor.claimReferrer(key.toId(), address(0), tokenId), 0);
    }

    function test_participantCannotCreateInvitesWithoutAuth() public {
        (,, address auction) = _create(1 ether);
        vm.roll(block.number + 1);

        vm.prank(bidder);
        IContinuousClearingAuction(auction).submitBid{value: 1 ether}(
            _maxPrice(), 1 ether, bidder, abi.encode(inviteCode)
        );

        bytes32[] memory codes = new bytes32[](1);
        codes[0] = keccak256("bidder-invite");
        vm.prank(bidder);
        vm.expectRevert(InviteRegistry.NotAuthorized.selector);
        registry.createInvitesFor(auction, bidder, codes);
    }

    function test_migrate_poolUsesFeeAndHook_thenHarvestClaims() public {
        (uint256 launchId, address token, address auction) = _create(1 ether);
        CcaLaunchFactory.Launch memory launch = factory.getLaunch(launchId);

        vm.roll(launch.startBlock + 1);
        vm.prank(bidder);
        IContinuousClearingAuction(auction).submitBid{value: 50 ether}(
            _maxPrice(), 50 ether, bidder, abi.encode(inviteCode)
        );

        vm.roll(launch.endBlock);
        IContinuousClearingAuction(auction).checkpoint();
        assertTrue(IContinuousClearingAuction(auction).isGraduated());

        vm.roll(launch.endBlock + 1);
        lbp.migrate(ILBPInitializer(auction));

        PoolKey memory key = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(token),
            fee: 1_000,
            tickSpacing: 60,
            hooks: IHooks(address(feeHook))
        });
        (uint160 sqrtPriceX96,,,) = poolManager.getSlot0(key.toId());
        assertGt(sqrtPriceX96, 0);

        uint256 swapIn = 1 ether;
        swapRouter.swapExactTokensForTokens{value: swapIn}(
            swapIn, 0, true, key, "", address(this), block.timestamp + 60
        );

        feeHook.harvest(key);

        uint256 hookFeeAmount = (swapIn * HOOK_FEE) / 1e6;
        uint256 expectedCreator = (hookFeeAmount * 2_000) / 10_000;
        uint256 creatorEthBefore = creator.balance;
        vm.prank(creator);
        uint256 claimed = distributor.claimCreator(key.toId(), address(0));
        assertEq(claimed, expectedCreator);
        assertEq(creator.balance, creatorEthBefore + claimed);
        assertEq(distributor.creatorOwed(key.toId(), token), 0);

        assertEq(distributor.pendingReferrer(key.toId(), address(0), 1), 0);

        address platform = distributor.PLATFORM();
        uint256 platformOwed = distributor.platformOwed(key.toId(), address(0));
        if (platformOwed > 0) {
            uint256 beforeBal = platform.balance;
            vm.prank(platform);
            distributor.claimPlatform(key.toId(), address(0));
            assertEq(platform.balance, beforeBal + platformOwed);
        }

        uint256 tokenBal = IERC20(token).balanceOf(address(this));
        IERC20(token).approve(address(swapRouter), tokenBal);
        uint256 creatorOwedBeforeSell = distributor.creatorOwed(key.toId(), address(0));
        swapRouter.swapExactTokensForTokens(tokenBal / 2, 0, false, key, "", address(this), block.timestamp + 60);
        feeHook.harvest(key);
        assertGt(distributor.creatorOwed(key.toId(), address(0)), creatorOwedBeforeSell);
        assertEq(distributor.creatorOwed(key.toId(), token), 0);
    }

    function test_manyUniqueOwnersCanBid() public {
        CcaLaunchFactory.CreateParams memory params = CcaLaunchFactory.CreateParams({
            metadata: CcaLaunchFactory.Metadata({
                name: "Test",
                symbol: "TST",
                description: "d",
                image: "",
                website: "https://x.com/test",
                extraData: X_EXTRA
            }),
            auctionBlocks: 250,
            minRaise: 100 ether,
            auctionSupplyBps: 5_000,
            salt: bytes32(uint256(1)),
            inviteCode: inviteCode
        });
        vm.prank(creator);
        (,, address auction) = factory.createLaunch(params);
        vm.roll(block.number + 1);
        vm.deal(creator, 200 ether);
        uint256 floor = FLOOR_PRICE;
        uint256 tick = TICK_SPACING_Q96;
        for (uint256 i = 0; i < 57; i++) {
            address owner =
                vm.addr(uint256(keccak256(abi.encodePacked("punks-bidder", i + 1))));
            uint128 amount = i < 12 ? uint128(0.25 ether)
                : i < 24 ? uint128(0.5 ether)
                : i < 36 ? uint128(1 ether)
                : i < 46 ? uint128(1.5 ether)
                : i < 52 ? uint128(2 ether)
                : i < 55 ? uint128(3 ether)
                : i == 55 ? uint128(5 ether)
                : uint128(6.13742 ether);
            vm.prank(creator);
            IContinuousClearingAuction(auction).submitBid{value: amount}(
                floor + tick * (BID_TICKS_ABOVE_FLOOR + i), amount, owner, abi.encode(inviteCode)
            );
            vm.roll(block.number + 1);
        }
        assertEq(auction.balance, 68.13742 ether);
    }

    function test_megapotFailedRaiseOwners() public {
        CcaLaunchFactory.CreateParams memory params = CcaLaunchFactory.CreateParams({
            metadata: CcaLaunchFactory.Metadata({
                name: "Megapot",
                symbol: "MEGAPOT",
                description: "d",
                image: "",
                website: "https://megapot.io/",
                extraData: X_EXTRA
            }),
            auctionBlocks: 250,
            minRaise: 50 ether,
            auctionSupplyBps: 5_000,
            salt: bytes32(uint256(5)),
            inviteCode: inviteCode
        });
        vm.prank(creator);
        (,, address auction) = factory.createLaunch(params);
        vm.roll(block.number + 1);
        vm.deal(creator, 50 ether);
        address tester = 0x530bf56676Af5bdf5B0104Db8CD3d4588AA80735;
        vm.deal(tester, 1 ether);
        uint256 floor = FLOOR_PRICE;
        uint256 tick = TICK_SPACING_Q96;
        for (uint256 i = 0; i < 12; i++) {
            address owner =
                vm.addr(uint256(keccak256(abi.encodePacked("megapot-bidder", i + 1))));
            uint128 amount = i < 4 ? uint128(1.5 ether)
                : i < 8 ? uint128(2 ether)
                : i < 11 ? uint128(3 ether)
                : uint128(4.724135 ether);
            vm.prank(creator);
            IContinuousClearingAuction(auction).submitBid{value: amount}(
                floor + tick * (BID_TICKS_ABOVE_FLOOR + i), amount, owner, abi.encode(inviteCode)
            );
            vm.roll(block.number + 1);
        }
        vm.prank(tester);
        IContinuousClearingAuction(auction).submitBid{value: 0.4 ether}(
            _maxPrice(), 0.4 ether, tester, abi.encode(inviteCode)
        );
        assertEq(auction.balance, 28.124135 ether);
    }

    function test_virtuosoGraduatedRaiseOwners() public {
        CcaLaunchFactory.CreateParams memory params = CcaLaunchFactory.CreateParams({
            metadata: CcaLaunchFactory.Metadata({
                name: "Virtuoso Club",
                symbol: "VIRTUOSO",
                description: "d",
                image: "",
                website: "https://virtuoso.club/",
                extraData: X_EXTRA
            }),
            auctionBlocks: 250,
            minRaise: 100 ether,
            auctionSupplyBps: 5_000,
            salt: bytes32(uint256(2)),
            inviteCode: inviteCode
        });
        vm.prank(creator);
        (,, address auction) = factory.createLaunch(params);
        vm.roll(block.number + 1);
        vm.deal(creator, 300 ether);
        address tester = 0x530bf56676Af5bdf5B0104Db8CD3d4588AA80735;
        vm.deal(tester, 10 ether);
        uint256 floor = FLOOR_PRICE;
        uint256 tick = TICK_SPACING_Q96;
        for (uint256 i = 0; i < 24; i++) {
            address owner =
                vm.addr(uint256(keccak256(abi.encodePacked("virtuoso-bidder", i + 1))));
            uint128 amount = i < 6 ? uint128(5 ether)
                : i < 12 ? uint128(8 ether)
                : i < 17 ? uint128(10 ether)
                : i < 21 ? uint128(15 ether)
                : i < 23 ? uint128(20 ether)
                : uint128(4.5124 ether);
            vm.prank(creator);
            IContinuousClearingAuction(auction).submitBid{value: amount}(
                floor + tick * (BID_TICKS_ABOVE_FLOOR + i), amount, owner, abi.encode(inviteCode)
            );
            vm.roll(block.number + 1);
        }
        vm.prank(tester);
        IContinuousClearingAuction(auction).submitBid{value: 10 ether}(
            _maxPrice(), 10 ether, tester, abi.encode(inviteCode)
        );
        assertEq(auction.balance, 242.5124 ether);
    }

    function _signCreateInvites(
        address auction,
        address issuer,
        bytes32[] memory codes,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (bytes memory) {
        bytes32 typehash = keccak256(
            "CreateInvites(address auction,address issuer,bytes32 codesHash,uint256 nonce,uint256 deadline)"
        );
        bytes32 structHash = keccak256(
            abi.encode(typehash, auction, issuer, keccak256(abi.encode(codes)), nonce, deadline)
        );
        bytes32 digest = keccak256(abi.encodePacked("\x19\x01", registry.DOMAIN_SEPARATOR(), structHash));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(operatorKey, digest);
        return abi.encodePacked(r, s, v);
    }

    function _maxPrice() internal pure returns (uint256) {
        return FLOOR_PRICE + TICK_SPACING_Q96 * BID_TICKS_ABOVE_FLOOR;
    }

    function _create(uint128 minRaise) internal returns (uint256 launchId, address token, address auction) {
        CcaLaunchFactory.CreateParams memory params = CcaLaunchFactory.CreateParams({
            metadata: CcaLaunchFactory.Metadata({
                name: "Test",
                symbol: "TST",
                description: "d",
                image: "",
                website: "https://x.com/test",
                extraData: X_EXTRA
            }),
            auctionBlocks: AUCTION_BLOCKS,
            minRaise: minRaise,
            auctionSupplyBps: 5_000,
            salt: bytes32(uint256(1)),
            inviteCode: inviteCode
        });

        vm.prank(creator);
        return factory.createLaunch(params);
    }

    receive() external payable {}
}
