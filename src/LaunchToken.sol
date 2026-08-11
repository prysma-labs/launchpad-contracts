// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/// @notice Fixed-supply ERC-20 with immutable launch metadata.
contract LaunchToken is ERC20 {
    uint256 public constant TOTAL_SUPPLY = 1_000_000_000 ether;

    string public description;
    string public image;
    string public website;
    string public twitter;
    string public telegram;

    address public immutable factory;

    constructor(
        string memory name_,
        string memory symbol_,
        string memory description_,
        string memory image_,
        string memory website_,
        string memory twitter_,
        string memory telegram_,
        address recipient
    ) ERC20(name_, symbol_) {
        factory = msg.sender;
        description = description_;
        image = image_;
        website = website_;
        twitter = twitter_;
        telegram = telegram_;
        _mint(recipient, TOTAL_SUPPLY);
    }
}
