/**
 *SPDX-License-Identifier: UNLICENSED
 */
pragma solidity 0.7.6;

contract TimeProvider {
    uint256 manualTime;

    function currentTime() external view returns (uint256 amountOut) {
        if (manualTime > 0) return manualTime;
        return block.timestamp;
    }

    function setTime(uint256 _now) external {
        manualTime = _now;
    }

    function increaseTime(uint256 val) external {
        if (manualTime > 0) {
            manualTime = manualTime + val;
        } else {
            manualTime = block.timestamp + val;
        }
    }

    function decreaseTime(uint256 val) external {
        if (manualTime > 0) {
            manualTime = manualTime - val;
        } else {
            manualTime = block.timestamp - val;
        }
    }

    function reset() external {
        manualTime = 0;
    }
}