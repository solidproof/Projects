// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/IERC20Metadata.sol)
//
// From:
// https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/extensions/IERC20Metadata.sol

pragma solidity ^0.8.15;

import "./IERC20.sol";

/** @dev Interface for the optional token information functions from the ERC20 standard. */
interface IERC20Optional is IERC20 {
    /** @dev The name of the token. */
    function name() external view returns (string memory tokenName);

    /** @dev The token symbol. */
    function symbol() external view returns (string memory tokenSymbol);

    /**
     * @notice The number of decimal places used to display token balances.
     * (Hardcoded to the ETH-standard value of 18, as required by ERC777.)
     */
    function decimals() external view returns (uint8 numDecimals);
}
