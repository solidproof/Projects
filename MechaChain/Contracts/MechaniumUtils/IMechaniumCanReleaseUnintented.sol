// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

/**
 * @dev Mechanim can release unintented smart contract interface
 * @author EthernalHorizons - <https://ethernalhorizons.com/>
 * @custom:project-website  https://mechachain.io/
 * @custom:security-contact contracts@ethernalhorizons.com
 */
interface IMechaniumCanReleaseUnintented {
    /**
     * @dev Release unintented tokens sent to smart contract ( only admin role )
     * This function is used to prevent unintented tokens that got sent to be stuck on the contract
     * @param token The address of the token contract (zero address for claiming native coins).
     * @param account The address of the tokens/coins receiver.
     * @param amount Amount to claim.
     */
    function releaseUnintented(
        address token,
        address account,
        uint256 amount
    ) external returns (bool);
}
