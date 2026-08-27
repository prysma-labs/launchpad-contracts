# FeeDistributor
[Git Source](https://github.com/prysma-labs/launchpad-contracts/blob/5581699504b49b43ecb36ba097021e1d689dd2d0/src/fee/FeeDistributor.sol)

Accrues hook fees and pays creator / platform via claim.

Split: 95% creator, 5% platform.


## State Variables
### PLATFORM

```
address public constant PLATFORM = 0xBb6f397d9d8bf128dDa607005397F539B43CD710
```


### CREATOR_BPS

```
uint16 public constant CREATOR_BPS = 9_500
```


### PLATFORM_BPS

```
uint16 public constant PLATFORM_BPS = 500
```


### BPS_DENOM

```
uint16 public constant BPS_DENOM = 10_000
```


### hook

```
address public hook
```


### registrar

```
address public registrar
```


### pools

```
mapping(PoolId => PoolInfo) public pools
```


### creatorOwed

```
mapping(PoolId => mapping(address => uint256)) public creatorOwed
```


### platformOwed

```
mapping(PoolId => mapping(address => uint256)) public platformOwed
```


## Functions
### onlyHook


```
modifier onlyHook() ;
```

### receive


```
receive() external payable;
```

### setHook


```
function setHook(address hook_) external;
```

### setRegistrar


```
function setRegistrar(address registrar_) external;
```

### registerPool


```
function registerPool(PoolId poolId, address auction, address creator) external;
```

### notifyFee


```
function notifyFee(PoolId poolId, address currency, uint256 amount) external payable onlyHook;
```

### claimCreator


```
function claimCreator(PoolId poolId, address currency) external returns (uint256 amount);
```

### claimPlatform


```
function claimPlatform(PoolId poolId, address currency) external returns (uint256 amount);
```

### _pay


```
function _pay(address currency, address to, uint256 amount) internal;
```

## Events
### HookSet

```
event HookSet(address indexed hook);
```

### RegistrarSet

```
event RegistrarSet(address indexed registrar);
```

### PoolRegistered

```
event PoolRegistered(PoolId indexed poolId, address indexed auction, address indexed creator);
```

### FeeNotified

```
event FeeNotified(PoolId indexed poolId, address indexed currency, uint256 amount);
```

### Claimed

```
event Claimed(PoolId indexed poolId, address indexed currency, address indexed to, uint256 amount);
```

## Errors
### NotAuthorized

```
error NotAuthorized();
```

### NotHook

```
error NotHook();
```

### NotRegistered

```
error NotRegistered();
```

### NothingToClaim

```
error NothingToClaim();
```

### InvalidAmount

```
error InvalidAmount();
```

### TransferFailed

```
error TransferFailed();
```

### AlreadySet

```
error AlreadySet();
```

## Structs
### PoolInfo

```
struct PoolInfo {
    address creator;
    address auction;
    bool registered;
}
```
