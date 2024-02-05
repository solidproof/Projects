// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./FayreMembershipCard721.sol";

contract FayreStandardCard is FayreMembershipCard721 {
    function initialize(uint256 networkId) public initializer {
        __FayreMembershipCard721_init(networkId, "FAYRESTANDARDCARD", "FAYRESC", 50e18, 10000e18, 0, 10000e18, 1);
    }
}