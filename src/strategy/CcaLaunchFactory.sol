// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";

import {ILiquidityLauncher} from "liquidity-launcher/src/interfaces/ILiquidityLauncher.sol";
import {Distribution} from "liquidity-launcher/src/types/Distribution.sol";
import {
    MigratorParameters,
    PoolParameters,
    LiquidityAllocationBracket
} from "liquidity-launcher/src/libraries/MigratorParams.sol";
import {PositionDefinition} from "liquidity-launcher/src/types/PositionPlannerTypes.sol";
import {IDistributorFactory} from "liquidity-launcher/src/interfaces/IDistributorFactory.sol";
import {ILBPStrategy} from "liquidity-launcher/src/interfaces/ILBPStrategy.sol";

import {AuctionParameters} from "continuous-clearing-auction/interfaces/IContinuousClearingAuction.sol";
import {ConstantsLib} from "continuous-clearing-auction/libraries/ConstantsLib.sol";
import {FixedPoint96} from "continuous-clearing-auction/libraries/FixedPoint96.sol";

import {LaunchToken} from "../LaunchToken.sol";
import {FeeDistributor} from "../fee/FeeDistributor.sol";
import {LaunchFeeHook} from "../fee/LaunchFeeHook.sol";
import {InviteRegistry} from "../invite/InviteRegistry.sol";

