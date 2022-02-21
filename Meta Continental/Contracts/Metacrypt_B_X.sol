// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./ERC20.sol";

import "./MetacryptHelper.sol";
import "./MetacryptGeneratorInfo.sol";

contract Metacrypt_B_X is ERC20, MetacryptHelper, MetacryptGeneratorInfo {
    constructor(
        address __metacrypt_target,
        string memory __cmt_name,
        string memory __cmt_symbol,
        uint256 __cmt_initial
    ) payable ERC20(__cmt_name, __cmt_symbol) MetacryptHelper("Metacrypt_B_X", __metacrypt_target) {
        require(__cmt_initial > 0, "ERC20: supply cannot be zero");

        _mint(_msgSender(), __cmt_initial);
    }
}