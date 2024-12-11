// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";

// This contract just receives and holds HLAW Rewards that are dripped to stakers.
contract HLAWRewardPool is Ownable {
    using Address for address;

    IERC20 public hlawToken;
    address public hlawStaking;
    bool private initialized;

    constructor(address _hlawToken) Ownable(msg.sender) {
        hlawToken = IERC20(_hlawToken);
    }

    function init(address _hlawStaking) external onlyOwner {
        require(!initialized, "Can only initialize once!");
        require(_hlawStaking.code.length > 0, "Must be a contract address that is initialized.");
        hlawStaking = _hlawStaking;
        hlawToken.approve(hlawStaking, type(uint256).max);

        initialized = true;
    }
}
