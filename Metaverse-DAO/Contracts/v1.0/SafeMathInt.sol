// SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;
pragma experimental ABIEncoderV2;

library SafeMathInt {
    function add(int256 a, int256 b) internal pure returns(int256) {
        int256 c = a + b;
        require((b >= 0 && c >= a) || (b < 0 && c < a));
        return c;
    }

    function sub(int256 a, int256 b) internal pure returns(int256) {
        require((b >= 0 && a - b <= a) || (b < 0 && a - b > a));
        return a - b;
    }

    function mul(int256 a, int256 b) internal pure returns(int256) {
        require(!(a == -2**255 && b == -1) && !(b == -2**255 && a == -1));
         int256 c = a * b;
         require((b == 0) || (c/b == a));
         return c;
    }

    function div(int256 a, int256 b) internal pure returns(int256){
        require(!(a == -2**255 && b == -1) && (b > 0));
        return a/b;
    }

    function toUint256Safe(int256 a) internal pure returns(uint256) {
        require(a >= 0);
        return uint256(a);
    }
}