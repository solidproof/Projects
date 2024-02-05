// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "../libraries/LibERC4626.sol";
import "../libraries/LibConfigSet.sol";
import "../common/Keys.sol";

uint256 constant ONE = 1e18;

struct JuniorStateStore {
    ERC4626Store asset;
    LibConfigSet.ConfigSet config;
    address depositToken;
    bytes32[20] __reserves;
}
