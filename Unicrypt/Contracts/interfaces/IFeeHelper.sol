// SPDX-License-Identifier: UNLICENSED
// ALL RIGHTS RESERVED

// Unicrypt by SDDTech reserves all rights on this code. You may NOT copy these contracts.

pragma solidity 0.8.17;

interface IFeeHelper {
    function getFee() view external returns(uint256);
    
    function getFeeDenominator() view external returns(uint256);
    
    function setFee(uint _fee) external;
    
    function getFeeAddress() view external returns(address);
    
    function setFeeAddress(address payable _feeAddress) external;

    function getGeneratorFee() view external returns(uint256);

    function setGeneratorFee(uint256 _fee) external;
}