# InviteValidationHook
[Git Source](https://github.com/prysma-labs/launchpad-contracts/blob/3528c3a546aa4da6c3de1ec8f4ab563f3a4a2c69/src/invite/InviteValidationHook.sol)

**Inherits:**
IValidationHook

CCA bid validation: require a valid invite code in hookData.


## State Variables
### registry

```
InviteRegistry public immutable registry
```


## Functions
### constructor


```
constructor(InviteRegistry registry_) ;
```

### validate

Validate a bid

hookData is 32 bytes (inbound invite) or 64 bytes (inbound + ignored outbound).


```
function validate(uint256, uint128 amount, address owner, address, bytes calldata hookData) external;
```
**Parameters**

|Name|Type|Description|
|----|----|-----------|
|`<none>`|`uint256`||
|`amount`|`uint128`|The amount of the bid|
|`owner`|`address`|The owner of the bid|
|`<none>`|`address`||
|`hookData`|`bytes`|Additional data to pass to the hook required for validation|


## Errors
### InvalidHookData

```
error InvalidHookData();
```

