/**
 * @title USDFI
 * @dev USDFI contract
 *
 * @author - <USDFI TRUST>
 * for the USDFI Trust
 *
 * SPDX-License-Identifier: GNU GPLv2
 *
 **/

pragma solidity 0.6.12;

import "./ERC20.sol";

contract USDFI is ERC20 {
    constructor() public ERC20("USDFI", "USDFI") {}
}
