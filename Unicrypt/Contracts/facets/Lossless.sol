// SPDX-License-Identifier: UNLICENSED
// ALL RIGHTS RESERVED

// Unicrypt by SDDTech reserves all rights on this code. You may NOT copy these contracts.

pragma solidity 0.8.17;

import "./Storage.sol";

import "../libraries/Ownable.sol";

contract LosslessFacet is Storage, Ownable {
    function onlyRecoveryAdminCheck() internal view {
        require(_msgSender() == recoveryAdmin, "LRA");
    }

    modifier onlyRecoveryAdmin() {
        onlyRecoveryAdminCheck();
        _;
    }

    // --- LOSSLESS management ---

    function getAdmin() external view returns (address) {
        return admin;
    }

    function setLosslessAdmin(address newAdmin) external onlyRecoveryAdmin {
        require(newAdmin != address(0), "LZ");
        emit AdminChanged(admin, newAdmin);
        admin = newAdmin;
    }

    function transferRecoveryAdminOwnership(address candidate, bytes32 keyHash) external onlyRecoveryAdmin {
        require(candidate != address(0), "LZ");
        recoveryAdminCandidate = candidate;
        recoveryAdminKeyHash = keyHash;
        emit RecoveryAdminChangeProposed(candidate);
    }

    function acceptRecoveryAdminOwnership(bytes memory key) external {
        require(_msgSender() == recoveryAdminCandidate, "LC");
        require(keccak256(key) == recoveryAdminKeyHash, "LIK");
        emit RecoveryAdminChanged(recoveryAdmin, recoveryAdminCandidate);
        recoveryAdmin = recoveryAdminCandidate;
    }

    function proposeLosslessTurnOff() external onlyRecoveryAdmin {
        losslessTurnOffTimestamp = block.timestamp + timelockPeriod;
        isLosslessTurnOffProposed = true;
        emit LosslessTurnOffProposed(losslessTurnOffTimestamp);
    }

    function executeLosslessTurnOff() external onlyRecoveryAdmin {
        require(isLosslessTurnOffProposed, "LTNP");
        require(losslessTurnOffTimestamp <= block.timestamp, "LTL");
        isLosslessOn = false;
        isLosslessTurnOffProposed = false;
        emit LosslessTurnedOff();
    }

    function executeLosslessTurnOn() external onlyRecoveryAdmin {
        isLosslessTurnOffProposed = false;
        isLosslessOn = true;
        emit LosslessTurnedOn();
    }
}