// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface INeokingdomToken is IERC20 {
    function mint(address to, uint256 amount) external;

    function burn(uint256 amount) external;

    function burnFrom(address from, uint256 amount) external;
}
