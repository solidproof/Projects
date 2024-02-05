//SPDX-License-Identifier: LicenseRef-LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract LPLocker {
    using SafeMath for uint;
    using Counters for Counters.Counter;

    Counters.Counter private _lockerIdTracker;

    enum LockerState {Locked, Unlocked}

    struct Locker {
        IERC20 token;
        LockerState state;
        uint amount;
        uint unlocksAt;
        address lockerOwner;
    }

    mapping (uint => Locker) public lockers;

    function getCorrectAmount(IERC20 token, uint _amount) internal returns (uint) {
        uint beforeBalance = token.balanceOf(address(this));
        require(token.transferFrom(msg.sender, address(this), _amount), 'LPLocker: Token transfer failed');
        uint afterAmount = token.balanceOf(address(this));

        return afterAmount.sub(beforeBalance);
    }

    function lock(address _token, address _owner, uint _amount, uint unlocksAt) public returns (uint) {
        require(block.timestamp < unlocksAt, 'LPLocker: cannot lock in past');

        IERC20 token = IERC20(_token);

        uint amount = getCorrectAmount(token, _amount); // To accommodate any such tax tokens

        uint lockerIDToAssign = _lockerIdTracker.current();
        _lockerIdTracker.increment();

        Locker storage locker = lockers[lockerIDToAssign];
        locker.token = token;
        locker.amount = amount;
        locker.unlocksAt = unlocksAt;
        locker.state = LockerState.Locked;
        locker.lockerOwner = _owner;

        return lockerIDToAssign;
    }

    function unlock(uint lockId) public {
        Locker storage locker = lockers[lockId];

        require(block.timestamp > locker.unlocksAt, 'LPLocker: Not ready to unlock yet');
        require(locker.state == LockerState.Locked, 'LPLocker: already unlocked');
        require(msg.sender == locker.lockerOwner, 'LPLocker: you cannot unlock it');

        locker.token.transfer(msg.sender, locker.amount);
        locker.state = LockerState.Unlocked;
    }

    // For cases if something wrong happened and amount gets stuck, for any tax or transfer logic contracts
    function unlockWithSpecifiedAmount(uint lockId, uint _amount) public {
        Locker storage locker = lockers[lockId];

        require(block.timestamp > locker.unlocksAt, 'LPLocker: Not ready to unlock yet');
        require(locker.state == LockerState.Locked, 'LPLocker: already unlocked');
        require(msg.sender == locker.lockerOwner, 'LPLocker: you cannot unlock it');

        require(_amount <= locker.amount, 'LPLocker: cannot withdraw more then locked');

        locker.token.transfer(msg.sender, _amount);
        locker.state = LockerState.Unlocked;
    }

    // getters
    function getLocker(uint lockId) public view returns (Locker memory) {
        return lockers[lockId];
    }
}
