// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import "./Ownable.sol";

contract esVIBBoost is Ownable {
    esVIBLockSetting[] public esVIBLockSettings;
    mapping(address => LockStatus) public userLockStatus;

    // Define a struct for the lock settings
    struct esVIBLockSetting {
        uint256 duration;
        uint256 miningBoost;
    }

    // Define a struct for the user's lock status
    struct LockStatus {
        uint256 unlockTime;
        uint256 duration;
        uint256 miningBoost;
    }

    // Constructor to initialize the default lock settings
    constructor(
    ) {
        esVIBLockSettings.push(esVIBLockSetting(15 days, 10 * 1e18));
        esVIBLockSettings.push(esVIBLockSetting(30 days, 20 * 1e18));
        esVIBLockSettings.push(esVIBLockSetting(90 days, 40 * 1e18));
        esVIBLockSettings.push(esVIBLockSetting(365 days, 100 * 1e18));
    }

    // Function to add a new lock setting
    function addLockSetting(esVIBLockSetting memory setting) external onlyOwner {
        esVIBLockSettings.push(setting);
    }

    // Function to set the user's lock status
    function setLockStatus(uint256 id) external {
        esVIBLockSetting memory _setting = esVIBLockSettings[id];
        LockStatus memory userStatus = userLockStatus[msg.sender];
        if(userStatus.unlockTime > block.timestamp) {
            require(userStatus.duration <= _setting.duration, "Your lock-in period has not ended, and the term can only be extended, not reduced.");
        }
        userLockStatus[msg.sender] = LockStatus(block.timestamp + _setting.duration, _setting.duration, _setting.miningBoost);
    }

    // Function to get the user's unlock time
    function getUnlockTime(address user) external view returns(uint256 unlockTime) {
        unlockTime = userLockStatus[user].unlockTime;
    }

    /**
     * @notice calculate the user's mining boost based on their lock status
     * @dev Based on the user's userUpdatedAt time, finishAt time, and the current time,
     * there are several scenarios that could occur, including no acceleration, full acceleration, and partial acceleration.
     */
    function getUserBoost(address user, uint256 userUpdatedAt, uint256 finishAt) external view returns(uint256) {
        uint256 boostEndTime = userLockStatus[user].unlockTime;
        uint256 maxBoost = userLockStatus[user].miningBoost;
        if(userUpdatedAt >= boostEndTime || userUpdatedAt >= finishAt) {
            return 0;
        }
        if (finishAt <= boostEndTime || block.timestamp <= boostEndTime) {
            return maxBoost;
        } else {
            uint256 time = block.timestamp > finishAt ? finishAt : block.timestamp;
            return
                ((boostEndTime - userUpdatedAt) *
                    maxBoost) /
                (time - userUpdatedAt);
        }
    }
}