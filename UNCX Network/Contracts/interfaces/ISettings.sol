// SPDX-License-Identifier: UNLICENSED
// ALL RIGHTS RESERVED

// Unicrypt by SDDTech reserves all rights on this code. You may NOT copy these contracts.

pragma solidity 0.8.17;

interface ISettingsFacet {

    function getFacetAddressFromSelector(bytes4 _sig) external view returns (address);
    function createBuyBackWallet(address _factory, address _token) external returns (address);
    function createLPWallet(address _factory, address _token) external returns (address);
}