// SPDX-License-Identifier: MIT
pragma solidity ^0.8.2;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "./IMechaniumCanReleaseUnintented.sol";

/**
 * @title MechaniumCanReleaseUnintented - Abstract class for util can release unintented tokens smart contract
 * @author EthernalHorizons - <https://ethernalhorizons.com/>
 * @custom:project-website  https://mechachain.io/
 * @custom:security-contact contracts@ethernalhorizons.com
 */
abstract contract MechaniumCanReleaseUnintented is
    AccessControl,
    IMechaniumCanReleaseUnintented
{
    using SafeERC20 for IERC20;

    /**
     * @notice Event emitted when release unintented `amount` of `token` for `account` address
     */
    event ReleaseUintentedTokens(
        address indexed token,
        address indexed account,
        uint256 amount
    );

    /// Locked tokens that can't be released for contract
    mapping(address => bool) private _lockedTokens;

    /// fallback payable function ( used to receive ETH in tests )
    fallback() external payable {}

    /// receive payable function ( used to receive ETH in tests )
    receive() external payable {}

    /**
     * @notice Add a locked `token_` ( can't be released )
     */
    function _addLockedToken(address token_) internal {
        _lockedTokens[token_] = true;
    }

    /**
     * @notice Release an `amount` of `token` to an `account`
     * This function is used to prevent unintented tokens that got sent to be stuck on the contract
     * @param token The address of the token contract (zero address for claiming native coins).
     * @param account The address of the tokens/coins receiver.
     * @param amount Amount to claim.
     */
    function releaseUnintented(
        address token,
        address account,
        uint256 amount
    ) public override onlyRole(DEFAULT_ADMIN_ROLE) returns (bool) {
        require(amount > 0, "Amount must be superior to zero");
        require(
            account != address(0) && account != address(this),
            "Amount must be superior to zero"
        );
        require(!_lockedTokens[token], "Token can't be released");

        if (token == address(0)) {
            require(
                address(this).balance >= amount,
                "Address: insufficient balance"
            );
            (bool success, ) = account.call{value: amount}("");
            require(
                success,
                "Address: unable to send value, recipient may have reverted"
            );
        } else {
            IERC20 customToken = IERC20(token);
            require(
                customToken.balanceOf(address(this)) >= amount,
                "Address: insufficient balance"
            );
            customToken.safeTransfer(account, amount);
        }

        emit ReleaseUintentedTokens(token, account, amount);

        return true;
    }
}
