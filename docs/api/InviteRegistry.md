# InviteRegistry
[Git Source](https://github.com/prysma-labs/launchpad-contracts/blob/5581699504b49b43ecb36ba097021e1d689dd2d0/src/invite/InviteRegistry.sol)

Invite codes and referral attribution.

Not wired into launches. Auctions are open; hook fees go to the creator.
Kept for a later referral program.


## State Variables
### CREATE_INVITES_TYPEHASH

```
bytes32 private constant CREATE_INVITES_TYPEHASH =
    keccak256("CreateInvites(address auction,address issuer,bytes32 codesHash,uint256 nonce,uint256 deadline)")
```


### EIP712_DOMAIN_TYPEHASH

```
bytes32 private constant EIP712_DOMAIN_TYPEHASH =
    keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)")
```


### NAME_HASH

```
bytes32 private constant NAME_HASH = keccak256("InviteRegistry")
```


### VERSION_HASH

```
bytes32 private constant VERSION_HASH = keccak256("1")
```


### factory
CcaLaunchFactory — only caller allowed to registerAuction.


```
address public factory
```


### validationHook

```
address public validationHook
```


### operator
Platform signer. Only this address can mint invites or authorize minting.


```
address public operator
```


### referrerNft

```
ReferrerNFT public referrerNft
```


### INITIAL_CHAIN_ID

```
uint256 private immutable INITIAL_CHAIN_ID
```


### INITIAL_DOMAIN_SEPARATOR

```
bytes32 private immutable INITIAL_DOMAIN_SEPARATOR
```


### creatorOf

```
mapping(address => address) public creatorOf
```


### auctionOfToken

```
mapping(address => address) public auctionOfToken
```


### inviteIssuer

```
mapping(address => mapping(bytes32 => address)) public inviteIssuer
```


### participated

```
mapping(address => mapping(address => bool)) public participated
```


### referrerOf

```
mapping(address => mapping(address => address)) public referrerOf
```


### invitesCreated

```
mapping(address => uint256) public invitesCreated
```


### nonces

```
mapping(address => uint256) public nonces
```


## Functions
### constructor


```
constructor() ;
```

### DOMAIN_SEPARATOR


```
function DOMAIN_SEPARATOR() public view returns (bytes32);
```

### setFactory


```
function setFactory(address factory_) external;
```

### setValidationHook


```
function setValidationHook(address hook_) external;
```

### setOperator


```
function setOperator(address operator_) external;
```

### setReferrerNft


```
function setReferrerNft(address nft_) external;
```

### registerAuction


```
function registerAuction(address auction, address token, address creator) external;
```

### seedInvites


```
function seedInvites(address auction, address issuer, bytes32[] calldata codes) external;
```

### createInvitesFor

Platform-only mint. `issuer` receives referral credit for these codes.


```
function createInvitesFor(address auction, address issuer, bytes32[] calldata codes) external;
```

### createInvites

Mint codes for `msg.sender` with a platform EIP-712 authorization.


```
function createInvites(address auction, bytes32[] calldata codes, uint256 deadline, bytes calldata signature)
    external;
```

### _requireDistributor


```
function _requireDistributor(address auction, address issuer) internal;
```

### _holdsNft


```
function _holdsNft(address account) internal view returns (bool);
```

### _createInvites


```
function _createInvites(address auction, address issuer, bytes32[] calldata codes) internal;
```

### _createInvite


```
function _createInvite(address auction, address issuer, bytes32 code) internal;
```

### useInvite

Called by InviteValidationHook during CCA submitBid.

First bid binds the bidder to the invite issuer. Later bids add volume
to that same referrer without re-checking the code.
The auction creator may bid with any/no code; volume is not attributed.


```
function useInvite(address auction, address bidder, bytes32 code, bytes32, uint128 amount) external;
```

### _hashCreateInvites


```
function _hashCreateInvites(
    address auction,
    address issuer,
    bytes32[] calldata codes,
    uint256 nonce,
    uint256 deadline
) internal view returns (bytes32);
```

### _computeDomainSeparator


```
function _computeDomainSeparator() internal view returns (bytes32);
```

### _recover


```
function _recover(bytes32 digest, bytes calldata signature) internal pure returns (address);
```

## Events
### FactorySet

```
event FactorySet(address indexed factory);
```

### ValidationHookSet

```
event ValidationHookSet(address indexed hook);
```

### OperatorSet

```
event OperatorSet(address indexed operator);
```

### ReferrerNftSet

```
event ReferrerNftSet(address indexed nft);
```

### AuctionRegistered

```
event AuctionRegistered(address indexed auction, address indexed token, address indexed creator);
```

### InviteCreated

```
event InviteCreated(address indexed auction, bytes32 indexed code, address indexed issuer);
```

### InviteUsed

```
event InviteUsed(
    address indexed auction, address indexed bidder, address indexed referrer, bytes32 code, uint128 amount
);
```

## Errors
### AlreadySet

```
error AlreadySet();
```

### NotAuthorized

```
error NotAuthorized();
```

### InvalidInvite

```
error InvalidInvite();
```

### InviteExists

```
error InviteExists();
```

### ZeroAddress

```
error ZeroAddress();
```

### Expired

```
error Expired();
```

### InvalidSignature

```
error InvalidSignature();
```

### NotDistributor

```
error NotDistributor();
```

