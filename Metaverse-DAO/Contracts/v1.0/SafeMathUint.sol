// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

library SafeMathUint {
    function toInt256Safe(uint256 a) internal pure returns(int256){
        int256 b = int256(a);
        require(b >= 0, "need >= 0");
        return b;
    }
}