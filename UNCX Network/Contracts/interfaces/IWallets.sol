// SPDX-License-Identifier: UNLICENSED
// ALL RIGHTS RESERVED

// Unicrypt by SDDTech reserves all rights on this code. You may NOT copy these contracts.

pragma solidity 0.8.17;

interface IWalletsFacet {

    function createBuyBackWallet(address _factory, address _token, uint256 _newThreshold) external returns (address);
    function createLPWallet(address _factory, address _token, uint256 _newThreshold) external returns (address);

    function updateBuyBackWalletThreshold(uint256 _newThreshold) external;

    function updateLPWalletThreshold(uint256 _newThreshold) external;
}