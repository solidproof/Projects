// SPDX-License-Identifier: UNLICENSED
// ALL RIGHTS RESERVED

// Unicrypt by SDDTech reserves all rights on this code. You may NOT copy these contracts.

pragma solidity 0.8.17;

interface IFacetHelper {

    struct Facet {
        address facetAddress;
        bytes4[] functionSelectors;
    }

    /// @notice Gets all facet addresses and their four byte function selectors.
    /// @return facets_ Facet
    function facets() external view returns (Facet[] memory facets_);

    /// @notice Gets all the function selectors supported by a specific facet.
    /// @param _facet The facet address.
    /// @return facetFunctionSelectors_
    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory facetFunctionSelectors_);

    /// @notice Get all the facet addresses used by a diamond.
    /// @return facetAddresses_
    function facetAddresses() external view returns (address[] memory facetAddresses_);

    /// @notice Gets the facet that supports the given selector.
    /// @dev If facet is not found return address(0).
    /// @param _functionSelector The function selector.
    /// @return facetAddress_ The facet address.
    function facetAddress(bytes4 _functionSelector) external view returns (address facetAddress_);

    // function addFacet(address _newFacet) external;

    // function addSelector(address _facet, bytes4 _sig) external;

    // function removeSelector(bytes4 _sig) external;

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