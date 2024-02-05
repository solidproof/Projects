// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "./FayreMembershipCard721.sol";

contract FayrePremiumOGCard is FayreMembershipCard721 {
    function initialize(uint256 networkId) public initializer {
        __FayreMembershipCard721_init(networkId, "FAYREOGCARD", "FAYREOG", 2500e18, 75000e18, 250, 0, 5);
    }
}