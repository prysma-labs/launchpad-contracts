// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {IValidationHook} from "continuous-clearing-auction/interfaces/IValidationHook.sol";
import {InviteRegistry} from "./InviteRegistry.sol";

/// @notice CCA bid validation: require a valid invite code in hookData.
contract InviteValidationHook is IValidationHook {
    InviteRegistry public immutable registry;

    error InvalidHookData();

    constructor(InviteRegistry registry_) {
        registry = registry_;
    }

    /// @inheritdoc IValidationHook
    /// @dev hookData is 32 bytes (inbound invite) or 64 bytes (inbound + outbound).
    /// On a first bid, the outbound hash is minted as the bidder's shareable invite.
    function validate(uint256, uint128 amount, address owner, address, bytes calldata hookData) external {
        bytes32 code;
        bytes32 outbound;
        if (hookData.length == 32) {
            code = abi.decode(hookData, (bytes32));
        } else if (hookData.length == 64) {
            (code, outbound) = abi.decode(hookData, (bytes32, bytes32));
        } else {
            revert InvalidHookData();
        }
        registry.useInvite(msg.sender, owner, code, outbound, amount);
    }
}
