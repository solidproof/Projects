// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "./interface/IERC20.sol";
import "./lib/SafeERC20.sol";

contract GovernanceTreasury {
    using SafeERC20 for IERC20;

    address public owner;
    address public pendingOwner;

    event Claimed(address recipient, address token, uint256 amount);

    constructor() {
        owner = msg.sender;
    }

    function setOwner(address _owner) external {
        require(msg.sender == owner, "Not owner");
        pendingOwner = _owner;
    }

    function acceptOwner() external {
        require(msg.sender == pendingOwner, "Not pending owner");
        owner = pendingOwner;
    }

    function claim(address[] memory tokens) external {
        require(msg.sender == owner, "Not owner");
        for (uint256 i; i < tokens.length; i++) {
            address token = tokens[i];
            uint256 balance = IERC20(token).balanceOf(address(this));
            require(balance != 0, "Zero balance");
            IERC20(token).safeTransfer(msg.sender, balance);
            emit Claimed(msg.sender, token, balance);
        }
    }
}
