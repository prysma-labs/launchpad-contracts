# LaunchFeeHook
[Git Source](https://github.com/prysma-labs/launchpad-contracts/blob/3528c3a546aa4da6c3de1ec8f4ab563f3a4a2c69/src/fee/LaunchFeeHook.sol)

**Inherits:**
InitializerHook, IUnlockCallback

LBP-compatible InitializerHook that charges a hook fee in ETH into FeeDistributor.

ETH is always currency0. Buys take 0.4% of specified ETH in beforeSwap; sells take 0.4% of
unspecified ETH out in afterSwap. Token fees are never taken.


## State Variables
### MAX_HOOK_FEE

```
uint24 internal constant MAX_HOOK_FEE = 1e6
```


### distributor

```
FeeDistributor public immutable distributor
```


### defaultHookFee

```
uint24 public immutable defaultHookFee
```


### hookFeeOf

```
mapping(PoolId => uint24) public hookFeeOf
```


### feeConfigured

```
mapping(PoolId => bool) public feeConfigured
```


## Functions
### constructor


```
constructor(IPoolManager poolManager_, address authorized_, FeeDistributor distributor_, uint24 defaultHookFee_)
    InitializerHook(poolManager_, authorized_);
```

### setPoolHookFee


```
function setPoolHookFee(PoolId poolId, uint24 fee) external;
```

### getHookPermissions


```
function getHookPermissions() public pure override returns (Hooks.Permissions memory);
```

### _beforeSwap

When ETH is specified (exact-in buy / exact-out sell), take 0.4% of that ETH.


```
function _beforeSwap(address sender, PoolKey calldata key, SwapParams calldata params, bytes calldata)
    internal
    override
    returns (bytes4, BeforeSwapDelta, uint24);
```

### _afterSwap

When ETH is unspecified (exact-in sell / exact-out buy), take 0.4% of ETH out/in.


```
function _afterSwap(
    address sender,
    PoolKey calldata key,
    SwapParams calldata params,
    BalanceDelta delta,
    bytes calldata
) internal override returns (bytes4, int128);
```

### harvest


```
function harvest(PoolKey calldata key) external;
```

### unlockCallback


```
function unlockCallback(bytes calldata data) external onlyPoolManager returns (bytes memory);
```

### _ethIsSpecified

Specified currency is currency0 when (amountSpecified < 0) == zeroForOne.


```
function _ethIsSpecified(PoolKey calldata key, SwapParams calldata params) internal pure returns (bool);
```

### _ethFee


```
function _ethFee(PoolId poolId, uint256 ethAmount) internal view returns (uint256);
```

### receive


```
receive() external payable;
```

## Events
### PoolHookFeeSet

```
event PoolHookFeeSet(PoolId indexed poolId, uint24 fee);
```

### HookFee

```
event HookFee(bytes32 indexed poolId, address indexed sender, uint128 feeAmount0, uint128 feeAmount1);
```

## Errors
### InvalidFee

```
error InvalidFee();
```

### HookFeeTooLarge

```
error HookFeeTooLarge();
```

