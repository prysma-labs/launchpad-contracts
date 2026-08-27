// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ReferrerNFT} from "../nft/ReferrerNFT.sol";

/// @notice Invite codes and referral attribution.
/// @dev Not wired into launches. Auctions are open; hook fees go to the creator.
///      Kept for a later referral program.
contract InviteRegistry {
    bytes32 private constant CREATE_INVITES_TYPEHASH = keccak256(
        "CreateInvites(address auction,address issuer,bytes32 codesHash,uint256 nonce,uint256 deadline)"
    );
    bytes32 private constant EIP712_DOMAIN_TYPEHASH =
        keccak256("EIP712Domain(string name,string version,uint256 chainId,address verifyingContract)");
    bytes32 private constant NAME_HASH = keccak256("InviteRegistry");
    bytes32 private constant VERSION_HASH = keccak256("1");

    /// @dev CcaLaunchFactory — only caller allowed to registerAuction.
    address public factory;
    address public validationHook;
    /// @dev Platform signer. Only this address can mint invites or authorize minting.
    address public operator;
    ReferrerNFT public referrerNft;

    uint256 private immutable INITIAL_CHAIN_ID;
    bytes32 private immutable INITIAL_DOMAIN_SEPARATOR;

    mapping(address => address) public creatorOf;
    mapping(address => address) public auctionOfToken;
    mapping(address => mapping(bytes32 => address)) public inviteIssuer;
    mapping(address => mapping(address => bool)) public participated;
    mapping(address => mapping(address => address)) public referrerOf;
    mapping(address => uint256) public invitesCreated;
    mapping(address => uint256) public nonces;

    error AlreadySet();
    error NotAuthorized();
    error InvalidInvite();
    error InviteExists();
    error ZeroAddress();
    error Expired();
    error InvalidSignature();
    error NotDistributor();

    event FactorySet(address indexed factory);
    event ValidationHookSet(address indexed hook);
    event OperatorSet(address indexed operator);
    event ReferrerNftSet(address indexed nft);
    event AuctionRegistered(
        address indexed auction,
        address indexed token,
        address indexed creator
    );
    event InviteCreated(
        address indexed auction,
        bytes32 indexed code,
        address indexed issuer
    );
    event InviteUsed(
        address indexed auction,
        address indexed bidder,
        address indexed referrer,
        bytes32 code,
        uint128 amount
    );

    constructor() {
        INITIAL_CHAIN_ID = block.chainid;
        INITIAL_DOMAIN_SEPARATOR = _computeDomainSeparator();
    }

    function DOMAIN_SEPARATOR() public view returns (bytes32) {
        return block.chainid == INITIAL_CHAIN_ID
            ? INITIAL_DOMAIN_SEPARATOR
            : _computeDomainSeparator();
    }

    function setFactory(address factory_) external {
        if (factory != address(0)) revert AlreadySet();
        if (factory_ == address(0)) revert ZeroAddress();
        factory = factory_;
        emit FactorySet(factory_);
    }

    function setValidationHook(address hook_) external {
        if (validationHook != address(0)) revert AlreadySet();
        if (hook_ == address(0)) revert ZeroAddress();
        validationHook = hook_;
        emit ValidationHookSet(hook_);
    }

    function setOperator(address operator_) external {
        if (operator != address(0)) revert AlreadySet();
        if (operator_ == address(0)) revert ZeroAddress();
        operator = operator_;
        emit OperatorSet(operator_);
    }

    function setReferrerNft(address nft_) external {
        if (address(referrerNft) != address(0)) revert AlreadySet();
        if (nft_ == address(0)) revert ZeroAddress();
        referrerNft = ReferrerNFT(nft_);
        emit ReferrerNftSet(nft_);
    }

    function registerAuction(
        address auction,
        address token,
        address creator
    ) external {
        if (msg.sender != factory) revert NotAuthorized();
        if (
            auction == address(0) ||
            token == address(0) ||
            creator == address(0)
        ) revert ZeroAddress();
        creatorOf[auction] = creator;
        auctionOfToken[token] = auction;
        emit AuctionRegistered(auction, token, creator);
    }

    function seedInvites(
        address auction,
        address issuer,
        bytes32[] calldata codes
    ) external {
        if (msg.sender != factory) revert NotAuthorized();
        _requireDistributor(auction, issuer);
        _createInvites(auction, issuer, codes);
    }

    /// @notice Platform-only mint. `issuer` receives referral credit for these codes.
    function createInvitesFor(
        address auction,
        address issuer,
        bytes32[] calldata codes
    ) external {
        if (msg.sender != operator) revert NotAuthorized();
        if (creatorOf[auction] == address(0)) revert NotAuthorized();
        if (issuer == address(0)) revert ZeroAddress();
        _requireDistributor(auction, issuer);
        _createInvites(auction, issuer, codes);
    }

    /// @notice Mint codes for `msg.sender` with a platform EIP-712 authorization.
    function createInvites(
        address auction,
        bytes32[] calldata codes,
        uint256 deadline,
        bytes calldata signature
    ) external {
        if (block.timestamp > deadline) revert Expired();
        if (creatorOf[auction] == address(0)) revert NotAuthorized();
        _requireDistributor(auction, msg.sender);
        uint256 nonce = nonces[msg.sender]++;
        bytes32 digest = _hashCreateInvites(auction, msg.sender, codes, nonce, deadline);
        if (_recover(digest, signature) != operator) revert InvalidSignature();
        _createInvites(auction, msg.sender, codes);
    }

    function _requireDistributor(address auction, address issuer) internal {
        if (!_holdsNft(issuer)) revert NotDistributor();
        referrerNft.bind(auction, issuer);
    }

    function _holdsNft(address account) internal view returns (bool) {
        return address(referrerNft) != address(0) && referrerNft.hasNft(account);
    }

    function _createInvites(
        address auction,
        address issuer,
        bytes32[] calldata codes
    ) internal {
        for (uint256 i = 0; i < codes.length; i++) {
            _createInvite(auction, issuer, codes[i]);
        }
    }

    function _createInvite(
        address auction,
        address issuer,
        bytes32 code
    ) internal {
        if (code == bytes32(0)) revert InvalidInvite();
        if (inviteIssuer[auction][code] != address(0)) revert InviteExists();
        inviteIssuer[auction][code] = issuer;
        invitesCreated[auction]++;
        emit InviteCreated(auction, code, issuer);
    }

    /// @notice Called by InviteValidationHook during CCA submitBid.
    /// @dev First bid binds the bidder to the invite issuer. Later bids add volume
    /// to that same referrer without re-checking the code.
    /// The auction creator may bid with any/no code; volume is not attributed.
    function useInvite(
        address auction,
        address bidder,
        bytes32 code,
        bytes32,
        uint128 amount
    ) external {
        if (msg.sender != validationHook) revert NotAuthorized();
        if (creatorOf[auction] == address(0)) revert InvalidInvite();

        if (bidder == creatorOf[auction]) {
            participated[auction][bidder] = true;
            emit InviteUsed(auction, bidder, address(0), code, amount);
            return;
        }

        address issuer = referrerOf[auction][bidder];
        if (issuer == address(0)) {
            issuer = inviteIssuer[auction][code];
            if (issuer == address(0) || issuer == bidder) {
                if (_holdsNft(bidder)) {
                    participated[auction][bidder] = true;
                    emit InviteUsed(auction, bidder, address(0), code, amount);
                    return;
                }
                revert InvalidInvite();
            }
            referrerOf[auction][bidder] = issuer;
            participated[auction][bidder] = true;
        }

        if (amount != 0 && issuer != creatorOf[auction] && address(referrerNft) != address(0)) {
            referrerNft.credit(auction, issuer, amount);
        }
        emit InviteUsed(auction, bidder, issuer, code, amount);
    }

    function _hashCreateInvites(
        address auction,
        address issuer,
        bytes32[] calldata codes,
        uint256 nonce,
        uint256 deadline
    ) internal view returns (bytes32) {
        return keccak256(
            abi.encodePacked(
                "\x19\x01",
                DOMAIN_SEPARATOR(),
                keccak256(
                    abi.encode(
                        CREATE_INVITES_TYPEHASH,
                        auction,
                        issuer,
                        keccak256(abi.encode(codes)),
                        nonce,
                        deadline
                    )
                )
            )
        );
    }

    function _computeDomainSeparator() internal view returns (bytes32) {
        return keccak256(
            abi.encode(
                EIP712_DOMAIN_TYPEHASH,
                NAME_HASH,
                VERSION_HASH,
                block.chainid,
                address(this)
            )
        );
    }

    function _recover(bytes32 digest, bytes calldata signature) internal pure returns (address) {
        if (signature.length != 65) revert InvalidSignature();
        bytes32 r;
        bytes32 s;
        uint8 v;
        assembly ("memory-safe") {
            r := calldataload(signature.offset)
            s := calldataload(add(signature.offset, 32))
            v := byte(0, calldataload(add(signature.offset, 64)))
        }
        if (v < 27) v += 27;
        address recovered = ecrecover(digest, v, r, s);
        if (recovered == address(0)) revert InvalidSignature();
        return recovered;
    }
}
