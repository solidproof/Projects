// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IMCB is IERC20 {
    function tokenSupplyOnL1() external view returns (uint256);
}
