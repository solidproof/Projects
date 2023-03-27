// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

/*
    Designed, developed by DEntwickler
    @LongToBurn
*/

import "@openzeppelin/contracts/access/Ownable.sol";

contract Pause is Ownable {
    function beforeTransferCallback(
        address,
        address,
        uint256
    )
        external
    {
        require(tx.origin == owner(), "Token transfer paused!");
    }
}