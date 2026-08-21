# FeeDistributor
[Git Source](https://github.com/prysma-labs/launchpad-contracts/blob/763627c87a2a7224666420def472b110f171f775/src/fee/FeeDistributor.sol)

Accrues hook fees and pays creator / referrers / platform via claim.

Split: 20% creator, 75% referrers (NFT tier weights), 5% platform.


## State Variables
### PLATFORM

```
address public constant PLATFORM = 0xBb6f397d9d8bf128dDa607005397F539B43CD710
```


### CREATOR_BPS

```
uint16 public constant CREATOR_BPS = 2_000
```


### REFERRERS_BPS

```
uint16 public constant REFERRERS_BPS = 7_500
```


### PLATFORM_BPS

```
uint16 public constant PLATFORM_BPS = 500
```


### BPS_DENOM

```
uint16 public constant BPS_DENOM = 10_000
```


### referrals

```
IReferralSource public referrals
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


### referrerPool

```
mapping(PoolId => mapping(address => uint256)) public referrerPool
```


### referrerClaimed

```
mapping(PoolId => mapping(address => mapping(uint256 => uint256))) public referrerClaimed
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

### setReferrals


```
function setReferrals(address referrals_) external;
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

### claimReferrer


```
function claimReferrer(PoolId poolId, address currency, uint256 tokenId) external returns (uint256 amount);
```

### pendingReferrer


```
function pendingReferrer(PoolId poolId, address currency, uint256 tokenId) external view returns (uint256);
```

### _pay


```
function _pay(address currency, address to, uint256 amount) internal;
```

## Events
### ReferralsSet

```
event ReferralsSet(address indexed referrals);
```

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

