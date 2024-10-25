// SPDX-License-Identifier: MIT
pragma solidity 0.8.24;

import {AccessManagerUpgradeable} from "@openzeppelin/contracts-upgradeable/access/manager/AccessManagerUpgradeable.sol";

/// @custom:security-contact dev@deelit.net
contract DeelitAccessManager is AccessManagerUpgradeable {

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address initialAdmin_) public initializer {
        __AccessManager_init(initialAdmin_);
    }
}