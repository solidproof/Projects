// SPDX-License-Identifier: UNLICENSED
// ALL RIGHTS RESERVED

// Unicrypt by SDDTech reserves all rights on this code. You may NOT copy these contracts.

pragma solidity 0.8.17;

interface IMintFactory {

    struct TaxHelper {
        string Name;
        address Address;
        uint Index;
    }

    function addTaxHelper(string calldata _name, address _address) external;

    function updateTaxHelper(uint _index, address _address) external;

    function getTaxHelperAddress(uint _index) external view returns(address);

    function getTaxHelpersDataByIndex(uint _index) external view returns(TaxHelper memory);

    function registerToken (address _tokenOwner, address _tokenAddress) external;

    function tokenIsRegistered(address _tokenAddress) external view returns (bool);

    function tokenGeneratorsLength() external view returns (uint256);

    function tokenGeneratorIsAllowed(address _tokenGenerator) external view returns (bool);

    function getFacetHelper() external view returns (address);

    function updateFacetHelper(address _newFacetHelperAddress) external;

    function getFeeHelper() external view returns (address);

    function updateFeeHelper(address _newFeeHelperAddress) external;
    
    function getLosslessController() external view returns (address);

    function updateLosslessController(address _newLosslessControllerAddress) external;
}