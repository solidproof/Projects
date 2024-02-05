// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "../tokens/MintableBaseToken.sol";

contract OMT is MintableBaseToken {
    constructor() public MintableBaseToken("Open Meta Trade", "OMT", 0) {
    }

    function id() external pure returns (string memory _name) {
        return "OMT";
    }
}