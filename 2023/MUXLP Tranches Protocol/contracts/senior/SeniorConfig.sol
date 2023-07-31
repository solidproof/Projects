// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "../interfaces/IConfigurable.sol";
import "../libraries/LibTypeCast.sol";
import "./Type.sol";

/**
 * @title SeniorConfig
 * @notice SeniorConfig is designed to assist administrators in managing variables within the Mux Tranche Protocol.
 * However, it is not a mandatory component, as users can still directly use the setConfig interface and Key-Value (KV) approach to configure and customize the protocol settings. \
 * The SeniorConfig module provides an additional layer of convenience and flexibility for administrators to manage and update the protocol's variables.
 */
contract SeniorConfig {
    using LibTypeCast for bytes32;
    using LibTypeCast for uint256;
    using LibTypeCast for address;

    IConfigurable public seniorVault;

    modifier onlyAdmin() {
        require(seniorVault.hasRole(DEFAULT_ADMIN, msg.sender), "SeniorConfig::ADMIN_ONLY");
        _;
    }

    constructor(address configurable_) {
        require(configurable_ != address(0), "SeniorConfig::INVALID_ADDRESS");
        seniorVault = IConfigurable(configurable_);
    }

    function lockType() public view virtual returns (LockType) {
        return LockType(seniorVault.getConfig(LOCK_TYPE).toUint256());
    }

    function lockPeriod() public view virtual returns (uint256) {
        return seniorVault.getConfig(LOCK_PERIOD).toUint256();
    }

    function lockPenaltyRate() public view virtual returns (uint256) {
        return seniorVault.getConfig(LOCK_PENALTY_RATE).toUint256();
    }

    function lockPenaltyRecipient() public view virtual returns (address) {
        return seniorVault.getConfig(LOCK_PENALTY_RECIPIENT).toAddress();
    }

    function maxBorrows() public view virtual returns (uint256) {
        return seniorVault.getConfig(MAX_BORROWS).toUint256();
    }

    function maxBorrowsByVault(address vault) public view virtual returns (uint256) {
        return seniorVault.getConfig(keccak256(abi.encode(MAX_BORROWS, vault))).toUint256();
    }

    function setLockType(LockType lockType_) public virtual onlyAdmin {
        seniorVault.setConfig(LOCK_TYPE, uint256(lockType_).toBytes32());
    }

    function setLockPeriod(uint256 lockPeriod_) public virtual onlyAdmin {
        seniorVault.setConfig(LOCK_PERIOD, lockPeriod_.toBytes32());
    }

    function setLockPenaltyRate(uint256 lockPenaltyRate_) public virtual onlyAdmin {
        require(lockPenaltyRate_ <= ONE, "SeniorConfig::INVALID_RATE");
        seniorVault.setConfig(LOCK_PENALTY_RATE, lockPenaltyRate_.toBytes32());
    }

    function setLockPenaltyRecipient(address lockPenaltyRecipient_) public virtual onlyAdmin {
        require(lockPenaltyRecipient_ != address(0), "SeniorConfig::INVALID_ADDRESS");
        seniorVault.setConfig(LOCK_PENALTY_RECIPIENT, lockPenaltyRecipient_.toBytes32());
    }

    function setMaxBorrows(uint256 maxBorrows_) public virtual onlyAdmin {
        seniorVault.setConfig(MAX_BORROWS, maxBorrows_.toBytes32());
    }

    function setMaxBorrowsByVault(address vault, uint256 maxBorrows_) public virtual onlyAdmin {
        seniorVault.setConfig(keccak256(abi.encode(MAX_BORROWS, vault)), maxBorrows_.toBytes32());
    }
}