/// @notice Creates LaunchToken + CCA/LBP distribution with invite gating and fee hook.
contract CcaLaunchFactory {
    using PoolIdLibrary for PoolKey;

    uint24 public constant DEFAULT_POOL_LP_FEE = 1_000;
    uint24 public constant DEFAULT_HOOK_FEE = 4_000;
    int24 public constant DEFAULT_TICK_SPACING = 60;
    uint16 public constant DEFAULT_AUCTION_SUPPLY_BPS = 5_000;
    uint256 public constant DEFAULT_AUCTION_TICK_SPACING = 100 << FixedPoint96.RESOLUTION;
    uint256 public constant DEFAULT_FLOOR_PRICE = 1000 << FixedPoint96.RESOLUTION;

    ILiquidityLauncher public immutable launcher;
    ILBPStrategy public immutable lbpStrategy;
    IDistributorFactory public immutable ccaFactory;
    InviteRegistry public immutable invites;
    FeeDistributor public immutable distributor;
    LaunchFeeHook public immutable feeHook;
    address public immutable positionRecipient;

    struct Metadata {
        string name;
        string symbol;
        string description;
        string image;
        string website;
        string twitter;
        string telegram;
    }

    struct CreateParams {
        Metadata metadata;
        uint64 auctionBlocks;
        uint128 minRaise;
        uint16 auctionSupplyBps;
        uint24 poolLpFee;
        uint24 hookFee;
        bytes32 salt;
        bytes32[] inviteCodes;
    }

    struct Launch {
        address creator;
        address token;
        address auction;
        uint64 startBlock;
        uint64 endBlock;
        uint64 claimBlock;
        uint128 minRaise;
        uint24 poolLpFee;
        uint24 hookFee;
    }

    uint256 public launchCount;
    mapping(uint256 => Launch) public launches;
    mapping(address => uint256) public launchIdByToken;
    mapping(address => uint256) public launchIdByAuction;

    event LaunchCreated(
        uint256 indexed launchId,
        address indexed creator,
        address token,
        address auction,
        uint64 endBlock,
        uint128 minRaise,
        uint24 poolLpFee,
        uint24 hookFee
    );

    error EmptyName();
    error InvalidDuration();
    error InvalidSupplyBps();
    error InvalidFee();
    error NeedInvites();

    constructor(
        ILiquidityLauncher launcher_,
        ILBPStrategy lbpStrategy_,
        IDistributorFactory ccaFactory_,
        InviteRegistry invites_,
        FeeDistributor distributor_,
        LaunchFeeHook feeHook_,
        address positionRecipient_
    ) {
        launcher = launcher_;
        lbpStrategy = lbpStrategy_;
        ccaFactory = ccaFactory_;
        invites = invites_;
        distributor = distributor_;
        feeHook = feeHook_;
        positionRecipient = positionRecipient_;
    }

    function createLaunch(CreateParams calldata params) external returns (uint256 launchId, address token, address auction) {
        if (bytes(params.metadata.name).length == 0 || bytes(params.metadata.symbol).length == 0) revert EmptyName();
        if (params.auctionBlocks < 2) revert InvalidDuration();
        if (params.inviteCodes.length == 0) revert NeedInvites();

        uint16 auctionSupplyBps = params.auctionSupplyBps == 0 ? DEFAULT_AUCTION_SUPPLY_BPS : params.auctionSupplyBps;
        if (auctionSupplyBps == 0 || auctionSupplyBps >= 10_000) revert InvalidSupplyBps();

        uint24 poolLpFee = params.poolLpFee == 0 ? DEFAULT_POOL_LP_FEE : params.poolLpFee;
        uint24 hookFee = params.hookFee == 0 ? DEFAULT_HOOK_FEE : params.hookFee;
        if (poolLpFee > 100_000 || hookFee > 1_000_000) revert InvalidFee();

        token = address(
            new LaunchToken(
                params.metadata.name,
                params.metadata.symbol,
                params.metadata.description,
                params.metadata.image,
                params.metadata.website,
                params.metadata.twitter,
                params.metadata.telegram,
                address(launcher)
            )
        );

        uint256 supply = LaunchToken(token).TOTAL_SUPPLY();
        uint128 reservedForLp = uint128((supply * (10_000 - auctionSupplyBps)) / 10_000);
        uint128 auctionSupply = uint128(supply - reservedForLp);

        uint64 startBlock = uint64(block.number);
        uint64 endBlock = startBlock + params.auctionBlocks;
        uint64 claimBlock = endBlock + 10;
        uint64 migrationBlock = endBlock + 1;

        bytes memory auctionStepsData = _buildSteps(params.auctionBlocks);

        AuctionParameters memory auctionParams = AuctionParameters({
            currency: address(0),
            tokensRecipient: msg.sender,
            fundsRecipient: address(lbpStrategy),
            startBlock: startBlock,
            endBlock: endBlock,
            claimBlock: claimBlock,
            tickSpacing: DEFAULT_AUCTION_TICK_SPACING,
            validationHook: address(invites.validationHook()),
            floorPrice: DEFAULT_FLOOR_PRICE,
            requiredCurrencyRaised: params.minRaise,
            auctionStepsData: auctionStepsData
        });

        PositionDefinition[] memory defs = new PositionDefinition[](1);
        defs[0] = PositionDefinition({
            offsetLower: TickMath.MIN_TICK,
            offsetUpper: TickMath.MAX_TICK,
            weight: 1e7,
            overridePositionRecipient: address(0)
        });

        LiquidityAllocationBracket[] memory brackets = new LiquidityAllocationBracket[](1);
        brackets[0] = LiquidityAllocationBracket({lowerThreshold: 0, rate: 1e7});

        MigratorParameters memory migrator = MigratorParameters({
            token: token,
            currency: address(0),
            migrationBlock: migrationBlock,
            reservedTokenAmountForLP: reservedForLp,
            recipient: msg.sender,
            positionRecipient: positionRecipient,
            poolParameters: PoolParameters({fee: poolLpFee, tickSpacing: DEFAULT_TICK_SPACING, hook: address(feeHook)}),
            positionDefinitions: abi.encode(defs),
            lpAllocationSchedule: abi.encode(brackets)
        });

        bytes memory initializerParams = abi.encode(auctionParams);
        bytes memory configData = abi.encode(migrator, initializerParams);

        bytes32 launcherSalt = params.salt;
        // LiquidityLauncher passes keccak256(abi.encode(msg.sender, salt)) into the strategy;
        // msg.sender there is this factory.
        bytes32 strategySalt = keccak256(abi.encode(address(this), launcherSalt));
        bytes32 initializerSalt = keccak256(abi.encode(strategySalt, migrator));

        auction = address(
            ccaFactory.getAddress(token, auctionSupply, initializerParams, initializerSalt, address(lbpStrategy))
        );

        invites.registerAuction(auction, token, msg.sender);
        invites.seedInvites(auction, msg.sender, params.inviteCodes);

        Distribution memory dist =
            Distribution({strategy: address(lbpStrategy), amount: uint128(supply), configData: configData});
        launcher.distributeToken(token, dist, launcherSalt);

        PoolKey memory key = _poolKey(address(0), token, poolLpFee, address(feeHook));
        distributor.registerPool(key.toId(), auction, msg.sender);
        launchId = ++launchCount;
        launches[launchId] = Launch({
            creator: msg.sender,
            token: token,
            auction: auction,
            startBlock: startBlock,
            endBlock: endBlock,
            claimBlock: claimBlock,
            minRaise: params.minRaise,
            poolLpFee: poolLpFee,
            hookFee: hookFee
        });
        launchIdByToken[token] = launchId;
        launchIdByAuction[auction] = launchId;

        emit LaunchCreated(launchId, msg.sender, token, auction, endBlock, params.minRaise, poolLpFee, hookFee);
    }

    function getLaunch(uint256 launchId) external view returns (Launch memory) {
        return launches[launchId];
    }

    function _buildSteps(uint64 auctionBlocks) internal pure returns (bytes memory steps) {
        if (ConstantsLib.MPS % uint256(auctionBlocks) != 0) revert InvalidDuration();
        uint24 mps = uint24(ConstantsLib.MPS / uint256(auctionBlocks));
        steps = abi.encodePacked(mps, uint40(auctionBlocks));
    }

    function _poolKey(address currency, address token, uint24 fee, address hook)
        internal
        pure
        returns (PoolKey memory key)
    {
        Currency c0 = Currency.wrap(currency);
        Currency c1 = Currency.wrap(token);
        if (uint160(currency) > uint160(token)) (c0, c1) = (c1, c0);
        key = PoolKey({
            currency0: c0,
            currency1: c1,
            fee: fee,
            tickSpacing: DEFAULT_TICK_SPACING,
            hooks: IHooks(hook)
        });
    }
}
