// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console2} from "forge-std/Script.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {IPositionManager} from "@uniswap/v4-periphery/src/interfaces/IPositionManager.sol";
import {IAllowanceTransfer} from "permit2/src/interfaces/IAllowanceTransfer.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {HookMiner} from "@uniswap/v4-periphery/src/utils/HookMiner.sol";
import {AddressConstants} from "hookmate/constants/AddressConstants.sol";
import {Permit2Deployer} from "hookmate/artifacts/Permit2.sol";
import {V4PoolManagerDeployer} from "hookmate/artifacts/V4PoolManager.sol";
import {V4PositionManagerDeployer} from "hookmate/artifacts/V4PositionManager.sol";
import {V4RouterDeployer} from "hookmate/artifacts/V4Router.sol";

import {LiquidityLauncher} from "liquidity-launcher/src/LiquidityLauncher.sol";
import {LBPStrategy} from "liquidity-launcher/src/strategies/lbp/LBPStrategy.sol";
import {CompoundingClaimRecipient} from "liquidity-launcher/src/periphery/CompoundingClaimRecipient.sol";
import {IDistributorFactory} from "liquidity-launcher/src/interfaces/IDistributorFactory.sol";
import {ILiquidityLauncher} from "liquidity-launcher/src/interfaces/ILiquidityLauncher.sol";
import {ILBPStrategy} from "liquidity-launcher/src/interfaces/ILBPStrategy.sol";
import {ContinuousClearingAuctionFactory} from "continuous-clearing-auction/ContinuousClearingAuctionFactory.sol";
import {UERC20Factory} from "@uniswap/uerc20-factory/src/factories/UERC20Factory.sol";

import {FeeDistributor} from "../src/fee/FeeDistributor.sol";
import {LaunchFeeHook} from "../src/fee/LaunchFeeHook.sol";
import {InviteRegistry} from "../src/invite/InviteRegistry.sol";
import {InviteValidationHook} from "../src/invite/InviteValidationHook.sol";
import {ReferrerNFT} from "../src/nft/ReferrerNFT.sol";
import {CcaLaunchFactory} from "../src/strategy/CcaLaunchFactory.sol";

