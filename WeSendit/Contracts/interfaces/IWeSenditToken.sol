// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "./IDynamicFeeManager.sol";

interface IWeSenditToken {
    /**
     * Emitted on transaction unpause
     */
    event Unpaused();

    /**
     * Emitted on dynamic fee manager update
     *
     * @param newAddress address - New dynamic fee manager address
     */
    event DynamicFeeManagerUpdated(address newAddress);

    /**
     * Returns the initial supply
     *
     * @return value uint256 - Initial supply
     */
    function initialSupply() external pure returns (uint256 value);

    /**
     * Returns true if transactions are pause, false if unpaused
     *
     * @param value bool - Indicates if transactions are paused
     */
    function paused() external view returns (bool value);

    /**
     * Sets the transaction pause state to false and therefor, allowing any transactions
     */
    function unpause() external;

    /**
     * Returns the dynamic fee manager
     *
     * @return value IDynamicFeeManager - Dynamic Fee Manager
     */
    function dynamicFeeManager()
        external
        view
        returns (IDynamicFeeManager value);

    /**
     * Sets the dynamic fee manager
     * Can be set to zero address to disable fee reflection.
     *
     * @param value address - New dynamic fee manager address
     */
    function setDynamicFeeManager(address value) external;

    /**
     * Transfers token from <from> to <to> without applying fees
     *
     * @param from address - Sender address
     * @param to address - Receiver address
     * @param amount uin256 - Transaction amount
     */
    function transferFromNoFees(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}
