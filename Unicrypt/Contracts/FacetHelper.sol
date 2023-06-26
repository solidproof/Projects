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

    struct FacetAddressAndPosition {
        address facetAddress;
        uint16 functionSelectorPosition; // position in facetFunctionSelectors.functionSelectors array
    }

    struct FacetFunctionSelectors {
        bytes4[] functionSelectors;
        uint16 facetAddressPosition; // position of facetAddress in facetAddresses array
    }

    // maps function selector to the facet address and
    // the position of the selector in the facetFunctionSelectors.selectors array
    mapping(bytes4 => FacetAddressAndPosition) _selectorToFacetAndPosition;
    // maps facet addresses to function selectors
    mapping(address => FacetFunctionSelectors) _facetFunctionSelectors;
    // facet addresses
    address[] _facetAddresses;
    // Used to query if a contract implements an interface.
    // Used to implement ERC-165.
    mapping(bytes4 => bool) supportedInterfaces;

    Facets public facetsInfo;

    enum FacetCutAction {Add, Replace, Remove}
    // Add=0, Replace=1, Remove=2

    struct FacetCut {
        address facetAddress;
        FacetCutAction action;
        bytes4[] functionSelectors;
    }

    struct Facet {
        address facetAddress;
        bytes4[] functionSelectors;
    }

    /// @notice Gets all facets and their selectors.
    /// @return facets_ Facet
    function facets() external view returns (Facet[] memory facets_) {
        uint256 numFacets = _facetAddresses.length;
        facets_ = new Facet[](numFacets);
        for (uint256 i; i < numFacets; i++) {
            address facetAddress_ = _facetAddresses[i];
            facets_[i].facetAddress = facetAddress_;
            facets_[i].functionSelectors = _facetFunctionSelectors[facetAddress_].functionSelectors;
        }
    }

    /// @notice Gets all the function selectors provided by a facet.
    /// @param _facet The facet address.
    /// @return facetFunctionSelectors_
    function facetFunctionSelectors(address _facet) external view returns (bytes4[] memory facetFunctionSelectors_) {
        facetFunctionSelectors_ = _facetFunctionSelectors[_facet].functionSelectors;
    }

    /// @notice Get all the facet addresses used by a diamond.
    /// @return facetAddresses_
    function facetAddresses() external view returns (address[] memory facetAddresses_) {
        facetAddresses_ = _facetAddresses;
    }

    /// @notice Gets the facet that supports the given selector.
    /// @dev If facet is not found return address(0).
    /// @param _functionSelector The function selector.
    /// @return facetAddress_ The facet address.
    function facetAddress(bytes4 _functionSelector) external view returns (address facetAddress_) {
        facetAddress_ = _selectorToFacetAndPosition[_functionSelector].facetAddress;
    }

    // This implements ERC-165.
    function supportsInterface(bytes4 _interfaceId) external view returns (bool) {
        return supportedInterfaces[_interfaceId];
    }

    event DiamondCut(FacetCut[] _diamondCut);

    function diamondCut(
        FacetCut[] memory _diamondCut
    ) public onlyOwner {
        for (uint256 facetIndex; facetIndex < _diamondCut.length; facetIndex++) {
            FacetCutAction action = _diamondCut[facetIndex].action;
            if (action == FacetCutAction.Add) {
                addFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else if (action == FacetCutAction.Replace) {
                replaceFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else if (action == FacetCutAction.Remove) {
                removeFunctions(_diamondCut[facetIndex].facetAddress, _diamondCut[facetIndex].functionSelectors);
            } else {
                revert("LibDiamondCut: Incorrect FacetCutAction");
            }
        }
        emit DiamondCut(_diamondCut);
    }

    function addFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        require(_functionSelectors.length > 0, "LibDiamondCut: No selectors in facet to cut");
        // uint16 selectorCount = uint16(diamondStorage().selectors.length);
        require(_facetAddress != address(0), "LibDiamondCut: Add facet can't be address(0)");
        uint16 selectorPosition = uint16(_facetFunctionSelectors[_facetAddress].functionSelectors.length);
        // add new facet address if it does not exist
        if (selectorPosition == 0) {
            enforceHasContractCode(_facetAddress, "LibDiamondCut: New facet has no code");
            _facetFunctionSelectors[_facetAddress].facetAddressPosition = uint16(_facetAddresses.length);
            _facetAddresses.push(_facetAddress);
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = _selectorToFacetAndPosition[selector].facetAddress;
            require(oldFacetAddress == address(0), "LibDiamondCut: Can't add function that already exists");
            _facetFunctionSelectors[_facetAddress].functionSelectors.push(selector);
            _selectorToFacetAndPosition[selector].facetAddress = _facetAddress;
            _selectorToFacetAndPosition[selector].functionSelectorPosition = selectorPosition;
            selectorPosition++;
        }
    }

    function replaceFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        require(_functionSelectors.length > 0, "LibDiamondCut: No selectors in facet to cut");
        require(_facetAddress != address(0), "LibDiamondCut: Add facet can't be address(0)");
        uint16 selectorPosition = uint16(_facetFunctionSelectors[_facetAddress].functionSelectors.length);
        // add new facet address if it does not exist
        if (selectorPosition == 0) {
            enforceHasContractCode(_facetAddress, "LibDiamondCut: New facet has no code");
            _facetFunctionSelectors[_facetAddress].facetAddressPosition = uint16(_facetAddresses.length);
            _facetAddresses.push(_facetAddress);
        }
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = _selectorToFacetAndPosition[selector].facetAddress;
            require(oldFacetAddress != _facetAddress, "LibDiamondCut: Can't replace function with same function");
            removeFunction(oldFacetAddress, selector);
            // add function
            _selectorToFacetAndPosition[selector].functionSelectorPosition = selectorPosition;
            _facetFunctionSelectors[_facetAddress].functionSelectors.push(selector);
            _selectorToFacetAndPosition[selector].facetAddress = _facetAddress;
            selectorPosition++;
        }
    }

    function removeFunctions(address _facetAddress, bytes4[] memory _functionSelectors) internal {
        require(_functionSelectors.length > 0, "LibDiamondCut: No selectors in facet to cut");
        // if function does not exist then do nothing and return
        require(_facetAddress == address(0), "LibDiamondCut: Remove facet address must be address(0)");
        for (uint256 selectorIndex; selectorIndex < _functionSelectors.length; selectorIndex++) {
            bytes4 selector = _functionSelectors[selectorIndex];
            address oldFacetAddress = _selectorToFacetAndPosition[selector].facetAddress;
            removeFunction(oldFacetAddress, selector);
        }
    }

    function removeFunction(address _facetAddress, bytes4 _selector) internal {
        require(_facetAddress != address(0), "LibDiamondCut: Can't remove function that doesn't exist");
        // an immutable function is a function defined directly in a diamond
        require(_facetAddress != address(this), "LibDiamondCut: Can't remove immutable function");
        // replace selector with last selector, then delete last selector
        uint256 selectorPosition = _selectorToFacetAndPosition[_selector].functionSelectorPosition;
        uint256 lastSelectorPosition = _facetFunctionSelectors[_facetAddress].functionSelectors.length - 1;
        // if not the same then replace _selector with lastSelector
        if (selectorPosition != lastSelectorPosition) {
            bytes4 lastSelector = _facetFunctionSelectors[_facetAddress].functionSelectors[lastSelectorPosition];
            _facetFunctionSelectors[_facetAddress].functionSelectors[selectorPosition] = lastSelector;
            _selectorToFacetAndPosition[lastSelector].functionSelectorPosition = uint16(selectorPosition);
        }
        // delete the last selector
        _facetFunctionSelectors[_facetAddress].functionSelectors.pop();
        delete _selectorToFacetAndPosition[_selector];

        // if no more selectors for facet address then delete the facet address
        if (lastSelectorPosition == 0) {
            // replace facet address with last facet address and delete last facet address
            uint256 lastFacetAddressPosition = _facetAddresses.length - 1;
            uint256 facetAddressPosition = _facetFunctionSelectors[_facetAddress].facetAddressPosition;
            if (facetAddressPosition != lastFacetAddressPosition) {
                address lastFacetAddress = _facetAddresses[lastFacetAddressPosition];
                _facetAddresses[facetAddressPosition] = lastFacetAddress;
                _facetFunctionSelectors[lastFacetAddress].facetAddressPosition = uint16(facetAddressPosition);
            }
            _facetAddresses.pop();
            delete _facetFunctionSelectors[_facetAddress].facetAddressPosition;
        }
    }

    function enforceHasContractCode(address _contract, string memory _errorMessage) internal view {
        uint256 contractSize;
        assembly {
            contractSize := extcodesize(_contract)
        }
        require(contractSize > 0, _errorMessage);
    }

    // mapping(bytes4 => address) public selectorToFacet;
    // bytes4[] public selectorsList;
    // mapping(address => bool) public isFacet;
    // address[] public facetsList;

    // function addFacet(address _newFacet) public onlyOwner {
    //     isFacet[_newFacet] = true;
    //     facetsList.push(_newFacet);
    //     emit AddedFacet(_newFacet);
    // }

    // function batchAddSelectors(address _facet, bytes4[] memory _sigs) public onlyOwner {
    //     for(uint256 index; index < _sigs.length; index++) {
    //         addSelector(_facet, _sigs[index]);
    //     }
    // }

    // function addSelector(address _facet, bytes4 _sig) public onlyOwner {
    //     require(selectorToFacet[_sig] == address(0));
    //     // require(isFacet[_facet]);
    //     selectorToFacet[_sig] = _facet;
    //     selectorsList.push(_sig);
    //     emit AddedSelector(_facet, _sig);
    // }

    // Removing of the selectors occurs during resetFacetStorage();
    // it is easier to reset and rebuild using the script when deploying and updating the facets
    // function removeSelector(bytes4 _sig) public onlyOwner {
    //     selectorToFacet[_sig] = address(0);
    //     emit RemovedSelector(_sig);
    // }    

    // function getFacetAddressFromSelector(bytes4 _sig) public view returns (address) {
    //     return selectorToFacet[_sig];
    // }

    // function getFacetByIndex(uint256 _index) public view returns(address) {
    //     return facetsList[_index];
    // }

    // function resetFacetStorage() public onlyOwner {
    //     for(uint i = 0; i < selectorsList.length; i++) {
    //         bytes4 sig = selectorsList[i];
    //         selectorToFacet[sig] = address(0);
    //     }
    //     delete selectorsList;

    //     for(uint i = 0; i < facetsList.length; i++) {
    //         address facet = facetsList[i];
    //         isFacet[facet] = false;
    //     }
    //     delete facetsList;

    //     emit ResetStorage();
    // }

        // Facet getters and setters

    function getSettingsFacet() public view returns (address) {
        return facetsInfo.Settings;
    }

    function updateSettingsFacet(address _newSettingsAddress) public onlyOwner {
        facetsInfo.Settings = _newSettingsAddress;
        emit UpdatedSettingsFacet(_newSettingsAddress);
    }

    function getLosslessFacet() public view returns (address) {
        return facetsInfo.Lossless;
    }

    function updateLosslessFacet(address _newLosslessAddress) public onlyOwner {
        facetsInfo.Lossless = _newLosslessAddress;
        emit UpdatedLosslessFacet(_newLosslessAddress);
    }

    function getTaxFacet() public view returns (address) {
        return facetsInfo.Tax;
    }

    function updateTaxFacet(address _newTaxAddress) public onlyOwner {
        facetsInfo.Tax = _newTaxAddress;
        emit UpdatedTaxFacet(_newTaxAddress);
    }

    function getConstructorFacet() public view returns (address) {
        return facetsInfo.Constructor;
    }

    function updateConstructorFacet(address _newConstructorAddress) public onlyOwner {
        facetsInfo.Constructor = _newConstructorAddress;
        emit UpdatedConstructorFacet(_newConstructorAddress);
    }

    function getWalletsFacet() public view returns (address) {
        return facetsInfo.Wallets;
    }

    function updateWalletsFacet(address _newWalletsAddress) public onlyOwner {
        facetsInfo.Wallets = _newWalletsAddress;
        emit UpdatedWalletsFacet(_newWalletsAddress);
    }

    function getAntiBotFacet() public view returns (address) {
        return facetsInfo.AntiBot;
    }

    function updateAntiBotFacet(address _newAntiBotAddress) public onlyOwner {
        facetsInfo.AntiBot = _newAntiBotAddress;
        emit UpdatedAntiBotFacet(_newAntiBotAddress);
    }

    function getMulticallFacet() public view returns (address) {
        return facetsInfo.Multicall;
    }

    function updateMulticallFacet(address _newWalletsAddress) public onlyOwner {
        facetsInfo.Multicall = _newWalletsAddress;
        emit UpdatedMulticallFacet(_newWalletsAddress);
    }
} 