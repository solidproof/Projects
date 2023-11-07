// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IXCarbonStarterToken is IERC20 {
    function convertTo(uint256 amount, address to) external;

    function isTransferWhitelisted(
        address account
    ) external view returns (bool);
}
