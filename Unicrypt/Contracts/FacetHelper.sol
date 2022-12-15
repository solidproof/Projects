// SPDX-License-Identifier: UNLICENSED
// ALL RIGHTS RESERVED

// Unicrypt by SDDTech reserves all rights on this code. You may NOT copy these contracts.

pragma solidity 0.8.17;

import "./libraries/Ownable.sol";

contract FacetHelper is Ownable{

    event AddedFacet(address _newFacet);
    event AddedSelector(address _facet, bytes4 _sig);
    event RemovedSelector(bytes4 _sig);
    event ResetStorage();

    event UpdatedSettingsFacet(address _newAddress);
    event UpdatedLosslessFacet(address _newAddress);
    event UpdatedTaxFacet(address _newAddress);
    event UpdatedConstructorFacet(address _newAddress);
    event UpdatedWalletsFacet(address _newAddress);
    event UpdatedAntiBotFacet(address _newAddress);
    event UpdatedMulticallFacet(address _newAddress);

    struct Facets {
        address Settings;
        address Lossless;
        address Tax;
        address Constructor;
        address Wallets;
        address AntiBot;
        address Multicall;
    }

    Facets public facets;

    mapping(bytes4 => address) public selectorToFacet;
    bytes4[] public selectorsList;
    mapping(address => bool) public isFacet;
    address[] public facetsList;

    function addFacet(address _newFacet) public onlyOwner {
        isFacet[_newFacet] = true;
        facetsList.push(_newFacet);
        emit AddedFacet(_newFacet);
    }

    function addSelector(address _facet, bytes4 _sig) public onlyOwner {
        require(selectorToFacet[_sig] == address(0));
        // require(isFacet[_facet]);
        selectorToFacet[_sig] = _facet;
        selectorsList.push(_sig);
        emit AddedSelector(_facet, _sig);
    }

    // Removing of the selectors occurs during resetFacetStorage();
    // it is easier to reset and rebuild using the script when deploying and updating the facets
    // function removeSelector(bytes4 _sig) public onlyOwner {
    //     selectorToFacet[_sig] = address(0);
    //     emit RemovedSelector(_sig);
    // }    

    function getFacetAddressFromSelector(bytes4 _sig) public view returns (address) {
        return selectorToFacet[_sig];
    }

    function getFacetByIndex(uint256 _index) public view returns(address) {
        return facetsList[_index];
    }

    function resetFacetStorage() public onlyOwner {
        for(uint i = 0; i < selectorsList.length; i++) {
            bytes4 sig = selectorsList[i];
            selectorToFacet[sig] = address(0);
        }
        delete selectorsList;

        for(uint i = 0; i < facetsList.length; i++) {
            address facet = facetsList[i];
            isFacet[facet] = false;
        }
        delete facetsList;

        emit ResetStorage();
    }

        // Facet getters and setters

    function getSettingsFacet() public view returns (address) {
        return facets.Settings;
    }

    function updateSettingsFacet(address _newSettingsAddress) public onlyOwner {
        facets.Settings = _newSettingsAddress;
        emit UpdatedSettingsFacet(_newSettingsAddress);
    }

    function getLosslessFacet() public view returns (address) {
        return facets.Lossless;
    }

    function updateLosslessFacet(address _newLosslessAddress) public onlyOwner {
        facets.Lossless = _newLosslessAddress;
        emit UpdatedLosslessFacet(_newLosslessAddress);
    }

    function getTaxFacet() public view returns (address) {
        return facets.Tax;
    }

    function updateTaxFacet(address _newTaxAddress) public onlyOwner {
        facets.Tax = _newTaxAddress;
        emit UpdatedTaxFacet(_newTaxAddress);
    }

    function getConstructorFacet() public view returns (address) {
        return facets.Constructor;
    }

    function updateConstructorFacet(address _newConstructorAddress) public onlyOwner {
        facets.Constructor = _newConstructorAddress;
        emit UpdatedConstructorFacet(_newConstructorAddress);
    }

    function getWalletsFacet() public view returns (address) {
        return facets.Wallets;
    }

    function updateWalletsFacet(address _newWalletsAddress) public onlyOwner {
        facets.Wallets = _newWalletsAddress;
        emit UpdatedWalletsFacet(_newWalletsAddress);
    }

    function getAntiBotFacet() public view returns (address) {
        return facets.AntiBot;
    }

    function updateAntiBotFacet(address _newAntiBotAddress) public onlyOwner {
        facets.AntiBot = _newAntiBotAddress;
        emit UpdatedAntiBotFacet(_newAntiBotAddress);
    }

    function getMulticallFacet() public view returns (address) {
        return facets.Multicall;
    }

    function updateMulticallFacet(address _newWalletsAddress) public onlyOwner {
        facets.Multicall = _newWalletsAddress;
        emit UpdatedMulticallFacet(_newWalletsAddress);
    }
} 