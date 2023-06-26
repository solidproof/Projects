// SPDX-License-Identifier: UNLICENSED
// ALL RIGHTS RESERVED

// Unicrypt by SDDTech reserves all rights on this code. You may NOT copy these contracts.

pragma solidity 0.8.17;

interface ITaxHelper {

    function initiateBuyBackTax(
        address _token,
        address _wallet
    ) external returns (bool);

    function initiateLPTokenTax(        
        address _token,
        address _wallet
    ) external returns (bool);

    function lpTokenHasReserves(address _lpToken) external view returns (bool);

    function createLPToken() external returns (address lpToken);

    function sync(address _lpToken) external;
}