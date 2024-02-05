// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;

import { Diamond } from "./Diamond.sol";

/// @title DegenX Ecosystem Diamond
/// @author Daniel <danieldegendev@gmail.com>
/// @custom:version 1.0.0
contract DegenX is Diamond {
    constructor(address _owner, address _diamondCutFacet) payable Diamond(_owner, _diamondCutFacet) {}
}
