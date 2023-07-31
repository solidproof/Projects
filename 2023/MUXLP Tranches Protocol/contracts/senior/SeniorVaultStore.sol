// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "./Type.sol";

contract SeniorVaultStore {
    string internal _name;
    string internal _symbol;
    SeniorStateStore internal _store;
    bytes32[20] private __reserves;
}
