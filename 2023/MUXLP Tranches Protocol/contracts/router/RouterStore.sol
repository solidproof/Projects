// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "./Type.sol";

contract RouterStore {
    RouterStateStore internal _store;
    bytes32[20] private _reserves;
}
