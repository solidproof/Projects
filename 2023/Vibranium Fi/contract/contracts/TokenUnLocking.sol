// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;

import "./Ownable.sol";
import "./IERC20.sol";

contract TokenUnLocking is Ownable {
    address public immutable vib;

    mapping(address => UnlockingRule) public UnlockingInfo;

    event Withdraw(address indexed _user, uint256 _amount, uint256 _timestamp);
    event WithdrawDirect(
        address indexed _user,
        uint256 _amount,
        uint256 _timestamp
    );

    event SetUnlockRule(
        address indexed _user,
        uint256 _directUnlock,
        uint256 directUnlockTime,
        uint256 _totalLocked,
        uint256 _duration,
        uint256 _unlockStartTime,
        uint256 _lastWithdrawTime
    );

    constructor(address _vib) {
        vib = _vib;
    }

    struct UnlockingRule {
        uint256 directUnlock;
        uint256 directUnlockTime;
        uint256 totalLocked;
        uint256 duration;
        uint256 unlockStartTime;
        uint256 lastWithdrawTime;
    }

    function setUnlockRule(
        address _user,
        uint256 _directUnlock,
        uint256 _directUnlockTime,
        uint256 _duration,
        uint256 _totalLocked,
        uint256 _unlockStartTime
    ) external onlyOwner {
        require(_unlockStartTime > 0, "Invalid time");
        require(
            UnlockingInfo[_user].lastWithdrawTime == 0,
            "This rule has already been set."
        );
        IERC20(vib).transferFrom(
            msg.sender,
            address(this),
            _directUnlock + _totalLocked
        );
        UnlockingInfo[_user].directUnlock = _directUnlock;
        UnlockingInfo[_user].directUnlockTime = _directUnlockTime;
        UnlockingInfo[_user].totalLocked = _totalLocked;
        UnlockingInfo[_user].duration = _duration;
        UnlockingInfo[_user].unlockStartTime = _unlockStartTime;
        UnlockingInfo[_user].lastWithdrawTime = _unlockStartTime;
        emit SetUnlockRule(
            _user,
            _directUnlock,
            _directUnlockTime,
            _totalLocked,
            _duration,
            _unlockStartTime,
            _unlockStartTime
        );
    }

    function getUserUnlockInfo(
        address _user
    ) external view returns (UnlockingRule memory) {
        return UnlockingInfo[_user];
    }

    function getRewards(address _user) public view returns (uint256) {
        if (
            block.timestamp <= UnlockingInfo[_user].unlockStartTime ||
            UnlockingInfo[_user].unlockStartTime == 0
        ) return 0;
        uint256 unlockEndTime = UnlockingInfo[_user].unlockStartTime +
            UnlockingInfo[_user].duration;
        uint256 unstakeRate = UnlockingInfo[_user].totalLocked /
            UnlockingInfo[_user].duration;
        uint256 reward = block.timestamp > unlockEndTime
            ? (unlockEndTime - UnlockingInfo[_user].lastWithdrawTime) *
                unstakeRate
            : (block.timestamp - UnlockingInfo[_user].lastWithdrawTime) *
                unstakeRate;
        return reward;
    }

    function withdraw(address _user) public {
        require(
            block.timestamp >= UnlockingInfo[_user].unlockStartTime,
            "The time has not yet arrived."
        );
        uint256 unlockEndTime = UnlockingInfo[_user].unlockStartTime +
            UnlockingInfo[_user].duration;
        uint256 amount = getRewards(_user);

        if (amount > 0) {
            if (block.timestamp > unlockEndTime) {
                UnlockingInfo[_user].lastWithdrawTime = unlockEndTime;
            } else {
                UnlockingInfo[_user].lastWithdrawTime = block.timestamp;
            }

            IERC20(vib).transfer(_user, amount);
            emit Withdraw(_user, amount, block.timestamp);
        }
    }

    function withdrawDirect(address _user) public {
        require(
            block.timestamp >= UnlockingInfo[_user].directUnlockTime,
            "The time has not yet arrived."
        );
        uint256 amount = UnlockingInfo[_user].directUnlock;
        UnlockingInfo[_user].directUnlock = 0;
        if (amount > 0) {
            IERC20(vib).transfer(_user, amount);
            emit WithdrawDirect(_user, amount, block.timestamp);
        }
    }
}
