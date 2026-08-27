// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {IReferralSource} from "../fee/IReferralSource.sol";

/// @notice Transferable distributor NFT. Minted separately as Recruit (10k).
/// @dev Currently unused for bidding or fees. Referral volume / tier weight
///      remain for a later referral program.
contract ReferrerNFT is ERC721, IReferralSource {
    using Strings for uint256;

    uint256 public constant MAX_SUPPLY = 10_000;
    uint256 public constant SCOUT_MIN = 0.5 ether;
    uint256 public constant PROMOTER_MIN = 1 ether;
    uint256 public constant ADVOCATE_MIN = 5 ether;
    uint256 public constant AMBASSADOR_MIN = 10 ether;
    uint256 public constant PARTNER_MIN = 25 ether;

    uint256 public constant RECRUIT_WEIGHT = 0;
    uint256 public constant SCOUT_WEIGHT = 1;
    uint256 public constant PROMOTER_WEIGHT = 2;
    uint256 public constant ADVOCATE_WEIGHT = 10;
    uint256 public constant AMBASSADOR_WEIGHT = 20;
    uint256 public constant PARTNER_WEIGHT = 35;

    enum Tier {
        None,
        Recruit,
        Scout,
        Promoter,
        Advocate,
        Ambassador,
        Partner
    }

    address public owner;
    address public registry;
    string public baseURI;
    uint256 public nextTokenId = 1;

    mapping(address => uint256) public tokenOfHolder;
    mapping(address => bool) public minted;
    mapping(address => mapping(address => uint256)) public tokenOf;
    mapping(uint256 => address) public issuerOf;
    mapping(uint256 => mapping(address => uint256)) public auctionVolume;
    mapping(uint256 => mapping(address => uint256)) public auctionWeight;
    mapping(uint256 => uint256) public volumeOf;
    mapping(address => uint256) public totalWeightOf;
    mapping(address => uint256[]) private _owned;
    mapping(uint256 => uint256) private _ownedIndex;

    error AlreadySet();
    error NotAuthorized();
    error ZeroAddress();
    error AlreadyMinted();
    error SoldOut();
    error NoNft();

    event RegistrySet(address indexed registry);
    event BaseURISet(string baseURI);
    event Minted(uint256 indexed tokenId, address indexed to);
    event VolumeCredited(uint256 indexed tokenId, address indexed auction, address indexed issuer, uint256 volume, Tier tier);
    event MetadataUpdate(uint256 indexed tokenId);

    constructor(string memory baseURI_) ERC721("Launchpad Distributor", "LDIST") {
        owner = msg.sender;
        baseURI = baseURI_;
    }

    function setRegistry(address registry_) external {
        if (registry != address(0)) revert AlreadySet();
        if (registry_ == address(0)) revert ZeroAddress();
        registry = registry_;
        emit RegistrySet(registry_);
    }

    function setBaseURI(string calldata baseURI_) external {
        if (msg.sender != owner) revert NotAuthorized();
        baseURI = baseURI_;
        emit BaseURISet(baseURI_);
    }

    /// @notice Mint a Recruit NFT to the caller. One per wallet, 10_000 max.
    function mint() external returns (uint256) {
        return _mintTo(msg.sender);
    }

    /// @notice Owner mint for fixtures / allocation.
    function mintTo(address to) external returns (uint256) {
        if (msg.sender != owner) revert NotAuthorized();
        return _mintTo(to);
    }

    function _mintTo(address to) internal returns (uint256 tokenId) {
        if (to == address(0)) revert ZeroAddress();
        if (minted[to] || tokenOfHolder[to] != 0) revert AlreadyMinted();
        if (nextTokenId > MAX_SUPPLY) revert SoldOut();
        tokenId = nextTokenId++;
        minted[to] = true;
        tokenOfHolder[to] = tokenId;
        issuerOf[tokenId] = to;
        _safeMint(to, tokenId);
        emit Minted(tokenId, to);
        emit MetadataUpdate(tokenId);
    }

    /// @notice Bind the issuer's NFT to an auction so later volume credits it.
    function bind(address auction, address issuer) external {
        if (msg.sender != registry) revert NotAuthorized();
        uint256 tokenId = tokenOfHolder[issuer];
        if (tokenId == 0) revert NoNft();
        if (tokenOf[auction][issuer] == 0) tokenOf[auction][issuer] = tokenId;
    }

    function credit(address auction, address issuer, uint128 amount) external {
        if (msg.sender != registry) revert NotAuthorized();
        if (amount == 0) return;

        uint256 tokenId = tokenOf[auction][issuer];
        if (tokenId == 0) {
            tokenId = tokenOfHolder[issuer];
            if (tokenId == 0) return;
            tokenOf[auction][issuer] = tokenId;
        }

        uint256 newVolume = auctionVolume[tokenId][auction] + amount;
        auctionVolume[tokenId][auction] = newVolume;
        volumeOf[tokenId] += amount;

        (, uint256 oldWeight) = tierOf(newVolume - amount);
        (, uint256 newWeight) = tierOf(newVolume);
        if (newWeight != oldWeight) {
            totalWeightOf[auction] = totalWeightOf[auction] - oldWeight + newWeight;
            auctionWeight[tokenId][auction] = newWeight;
            emit MetadataUpdate(tokenId);
        }
        emit VolumeCredited(tokenId, auction, issuer, newVolume, _tier(newVolume));
    }

    function tierOf(uint256 volume) public pure returns (Tier t, uint256 weight) {
        if (volume >= PARTNER_MIN) return (Tier.Partner, PARTNER_WEIGHT);
        if (volume >= AMBASSADOR_MIN) return (Tier.Ambassador, AMBASSADOR_WEIGHT);
        if (volume >= ADVOCATE_MIN) return (Tier.Advocate, ADVOCATE_WEIGHT);
        if (volume >= PROMOTER_MIN) return (Tier.Promoter, PROMOTER_WEIGHT);
        if (volume >= SCOUT_MIN) return (Tier.Scout, SCOUT_WEIGHT);
        return (Tier.Recruit, RECRUIT_WEIGHT);
    }

    function tier(uint256 tokenId) external view returns (Tier) {
        _requireOwned(tokenId);
        return _tier(volumeOf[tokenId]);
    }

    function tierOfAuction(uint256 tokenId, address auction) external view returns (Tier) {
        _requireOwned(tokenId);
        return _tier(auctionVolume[tokenId][auction]);
    }

    function _tier(uint256 volume) internal pure returns (Tier t) {
        (t,) = tierOf(volume);
    }

    function referrerWeight(uint256 tokenId, address auction) external view returns (uint256) {
        return auctionWeight[tokenId][auction];
    }

    function totalReferrerWeight(address auction) external view returns (uint256) {
        return totalWeightOf[auction];
    }

    function referrerOwner(uint256 tokenId) external view returns (address) {
        return ownerOf(tokenId);
    }

    function hasNft(address account) external view returns (bool) {
        return tokenOfHolder[account] != 0;
    }

    function tokensOfOwner(address account) external view returns (uint256[] memory) {
        return _owned[account];
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireOwned(tokenId);
        return string.concat(baseURI, tokenId.toString());
    }

    function _update(address to, uint256 tokenId, address auth) internal override returns (address from) {
        from = super._update(to, tokenId, auth);
        if (from != address(0) && from != to) {
            _removeOwned(from, tokenId);
            if (tokenOfHolder[from] == tokenId) tokenOfHolder[from] = 0;
        }
        if (to != address(0) && from != to) {
            _ownedIndex[tokenId] = _owned[to].length;
            _owned[to].push(tokenId);
            if (tokenOfHolder[to] == 0) tokenOfHolder[to] = tokenId;
        }
    }

    function _removeOwned(address from, uint256 tokenId) internal {
        uint256[] storage list = _owned[from];
        uint256 i = _ownedIndex[tokenId];
        uint256 last = list.length - 1;
        if (i != last) {
            uint256 lastId = list[last];
            list[i] = lastId;
            _ownedIndex[lastId] = i;
        }
        list.pop();
    }
}
