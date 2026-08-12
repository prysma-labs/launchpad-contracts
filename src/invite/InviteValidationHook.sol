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
    function validate(uint256, uint128 amount, address owner, address, bytes calldata hookData) external {
        if (hookData.length != 32) revert InvalidHookData();
        bytes32 code = abi.decode(hookData, (bytes32));
        registry.useInvite(msg.sender, owner, code, amount);
    }
}
