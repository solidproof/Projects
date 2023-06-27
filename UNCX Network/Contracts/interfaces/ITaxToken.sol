// SPDX-License-Identifier: UNLICENSED
// ALL RIGHTS RESERVED

// Unicrypt by SDDTech reserves all rights on this code. You may NOT copy these contracts.

pragma solidity 0.8.17;

import "./IERC20.sol";

interface ITaxToken is IERC20 {

    function taxHelperIndex()external view returns(uint);

    function buyBackBurn(uint256 _amount) external;

    function owner() external view returns (address);

    function pairAddress() external view returns (address);
    function decimals() external view returns (uint8);

}