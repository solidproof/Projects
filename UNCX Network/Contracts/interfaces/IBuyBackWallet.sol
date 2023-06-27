// SPDX-License-Identifier: UNLICENSED
// ALL RIGHTS RESERVED

// Unicrypt by SDDTech reserves all rights on this code. You may NOT copy these contracts.

pragma solidity 0.8.17;

interface IBuyBackWallet {

    function checkBuyBackTrigger() external view returns (bool);

    function getBalance() external view returns (uint256);

    function sendEthToTaxHelper() external returns(uint256);

    function updateThreshold(uint256 _newThreshold) external;

    function getThreshold() external view returns (uint256);
}