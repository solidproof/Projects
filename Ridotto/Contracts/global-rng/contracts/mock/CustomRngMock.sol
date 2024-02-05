// SPDX-License-Identifier: MIT
// A mock for testing code that relies on VRFCoordinatorV2.
pragma solidity ^0.8.4;

contract CustomRng {
    event data(bytes);

    function rng(address r, uint256 reqId, uint256 number) external {
        ICallBack(r).callBack(reqId, number);
    }

    function requestRandomNess(uint256 seed) external returns (uint256) {
        return seed;
    }

    function seeBytes(bytes calldata x, uint256 p1, uint256 p2) external pure returns (bytes memory) {
        return x[p1:p2];
    }
}

interface ICallBack {
    function callBack(uint256 reqId, uint256 number) external;
}

contract test {
    event dat(bytes);

    function ping(address o, bytes memory data) external returns (bytes memory) {
        (bool i, bytes memory p) = o.call(data);
        emit dat(p);
        return p;
    }

    fallback() external {
        emit dat(msg.data);
    }

    function concat(bytes memory x) external view returns (uint256) {
        uint l = x.length;
        uint pad = 32 - l;
        bytes memory p = new bytes(pad);
        return uint256(bytes32(bytes.concat(p, x)));
    }
}
