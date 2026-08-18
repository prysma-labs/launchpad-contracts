// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC721} from "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

import {IReferralSource} from "../fee/IReferralSource.sol";

/// @notice Transferable distributor claim NFT. Minted at Scout; art/tier upgrade with volume.
contract ReferrerNFT is ERC721, IReferralSource {
    using Strings for uint256;

    uint256 public constant SCOUT_MIN = 0.5 ether;
    uint256 public constant PROMOTER_MIN = 1 ether;
    uint256 public constant ADVOCATE_MIN = 5 ether;
    uint256 public constant AMBASSADOR_MIN = 10 ether;
    uint256 public constant PARTNER_MIN = 25 ether;

    uint256 public constant SCOUT_WEIGHT = 1;
    uint256 public constant PROMOTER_WEIGHT = 2;
    uint256 public constant ADVOCATE_WEIGHT = 10;
    uint256 public constant AMBASSADOR_WEIGHT = 20;
    uint256 public constant PARTNER_WEIGHT = 35;

    enum Tier {
        None,
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

    mapping(address => mapping(address => uint256)) public pendingVolume;
    mapping(address => mapping(address => uint256)) public tokenOf;
    mapping(uint256 => address) public auctionOf;
    mapping(uint256 => address) public issuerOf;
    mapping(uint256 => uint256) public volumeOf;
    mapping(uint256 => uint256) public weightOf;
    mapping(address => uint256) public totalWeightOf;
    mapping(address => uint256[]) private _owned;
    mapping(uint256 => uint256) private _ownedIndex;

    error AlreadySet();
    error NotAuthorized();
    error ZeroAddress();

    event RegistrySet(address indexed registry);
    event BaseURISet(string baseURI);
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

    function credit(address auction, address issuer, uint128 amount) external {
        if (msg.sender != registry) revert NotAuthorized();
        if (amount == 0) return;

        uint256 tokenId = tokenOf[auction][issuer];
        if (tokenId == 0) {
            uint256 pending = pendingVolume[auction][issuer] + amount;
            pendingVolume[auction][issuer] = pending;
            if (pending < SCOUT_MIN) return;
            pendingVolume[auction][issuer] = 0;
            _mintDistributor(auction, issuer, pending);
            return;
        }

        _addVolume(tokenId, amount);
    }

    function _mintDistributor(address auction, address issuer, uint256 volume) internal {
        uint256 tokenId = nextTokenId++;
        tokenOf[auction][issuer] = tokenId;
        auctionOf[tokenId] = auction;
        issuerOf[tokenId] = issuer;
        volumeOf[tokenId] = volume;
        (, uint256 weight) = tierOf(volume);
        weightOf[tokenId] = weight;
        totalWeightOf[auction] += weight;
        _safeMint(issuer, tokenId);
        emit VolumeCredited(tokenId, auction, issuer, volume, _tier(volume));
        emit MetadataUpdate(tokenId);
    }

    function _addVolume(uint256 tokenId, uint128 amount) internal {
        uint256 oldVolume = volumeOf[tokenId];
        uint256 newVolume = oldVolume + amount;
        volumeOf[tokenId] = newVolume;
        (, uint256 oldWeight) = tierOf(oldVolume);
        (, uint256 newWeight) = tierOf(newVolume);
        if (newWeight != oldWeight) {
            address auction = auctionOf[tokenId];
            totalWeightOf[auction] = totalWeightOf[auction] - oldWeight + newWeight;
            weightOf[tokenId] = newWeight;
            emit MetadataUpdate(tokenId);
        }
        emit VolumeCredited(tokenId, auctionOf[tokenId], issuerOf[tokenId], newVolume, _tier(newVolume));
    }

    function tierOf(uint256 volume) public pure returns (Tier t, uint256 weight) {
        if (volume >= PARTNER_MIN) return (Tier.Partner, PARTNER_WEIGHT);
        if (volume >= AMBASSADOR_MIN) return (Tier.Ambassador, AMBASSADOR_WEIGHT);
        if (volume >= ADVOCATE_MIN) return (Tier.Advocate, ADVOCATE_WEIGHT);
        if (volume >= PROMOTER_MIN) return (Tier.Promoter, PROMOTER_WEIGHT);
        if (volume >= SCOUT_MIN) return (Tier.Scout, SCOUT_WEIGHT);
        return (Tier.None, 0);
    }

    function tier(uint256 tokenId) external view returns (Tier) {
        return _tier(volumeOf[tokenId]);
    }

    function _tier(uint256 volume) internal pure returns (Tier t) {
        (t,) = tierOf(volume);
    }

    function referrerWeight(uint256 tokenId) external view returns (uint256) {
        return weightOf[tokenId];
    }

    function totalReferrerWeight(address auction) external view returns (uint256) {
        return totalWeightOf[auction];
    }

    function referrerAuction(uint256 tokenId) external view returns (address) {
        return auctionOf[tokenId];
    }

    function referrerOwner(uint256 tokenId) external view returns (address) {
        return ownerOf(tokenId);
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
        if (from != address(0) && from != to) _removeOwned(from, tokenId);
        if (to != address(0) && from != to) {
            _ownedIndex[tokenId] = _owned[to].length;
            _owned[to].push(tokenId);
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
