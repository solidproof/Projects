// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "./Type.sol";

contract JuniorVaultStore {
    string internal _name;
    string internal _symbol;
    JuniorStateStore internal _store;
    bytes32[20] private __reserves;
}
