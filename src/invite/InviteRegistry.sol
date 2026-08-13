// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IReferralSource} from "../fee/IReferralSource.sol";

/// @notice Invite codes and referral weights.
/// @dev Deployed once per chain; shared across all auctions (keyed by auction address).
/// Authority for bid gating + fee attribution (offchain DB is UX-only):
/// - Factory registers each auction and seeds the creator's first invite.
/// - Creator (or a prior participant) can create more invites; codes are bytes32 → issuer.
/// - InviteValidationHook calls useInvite on CCA bid; unknown/self invites revert on first bid.
///   The auction creator may bid without an invite; those bids get no referral credit.
///   First-time bidders may pass a second bytes32 in hookData to mint their outbound invite in the same tx.
/// - Codes are reusable. Each bid's currency amount is credited to the bidder's original inviter.
/// - FeeDistributor pays referrers pro-rata by attributed bid volume.
contract InviteRegistry is IReferralSource {
    /// @dev CcaLaunchFactory — only caller allowed to registerAuction / seedInvites.
    address public factory;
    address public validationHook;

    mapping(address => address) public creatorOf;
    mapping(address => address) public auctionOfToken;
    mapping(address => mapping(bytes32 => address)) public inviteIssuer;
    mapping(address => mapping(address => bool)) public participated;
    mapping(address => mapping(address => address)) public referrerOf;
    mapping(address => mapping(address => uint256)) public referralVolumeOf;
    mapping(address => uint256) public totalReferralVolumeOf;
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
        bytes32 code,
        uint128 amount
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

    /// @dev First-bid outbound mint. Zero skips. Same issuer is idempotent.
    function _seedOutbound(
        address auction,
        address bidder,
        bytes32 outbound
    ) internal {
        if (outbound == bytes32(0)) return;
        address existing = inviteIssuer[auction][outbound];
        if (existing == address(0)) {
            _createInvite(auction, bidder, outbound);
            return;
        }
        if (existing != bidder) revert InviteExists();
    }

    /// @notice Called by InviteValidationHook during CCA submitBid.
    /// @dev First bid binds the bidder to the invite issuer. Later bids add volume
    /// to that same referrer without re-checking the code.
    /// The auction creator may bid with any/no code; volume is not attributed.
    /// `outbound` mints the bidder's shareable invite on first participation.
    function useInvite(
        address auction,
        address bidder,
        bytes32 code,
        bytes32 outbound,
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
            if (issuer == address(0)) revert InvalidInvite();
            if (issuer == bidder) revert InvalidInvite();
            referrerOf[auction][bidder] = issuer;
            participated[auction][bidder] = true;
            _seedOutbound(auction, bidder, outbound);
        }

        if (amount != 0) {
            referralVolumeOf[auction][issuer] += amount;
            totalReferralVolumeOf[auction] += amount;
        }
        emit InviteUsed(auction, bidder, issuer, code, amount);
    }

    function referralVolume(
        address auction,
        address referrer
    ) external view returns (uint256) {
        return referralVolumeOf[auction][referrer];
    }

    function totalReferralVolume(
        address auction
    ) external view returns (uint256) {
        return totalReferralVolumeOf[auction];
    }
}
