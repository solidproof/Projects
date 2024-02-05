// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IAvionToken is IERC20 {
    function updateYield(address user, uint256 newTier) external;
}