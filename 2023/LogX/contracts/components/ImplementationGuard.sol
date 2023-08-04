// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

contract ImplementationGuard {
    address private immutable _this;

    constructor() {
        _this = address(this);
    }

    modifier onlyDelegateCall() {
        require(address(this) != _this);
        _;
    }
}