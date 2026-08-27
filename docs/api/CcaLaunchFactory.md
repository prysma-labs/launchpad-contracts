# CcaLaunchFactory
[Git Source](https://github.com/prysma-labs/launchpad-contracts/blob/5581699504b49b43ecb36ba097021e1d689dd2d0/src/strategy/CcaLaunchFactory.sol)

Creates a UERC20 + CCA/LBP distribution with fee hook.


## State Variables
### DEFAULT_POOL_LP_FEE
Protocol-fixed. Not creator-configurable.


```
uint24 public constant DEFAULT_POOL_LP_FEE = 1_000
```


### DEFAULT_HOOK_FEE
Protocol-fixed. Not creator-configurable.


```
uint24 public constant DEFAULT_HOOK_FEE = 4_000
```


### DEFAULT_TICK_SPACING

```
int24 public constant DEFAULT_TICK_SPACING = 60
```


### DEFAULT_AUCTION_SUPPLY_BPS

```
uint16 public constant DEFAULT_AUCTION_SUPPLY_BPS = 5_000
```


### DEFAULT_AUCTION_TICK_SPACING
FROGE Crowd Launch tick (Q96). ~5.24e-12 ETH/token.


```
uint256 public constant DEFAULT_AUCTION_TICK_SPACING = 0x05c37a5313eae06f
```


### DEFAULT_FLOOR_PRICE
FROGE Crowd Launch floor (Q96). ~5.24e-10 ETH/token.


```
uint256 public constant DEFAULT_FLOOR_PRICE = 0x2405bc873c7bfab5c
```


### UNSOLD_TOKENS_RECIPIENT
Unsold auction tokens + unused reserved LP after migrate, matching Uniswap CCA/LBP.


```
address public constant UNSOLD_TOKENS_RECIPIENT = 0x000000000000000000000000000000000000dEaD
```


### TOTAL_SUPPLY

```
uint128 public constant TOTAL_SUPPLY = 1_000_000_000 ether
```


### launcher

```
ILiquidityLauncher public immutable launcher
```


### lbpStrategy

```
ILBPStrategy public immutable lbpStrategy
```


### ccaFactory

```
IDistributorFactory public immutable ccaFactory
```


### distributor

```
FeeDistributor public immutable distributor
```


### feeHook

```
LaunchFeeHook public immutable feeHook
```


### positionRecipient

```
address public immutable positionRecipient
```


### uerc20Factory

```
address public immutable uerc20Factory
```


### launchCount

```
uint256 public launchCount
```


### launches

```
mapping(uint256 => Launch) public launches
```


### launchIdByToken

```
mapping(address => uint256) public launchIdByToken
```


### launchIdByAuction

```
mapping(address => uint256) public launchIdByAuction
```


## Functions
### constructor


```
constructor(
    ILiquidityLauncher launcher_,
    ILBPStrategy lbpStrategy_,
    IDistributorFactory ccaFactory_,
    FeeDistributor distributor_,
    LaunchFeeHook feeHook_,
    address positionRecipient_,
    address uerc20Factory_
) ;
```

### createLaunch


```
function createLaunch(CreateParams calldata params)
    external
    returns (uint256 launchId, address token, address auction);
```

### getLaunch


```
function getLaunch(uint256 launchId) external view returns (Launch memory);
```

### _buildSteps


```
function _buildSteps(uint64 auctionBlocks) internal pure returns (bytes memory steps);
```

### _poolKey


```
function _poolKey(address currency, address token, uint24 fee, address hook)
    internal
    pure
    returns (PoolKey memory key);
```

## Events
### LaunchCreated

```
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
```

## Errors
### EmptyName

```
error EmptyName();
```

### InvalidDuration

```
error InvalidDuration();
```

### InvalidSupplyBps

```
error InvalidSupplyBps();
```

### NeedXVerification

```
error NeedXVerification();
```

## Structs
### Metadata

```
struct Metadata {
    string name;
    string symbol;
    string description;
    string image;
    string website;
    /// @dev Required opaque bytes; expected to include xVerificationToken JSON.
    bytes extraData;
}
```

### CreateParams

```
struct CreateParams {
    Metadata metadata;
    uint64 auctionBlocks;
    uint128 minRaise;
    uint16 auctionSupplyBps;
    bytes32 salt;
}
```

### Launch

```
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
```

