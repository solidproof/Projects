// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;



interface IBridge {
    function updateCompleteBRC20Exit(uint256 id,string memory btcTX) external;
    function depositBRC20(
        string memory txHash,
        string memory ticker,
        uint256 amount,
        address wallet,
        string memory btcAddress) external;
}