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
import {FixedPoint96} from "continuous-clearing-auction/libraries/FixedPoint96.sol";

import {BaseTest} from "./utils/BaseTest.sol";
import {FeeDistributor} from "../src/fee/FeeDistributor.sol";
import {LaunchFeeHook} from "../src/fee/LaunchFeeHook.sol";
import {InviteRegistry} from "../src/invite/InviteRegistry.sol";
import {InviteValidationHook} from "../src/invite/InviteValidationHook.sol";
import {CcaLaunchFactory} from "../src/strategy/CcaLaunchFactory.sol";

contract CcaLaunchTest is BaseTest {
    using PoolIdLibrary for PoolKey;
    using StateLibrary for IPoolManager;

    uint24 constant HOOK_FEE = 4_000;
    uint64 constant AUCTION_BLOCKS = 10; // 1e7 % 10 == 0

    LiquidityLauncher launcher;
    ContinuousClearingAuctionFactory ccaFactory;
    LBPStrategy lbp;
    FeeDistributor distributor;
    InviteRegistry registry;
    InviteValidationHook inviteHook;
    LaunchFeeHook feeHook;
    CcaLaunchFactory factory;

    address creator = makeAddr("creator");
    address bidder = makeAddr("bidder");
    address stranger = makeAddr("stranger");

    bytes32 inviteCode = keccak256("invite-1");

    function setUp() public {
        deployArtifactsAndLabel();

        launcher = new LiquidityLauncher(IAllowanceTransfer(address(permit2)));
        ccaFactory = new ContinuousClearingAuctionFactory(address(0));

        bytes memory lbpArgs = abi.encode(address(positionManager), address(poolManager), address(ccaFactory));
        (address lbpAddr, bytes32 lbpSalt) =
            HookMiner.find(address(this), Hooks.BEFORE_INITIALIZE_FLAG, type(LBPStrategy).creationCode, lbpArgs);
        lbp = new LBPStrategy{salt: lbpSalt}(
            positionManager, poolManager, IDistributorFactory(address(ccaFactory))
        );
        assertEq(address(lbp), lbpAddr);

        distributor = new FeeDistributor();
        registry = new InviteRegistry();
        inviteHook = new InviteValidationHook(registry);
        registry.setValidationHook(address(inviteHook));

        bytes memory hookArgs = abi.encode(address(poolManager), address(lbp), address(distributor), HOOK_FEE);
        uint160 flags =
            uint160(Hooks.BEFORE_INITIALIZE_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG);
        (address hookAddr, bytes32 salt) =
            HookMiner.find(address(this), flags, type(LaunchFeeHook).creationCode, hookArgs);
        feeHook = new LaunchFeeHook{salt: salt}(poolManager, address(lbp), distributor, HOOK_FEE);
        assertEq(address(feeHook), hookAddr);

        distributor.setReferrals(address(registry));
        distributor.setHook(address(feeHook));

        factory = new CcaLaunchFactory(
            ILiquidityLauncher(address(launcher)),
            ILBPStrategy(address(lbp)),
            IDistributorFactory(address(ccaFactory)),
            registry,
            distributor,
            feeHook,
            address(this)
        );
        registry.setFactory(address(factory));
        distributor.setRegistrar(address(factory));

        vm.deal(bidder, 1000 ether);
        vm.deal(stranger, 100 ether);
        vm.deal(creator, 1 ether);
        vm.deal(address(this), 100 ether);
    }

    function test_createLaunch_seedsInvitesAndOpensCca() public {
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
    }

    function test_bid_revertsWithoutInvite() public {
        (,, address auction) = _create(1 ether);
        vm.roll(block.number + 1);

        vm.prank(stranger);
        vm.expectRevert();
        IContinuousClearingAuction(auction).submitBid{value: 1 ether}(_maxPrice(), 1 ether, stranger, "");
    }

    function test_bid_withInvite_recordsReferral() public {
        (,, address auction) = _create(1 ether);
        vm.roll(block.number + 1);

        vm.prank(bidder);
        IContinuousClearingAuction(auction).submitBid{value: 1 ether}(
            _maxPrice(), 1 ether, bidder, abi.encode(inviteCode)
        );
        assertTrue(registry.participated(auction, bidder));
        assertEq(registry.referralCount(auction, creator), 1);
        assertEq(registry.totalReferralCount(auction), 1);
    }

    function test_participantCanCreateInvites() public {
        (,, address auction) = _create(1 ether);
        vm.roll(block.number + 1);

        vm.prank(bidder);
        IContinuousClearingAuction(auction).submitBid{value: 1 ether}(
            _maxPrice(), 1 ether, bidder, abi.encode(inviteCode)
        );

        bytes32[] memory codes = new bytes32[](1);
        codes[0] = keccak256("bidder-invite");
        vm.prank(bidder);
        registry.createInvites(auction, codes);
        assertEq(registry.inviteIssuer(auction, codes[0]), bidder);
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

        uint256 creatorTokenBefore = IERC20(token).balanceOf(creator);
        vm.prank(creator);
        uint256 claimed = distributor.claimCreator(key.toId(), token);
        assertGt(claimed, 0);
        assertEq(IERC20(token).balanceOf(creator), creatorTokenBefore + claimed);

        uint256 pending = distributor.pendingReferrer(key.toId(), token, creator);
        if (pending > 0) {
            vm.prank(creator);
            distributor.claimReferrer(key.toId(), token);
        }

        address platform = distributor.PLATFORM();
        uint256 platformOwed = distributor.platformOwed(key.toId(), token);
        if (platformOwed > 0) {
            uint256 beforeBal = IERC20(token).balanceOf(platform);
            vm.prank(platform);
            distributor.claimPlatform(key.toId(), token);
            assertEq(IERC20(token).balanceOf(platform), beforeBal + platformOwed);
        }
    }

    function _maxPrice() internal pure returns (uint256) {
        uint256 floor = 1000 << FixedPoint96.RESOLUTION;
        uint256 tickSpacing = 100 << FixedPoint96.RESOLUTION;
        return floor + tickSpacing;
    }

    function _create(uint128 minRaise) internal returns (uint256 launchId, address token, address auction) {
        bytes32[] memory codes = new bytes32[](1);
        codes[0] = inviteCode;

        CcaLaunchFactory.CreateParams memory params = CcaLaunchFactory.CreateParams({
            metadata: CcaLaunchFactory.Metadata({
                name: "Test",
                symbol: "TST",
                description: "d",
                image: "",
                website: "",
                twitter: "",
                telegram: ""
            }),
            auctionBlocks: AUCTION_BLOCKS,
            minRaise: minRaise,
            auctionSupplyBps: 5_000,
            poolLpFee: 1_000,
            hookFee: HOOK_FEE,
            salt: bytes32(uint256(1)),
            inviteCodes: codes
        });

        vm.prank(creator);
        return factory.createLaunch(params);
    }

    receive() external payable {}
}