/// @notice Deploys CCA/LBP launchpad stack for anvil or Base Sepolia.
contract DeployCcaScript is Script {
    address constant UNISWAP_LIQUIDITY_LAUNCHER_V3 = 0x00004c4ccc709Ef590F7C81102C0689F0263D4e9;
    address constant CREATE2_DEPLOYER = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    uint24 constant DEFAULT_HOOK_FEE = 4_000;

    function run() public {
        uint256 deployerKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerKey);

        address permit2 = AddressConstants.getPermit2Address();
        address poolManager;
        address positionManager;
        address swapRouter;

        uint256 startBlock = block.number;

        if (block.chainid == 31337 && permit2.code.length == 0) {
            vm.etch(permit2, Permit2Deployer.deploy().code);
        }

        vm.startBroadcast(deployerKey);

        if (block.chainid == 31337) {
            poolManager = V4PoolManagerDeployer.deploy(deployer);
            positionManager = V4PositionManagerDeployer.deploy(
                poolManager, permit2, 300_000, address(0), address(0)
            );
            swapRouter = V4RouterDeployer.deploy(poolManager, permit2);
        } else {
            poolManager = AddressConstants.getPoolManagerAddress(block.chainid);
            positionManager = AddressConstants.getPositionManagerAddress(block.chainid);
            swapRouter = AddressConstants.getV4SwapRouterAddress(block.chainid);
            require(
                poolManager != address(0) && positionManager != address(0), "missing v4 addresses"
            );
        }

        address launcherAddr = vm.envOr("LIQUIDITY_LAUNCHER", address(0));
        if (launcherAddr == address(0) || block.chainid == 31337) {
            if (block.chainid == 31337) {
                launcherAddr = address(new LiquidityLauncher(IAllowanceTransfer(permit2)));
            } else if (launcherAddr == address(0)) {
                launcherAddr = UNISWAP_LIQUIDITY_LAUNCHER_V3;
            }
        }

        ContinuousClearingAuctionFactory ccaFactory = new ContinuousClearingAuctionFactory(address(0));

        bytes memory lbpArgs = abi.encode(positionManager, poolManager, address(ccaFactory));
        (address lbpAddr, bytes32 lbpSalt) = HookMiner.find(
            CREATE2_DEPLOYER, Hooks.BEFORE_INITIALIZE_FLAG, type(LBPStrategy).creationCode, lbpArgs
        );
        LBPStrategy lbp = new LBPStrategy{salt: lbpSalt}(
            IPositionManager(positionManager), IPoolManager(poolManager), IDistributorFactory(address(ccaFactory))
        );
        require(address(lbp) == lbpAddr, "lbp addr");

        CompoundingClaimRecipient compounder =
            new CompoundingClaimRecipient(IPositionManager(positionManager), 1);

        FeeDistributor distributor = new FeeDistributor();
        InviteRegistry registry = new InviteRegistry();
        string memory nftBaseUri = vm.envOr("REFERRER_NFT_BASE_URI", string("http://localhost:3001/api/nft/"));
        ReferrerNFT referrerNft = new ReferrerNFT(nftBaseUri);
        referrerNft.setRegistry(address(registry));
        registry.setReferrerNft(address(referrerNft));
        InviteValidationHook inviteHook = new InviteValidationHook(registry);
        registry.setValidationHook(address(inviteHook));

        bytes memory hookArgs = abi.encode(poolManager, address(lbp), address(distributor), DEFAULT_HOOK_FEE);
        uint160 flags = uint160(
            Hooks.BEFORE_INITIALIZE_FLAG | Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG
                | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.AFTER_SWAP_RETURNS_DELTA_FLAG
        );
        (address hookAddr, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, flags, type(LaunchFeeHook).creationCode, hookArgs);
        LaunchFeeHook feeHook = new LaunchFeeHook{salt: salt}(
            IPoolManager(poolManager), address(lbp), distributor, DEFAULT_HOOK_FEE
        );
        require(address(feeHook) == hookAddr, "hook addr");

        distributor.setReferrals(address(referrerNft));
        distributor.setHook(address(feeHook));

        address uerc20FactoryAddr = vm.envOr("UERC20_FACTORY", address(0));
        if (block.chainid == 31337 || uerc20FactoryAddr == address(0)) {
            uerc20FactoryAddr = address(new UERC20Factory());
        }

        CcaLaunchFactory factory = new CcaLaunchFactory(
            ILiquidityLauncher(launcherAddr),
            ILBPStrategy(address(lbp)),
            IDistributorFactory(address(ccaFactory)),
            registry,
            distributor,
            feeHook,
            address(compounder),
            uerc20FactoryAddr
        );
        registry.setFactory(address(factory));
        registry.setOperator(vm.envOr("INVITE_OPERATOR", deployer));
        distributor.setRegistrar(address(factory));

        vm.stopBroadcast();

        _writeSidecar(
            deployer,
            address(factory),
            address(lbp),
            launcherAddr,
            address(ccaFactory),
            address(compounder),
            address(distributor),
            address(feeHook),
            address(registry),
            address(referrerNft),
            address(inviteHook),
            uerc20FactoryAddr,
            permit2,
            poolManager,
            positionManager,
            swapRouter,
            startBlock
        );

        console2.log("CcaLaunchFactory", address(factory));
        console2.log("LBPStrategy", address(lbp));
        console2.log("CCAFactory", address(ccaFactory));
        console2.log("UERC20Factory", uerc20FactoryAddr);
        console2.log("FeeDistributor", address(distributor));
        console2.log("LaunchFeeHook", address(feeHook));
        console2.log("InviteRegistry", address(registry));
        console2.log("ReferrerNFT", address(referrerNft));
    }

    function _writeSidecar(
        address deployer,
        address factory,
        address lbpStrategy,
        address launcher,
        address ccaFactory,
        address compounder,
        address distributor,
        address feeHook,
        address registry,
        address referrerNft,
        address inviteHook,
        address uerc20Factory,
        address permit2,
        address poolManager,
        address positionManager,
        address swapRouter,
        uint256 startBlock
    ) internal {
        string memory key = "cca";
        vm.serializeAddress(key, "factory", factory);
        vm.serializeAddress(key, "lbpStrategy", lbpStrategy);
        vm.serializeAddress(key, "launcher", launcher);
        vm.serializeAddress(key, "ccaFactory", ccaFactory);
        vm.serializeAddress(key, "positionRecipient", compounder);
        vm.serializeAddress(key, "feeDistributor", distributor);
        vm.serializeAddress(key, "feeHook", feeHook);
        vm.serializeAddress(key, "inviteRegistry", registry);
        vm.serializeAddress(key, "referrerNft", referrerNft);
        vm.serializeAddress(key, "inviteValidationHook", inviteHook);
        vm.serializeAddress(key, "uerc20Factory", uerc20Factory);
        vm.serializeAddress(key, "permit2", permit2);
        vm.serializeAddress(key, "poolManager", poolManager);
        vm.serializeAddress(key, "positionManager", positionManager);
        vm.serializeAddress(key, "swapRouter", swapRouter);
        string memory ccaJson = vm.serializeUint(key, "startBlock", startBlock);

        string memory name;
        if (block.chainid == 84532) name = "base-sepolia";
        else if (block.chainid == 31337) name = "anvil";
        else name = vm.toString(block.chainid);

        string memory path = string.concat("./deployments/", name, "-cca.json");
        string memory out = string.concat(
            "{\n",
            '  "network": "',
            name,
            '",\n',
            '  "chainId": ',
            vm.toString(block.chainid),
            ",\n",
            '  "deployer": "',
            vm.toString(deployer),
            '",\n',
            '  "cca": ',
            ccaJson,
            "\n}\n"
        );
        vm.writeFile(path, out);
        console2.log("wrote", path);
    }
}
