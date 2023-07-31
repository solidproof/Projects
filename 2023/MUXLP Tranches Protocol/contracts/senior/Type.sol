// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "../libraries/LibERC4626.sol";
import "../libraries/LibConfigSet.sol";
import "../common/Keys.sol";

uint256 constant ONE = 1e18;

enum LockType {
    None,
    SoftLock,
    HardLock
}

struct SeniorStateStore {
    // balance properties
    ERC4626Store asset;
    // config
    LibConfigSet.ConfigSet config;
    // helper properties
    uint256 previousBalance;
    // total assets borrowed to junior vaults
    uint256 totalBorrows;
    // assets borrowed to junior vaults
    mapping(address => uint256) borrows;
    // withdraw timelock, depends on the type of lock
    mapping(address => uint256) timelocks;
    bytes32[20] __reserves;
}
