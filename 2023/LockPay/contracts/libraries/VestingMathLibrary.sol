pragma solidity ^0.8.0;

import './FullMath.sol';

// Allows a seperate contract with a unlockTokens() function to be used to override unlock dates
interface IUnlockCondition {
    function unlockTokens() external view returns (bool);
}

library VestingMathLibrary {

    // gets the withdrawable amount from a lock
    function getWithdrawableAmount (uint256 startEmission, uint256 endEmission, uint256 amount, uint256 timeStamp, address condition) internal view returns (uint256) {
        // It is possible in some cases IUnlockCondition(condition).unlockTokens() will fail (func changes state or does not return a bool)
        // for this reason we implemented revokeCondition per lock so funds are never stuck in the contract.

        // Prematurely release the lock if the condition is met
        if (condition != address(0) && IUnlockCondition(condition).unlockTokens()) {
            return amount;
        }
        // Lock type 1 logic block (Normal Unlock on due date)
        if (startEmission == 0 || startEmission == endEmission) {
            return endEmission < timeStamp ? amount : 0;
        }
        // Lock type 2 logic block (Linear scaling lock)
        uint256 timeClamp = timeStamp;
        if (timeClamp > endEmission) {
            timeClamp = endEmission;
        }
        if (timeClamp < startEmission) {
            timeClamp = startEmission;
        }
        uint256 elapsed = timeClamp - startEmission;
        uint256 fullPeriod = endEmission - startEmission;
        return FullMath.mulDiv(amount, elapsed, fullPeriod); // fullPeriod cannot equal zero due to earlier checks and restraints when locking tokens (startEmission < endEmission)
    }
}