// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface ICarbonStarterToken is IERC20 {
    function burnToDead(uint256 amount) external;
}
