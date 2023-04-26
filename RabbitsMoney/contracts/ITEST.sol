// SPDX-License-Identifier: MIT
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
pragma solidity 0.8.15;

interface ITEST is IERC20 {
    function burn(address from, uint256 amount) external;

    function mint(address to, uint256 amount) external;

}