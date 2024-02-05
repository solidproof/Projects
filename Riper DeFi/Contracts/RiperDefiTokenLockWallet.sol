// SPDX-License-Identifier: MIT

pragma solidity 0.8.6;

import "./base/RiperDefiTokenLock.sol";
import "./interfaces/IRiperDefiTokenLockManager.sol";

/**
 * @title BlackBearFinanceWallet
 * @notice This contract is built on top of the base BlackBearFinance functionality.
 * It allows wallet beneficiaries to use the deposited funds to perform specific function calls
 * on specific contracts.
 *
 * The idea is that supporters with locked tokens can participate in the protocol
 * but disallow any release before the vesting/lock schedule.
 * The beneficiary can issue authorized function calls to this contract that will
 * get forwarded to a target contract. A target contract is any of our protocol contracts.
 * The function calls allowed are queried to the BlackBearFinanceManager, this way
 * the same configuration can be shared for all the created lock wallet contracts.
 *
 * NOTE: Contracts used as target must have its function signatures checked to avoid collisions
 * with any of this contract functions.
 * Beneficiaries need to approve the use of the tokens to the protocol contracts. For convenience
 * the maximum amount of tokens is authorized.
 */
contract RiperDefiTokenLockWallet is RiperDefiTokenLock {
    // Initializer
    function initialize(
        address _newOwner,
        address _beneficiary,
        address _token,
        uint256 _managedAmount,
        uint256 _startTime,
        uint256 _endTime,
        uint256 _periods,
        uint256 _releaseStartTime,
        uint256 _vestingCliffTime,
        Revocability _revocable
    ) external {
        _initialize(
            _newOwner,
            _beneficiary,
            _token,
            _managedAmount,
            _startTime,
            _endTime,
            _periods,
            _releaseStartTime,
            _vestingCliffTime,
            _revocable
        );
    }
}