// SPDX-License-Identifier: UNLICENSED
// ALL RIGHTS RESERVED

// Unicrypt by SDDTech reserves all rights on this code. You may NOT copy these contracts.

pragma solidity 0.8.17;

import "./Storage.sol";

import "../libraries/Ownable.sol";

contract LosslessFacet is Ownable {
    Storage internal s;

    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);
    event RecoveryAdminChangeProposed(address indexed candidate);
    event RecoveryAdminChanged(address indexed previousAdmin, address indexed newAdmin);
    event LosslessTurnOffProposed(uint256 turnOffDate);
    event LosslessTurnedOff();
    event LosslessTurnedOn();

    function onlyRecoveryAdminCheck() internal view {
        require(_msgSender() == s.recoveryAdmin, "LRA");
    }

    modifier onlyRecoveryAdmin() {
        onlyRecoveryAdminCheck();
        _;
    }

    // --- LOSSLESS management ---

    function getAdmin() external view returns (address) {
        return s.admin;
    }

    function setLosslessAdmin(address newAdmin) external onlyRecoveryAdmin {
        require(newAdmin != address(0), "LZ");
        emit AdminChanged(s.admin, newAdmin);
        s.admin = newAdmin;
    }

    function transferRecoveryAdminOwnership(address candidate, bytes32 keyHash) external onlyRecoveryAdmin {
        require(candidate != address(0), "LZ");
        s.recoveryAdminCandidate = candidate;
        s.recoveryAdminKeyHash = keyHash;
        emit RecoveryAdminChangeProposed(candidate);
    }

    function acceptRecoveryAdminOwnership(bytes memory key) external {
        require(_msgSender() == s.recoveryAdminCandidate, "LC");
        require(keccak256(key) == s.recoveryAdminKeyHash, "LIK");
        emit RecoveryAdminChanged(s.recoveryAdmin, s.recoveryAdminCandidate);
        s.recoveryAdmin = s.recoveryAdminCandidate;
    }

    function proposeLosslessTurnOff() external onlyRecoveryAdmin {
        s.losslessTurnOffTimestamp = block.timestamp + s.timelockPeriod;
        s.isLosslessTurnOffProposed = true;
        emit LosslessTurnOffProposed(s.losslessTurnOffTimestamp);
    }

    function executeLosslessTurnOff() external onlyRecoveryAdmin {
        require(s.isLosslessTurnOffProposed, "LTNP");
        require(s.losslessTurnOffTimestamp <= block.timestamp, "LTL");
        s.isLosslessOn = false;
        s.isLosslessTurnOffProposed = false;
        emit LosslessTurnedOff();
    }

    function executeLosslessTurnOn() external onlyRecoveryAdmin {
        s.isLosslessTurnOffProposed = false;
        s.isLosslessOn = true;
        emit LosslessTurnedOn();
    }
}