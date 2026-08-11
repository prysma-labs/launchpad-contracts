// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IReferralSource} from "../fee/IReferralSource.sol";

/// @notice Invite codes and referral weights.
/// @dev Deployed once per chain; shared across all auctions (keyed by auction address).
/// Authority for bid gating + fee attribution (offchain DB is UX-only):
/// - Factory registers each auction and seeds creator invite codes (bytes32 → issuer).
/// - InviteValidationHook calls useInvite on first CCA bid; unknown/self invites revert.
/// - Codes are reusable; only the first participation per bidder credits the issuer.
/// - Creator or prior participants may createInvites; FeeDistributor reads referral counts.
contract InviteRegistry is IReferralSource {
    /// @dev CcaLaunchFactory — only caller allowed to registerAuction / seedInvites.
    address public factory;
    address public validationHook;

    mapping(address => address) public creatorOf;
    mapping(address => address) public auctionOfToken;
    mapping(address => mapping(bytes32 => address)) public inviteIssuer;
    mapping(address => mapping(address => bool)) public participated;
    mapping(address => mapping(address => uint256)) public referralCountOf;
    mapping(address => uint256) public totalReferralCountOf;
    mapping(address => uint256) public invitesCreated;

    error AlreadySet();
    error NotAuthorized();
    error InvalidInvite();
    error InviteExists();
    error ZeroAddress();

    event FactorySet(address indexed factory);
    event ValidationHookSet(address indexed hook);
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
        bytes32 code
    );

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
        _createInvites(auction, issuer, codes);
    }

    function createInvites(address auction, bytes32[] calldata codes) external {
        if (creatorOf[auction] == address(0)) revert NotAuthorized();
        bool isCreator = msg.sender == creatorOf[auction];
        bool isParticipant = participated[auction][msg.sender];
        if (!isCreator && !isParticipant) revert NotAuthorized();
        _createInvites(auction, msg.sender, codes);
    }

    function _createInvites(
        address auction,
        address issuer,
        bytes32[] calldata codes
    ) internal {
        for (uint256 i = 0; i < codes.length; i++) {
            bytes32 code = codes[i];
            if (code == bytes32(0)) revert InvalidInvite();
            if (inviteIssuer[auction][code] != address(0))
                revert InviteExists();
            inviteIssuer[auction][code] = issuer;
            invitesCreated[auction]++;
            emit InviteCreated(auction, code, issuer);
        }
    }

    /// @notice Called by InviteValidationHook during CCA submitBid.
    function useInvite(address auction, address bidder, bytes32 code) external {
        if (msg.sender != validationHook) revert NotAuthorized();
        if (creatorOf[auction] == address(0)) revert InvalidInvite();
        if (participated[auction][bidder]) return;

        address issuer = inviteIssuer[auction][code];
        if (issuer == address(0)) revert InvalidInvite();
        if (issuer == bidder) revert InvalidInvite();

        participated[auction][bidder] = true;
        referralCountOf[auction][issuer] += 1;
        totalReferralCountOf[auction] += 1;
        emit InviteUsed(auction, bidder, issuer, code);
    }

    function referralCount(
        address auction,
        address referrer
    ) external view returns (uint256) {
        return referralCountOf[auction][referrer];
    }

    function totalReferralCount(
        address auction
    ) external view returns (uint256) {
        return totalReferralCountOf[auction];
    }
}
