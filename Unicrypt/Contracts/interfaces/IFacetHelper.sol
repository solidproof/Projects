// SPDX-License-Identifier: UNLICENSED
// ALL RIGHTS RESERVED

// Unicrypt by SDDTech reserves all rights on this code. You may NOT copy these contracts.

pragma solidity 0.8.17;

interface IFacetHelper {

    function addFacet(address _newFacet) external;

    function addSelector(address _facet, bytes4 _sig) external;

    function removeSelector(bytes4 _sig) external;

    function getFacetAddressFromSelector(bytes4 _sig) external view returns (address);

    function getSettingsFacet() external view returns (address);

    function updateSettingsFacet(address _newSettingsAddress) external;

    function getTaxFacet() external view returns (address);

    function updateTaxFacet(address _newTaxesAddress) external;

    function getLosslessFacet() external view returns (address);

    function updateLosslessFacet(address _newLosslessAddress) external;

    function getConstructorFacet() external view returns (address);

    function updateConstructorFacet(address _newConstructorAddress) external;

    function getWalletsFacet() external view returns (address);

    function updateWalletsFacet(address _newWalletsAddress) external;

    function getAntiBotFacet() external view returns (address);

    function updateAntiBotFacet(address _newWalletsAddress) external;

    function getMulticallFacet() external view returns (address);

    function updateMulticallFacet(address _newWalletsAddress) external;
    
}