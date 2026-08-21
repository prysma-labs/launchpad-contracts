# ReferrerNFT
[Git Source](https://github.com/prysma-labs/launchpad-contracts/blob/763627c87a2a7224666420def472b110f171f775/src/nft/ReferrerNFT.sol)

**Inherits:**
ERC721, [IReferralSource](IReferralSource.md)

Transferable distributor NFT. Minted separately as Recruit (10k).

Holding a token makes you a distributor on every auction. Referred
volume is tracked per auction; Scout+ weight earns hook-fee share.
Recruit has weight 0 and does not accrue fees.


## State Variables
### MAX_SUPPLY

```
uint256 public constant MAX_SUPPLY = 10_000
```


### SCOUT_MIN

```
uint256 public constant SCOUT_MIN = 0.5 ether
```


### PROMOTER_MIN

```
uint256 public constant PROMOTER_MIN = 1 ether
```


### ADVOCATE_MIN

```
uint256 public constant ADVOCATE_MIN = 5 ether
```


### AMBASSADOR_MIN

```
uint256 public constant AMBASSADOR_MIN = 10 ether
```


### PARTNER_MIN

```
uint256 public constant PARTNER_MIN = 25 ether
```


### RECRUIT_WEIGHT

```
uint256 public constant RECRUIT_WEIGHT = 0
```


### SCOUT_WEIGHT

```
uint256 public constant SCOUT_WEIGHT = 1
```


### PROMOTER_WEIGHT

```
uint256 public constant PROMOTER_WEIGHT = 2
```


### ADVOCATE_WEIGHT

```
uint256 public constant ADVOCATE_WEIGHT = 10
```


### AMBASSADOR_WEIGHT

```
uint256 public constant AMBASSADOR_WEIGHT = 20
```


### PARTNER_WEIGHT

```
uint256 public constant PARTNER_WEIGHT = 35
```


### owner

```
address public owner
```


### registry

```
address public registry
```


### baseURI

```
string public baseURI
```


### nextTokenId

```
uint256 public nextTokenId = 1
```


### tokenOfHolder

```
mapping(address => uint256) public tokenOfHolder
```


### minted

```
mapping(address => bool) public minted
```


### tokenOf

```
mapping(address => mapping(address => uint256)) public tokenOf
```


### issuerOf

```
mapping(uint256 => address) public issuerOf
```


### auctionVolume

```
mapping(uint256 => mapping(address => uint256)) public auctionVolume
```


### auctionWeight

```
mapping(uint256 => mapping(address => uint256)) public auctionWeight
```


### volumeOf

```
mapping(uint256 => uint256) public volumeOf
```


### totalWeightOf

```
mapping(address => uint256) public totalWeightOf
```


### _owned

```
mapping(address => uint256[]) private _owned
```


### _ownedIndex

```
mapping(uint256 => uint256) private _ownedIndex
```


## Functions
### constructor


```
constructor(string memory baseURI_) ERC721("Launchpad Distributor", "LDIST");
```

### setRegistry


```
function setRegistry(address registry_) external;
```

### setBaseURI


```
function setBaseURI(string calldata baseURI_) external;
```

### mint

Mint a Recruit NFT to the caller. One per wallet, 10_000 max.


```
function mint() external returns (uint256);
```

### mintTo

Owner mint for fixtures / allocation.


```
function mintTo(address to) external returns (uint256);
```

### _mintTo


```
function _mintTo(address to) internal returns (uint256 tokenId);
```

### bind

Bind the issuer's NFT to an auction so later volume credits it.


```
function bind(address auction, address issuer) external;
```

### credit


```
function credit(address auction, address issuer, uint128 amount) external;
```

### tierOf


```
function tierOf(uint256 volume) public pure returns (Tier t, uint256 weight);
```

### tier


```
function tier(uint256 tokenId) external view returns (Tier);
```

### tierOfAuction


```
function tierOfAuction(uint256 tokenId, address auction) external view returns (Tier);
```

### _tier


```
function _tier(uint256 volume) internal pure returns (Tier t);
```

### referrerWeight


```
function referrerWeight(uint256 tokenId, address auction) external view returns (uint256);
```

### totalReferrerWeight


```
function totalReferrerWeight(address auction) external view returns (uint256);
```

### referrerOwner


```
function referrerOwner(uint256 tokenId) external view returns (address);
```

### hasNft


```
function hasNft(address account) external view returns (bool);
```

### tokensOfOwner


```
function tokensOfOwner(address account) external view returns (uint256[] memory);
```

### tokenURI


```
function tokenURI(uint256 tokenId) public view override returns (string memory);
```

### _update


```
function _update(address to, uint256 tokenId, address auth) internal override returns (address from);
```

### _removeOwned


```
function _removeOwned(address from, uint256 tokenId) internal;
```

## Events
### RegistrySet

```
event RegistrySet(address indexed registry);
```

### BaseURISet

```
event BaseURISet(string baseURI);
```

### Minted

```
event Minted(uint256 indexed tokenId, address indexed to);
```

### VolumeCredited

```
event VolumeCredited(
    uint256 indexed tokenId, address indexed auction, address indexed issuer, uint256 volume, Tier tier
);
```

### MetadataUpdate

```
event MetadataUpdate(uint256 indexed tokenId);
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

### ZeroAddress

```
error ZeroAddress();
```

### AlreadyMinted

```
error AlreadyMinted();
```

### SoldOut

```
error SoldOut();
```

### NoNft

```
error NoNft();
```

## Enums
### Tier

```
enum Tier {
    None,
    Recruit,
    Scout,
    Promoter,
    Advocate,
    Ambassador,
    Partner
}
```

