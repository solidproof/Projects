// SPDX-License-Identifier: UNLICENSED
// ALL RIGHTS RESERVED

// Unicrypt by SDDTech reserves all rights on this code. You may NOT copy these contracts.

pragma solidity 0.8.17;

import "./Storage.sol";

import "../interfaces/IMintFactory.sol";

import "../libraries/Ownable.sol";

contract AntiBotFacet is Storage, Ownable {

    // AntiBot

    function antiBotIsActiveModifier() view internal {
        require(antiBotSettings.isActive, "ABD");
    }

    modifier antiBotIsActive() {
        antiBotIsActiveModifier();
        _;
    }

    function setIncrement(uint256 _updatedIncrement) public onlyOwner antiBotIsActive {
        antiBotSettings.increment = _updatedIncrement;
        emit UpdatedAntiBotIncrement(_updatedIncrement);
    }

    function setEndDate( uint256 _updatedEndDate) public onlyOwner antiBotIsActive {
        require(_updatedEndDate <= 48, "ED");
        antiBotSettings.endDate = _updatedEndDate;
        emit UpdatedAntiBotEndDate(_updatedEndDate);
    }

    function setInitialMaxHold( uint256 _updatedInitialMaxHold) public onlyOwner antiBotIsActive {
        antiBotSettings.initialMaxHold = _updatedInitialMaxHold;
        emit UpdatedAntiBotInitialMaxHold(_updatedInitialMaxHold);
    }

    function updateAntiBot(bool _isActive) public onlyOwner {
        require(!marketInit, "AMIE");
        antiBotSettings.isActive = _isActive;
        emit UpdatedAntiBotActiveStatus(_isActive);
    }

    function antiBotCheck(uint256 amount, address receiver) public returns(bool) {
        // restrict it to being only called by registered tokens
        require(IMintFactory(factory).tokenIsRegistered(address(this)));
        require(marketInit, "AMIE");
        if(block.timestamp > marketInitBlockTime + (antiBotSettings.endDate * 1 hours)) {
            antiBotSettings.isActive = false;
            return true;
        }

        antiBotBalanceTracker[receiver] += amount;
        uint256 userAntiBotBalance = antiBotBalanceTracker[receiver];
        uint256 maxAntiBotBalance = ((block.number - antiBotSettings.startBlock) * antiBotSettings.increment) + antiBotSettings.initialMaxHold;

        require((userAntiBotBalance <= maxAntiBotBalance), "ABMSA");
        return true;
    }

    // MaxBalanceAfterBuy
   
    function addMaxBalanceWhitelistedAddress(address _address) public onlyOwner {
        require(swapWhitelistingSettings.isActive, "AMBABD");
        maxBalanceWhitelist[_address] = true;
        emit AddedMaxBalanceWhitelistAddress(_address);
    }

    function removeMaxBalanceWhitelistedAddress(address _address) public onlyOwner {
        require(swapWhitelistingSettings.isActive, "AMBABD");
        maxBalanceWhitelist[_address] = false;
        emit RemovedMaxBalanceWhitelistAddress(_address);
    }

    function updateMaxBalanceWhitelistBatch(address[] calldata _updatedAddresses, bool _isMaxBalanceWhitelisted) public onlyOwner {
        require(swapWhitelistingSettings.isActive, "AMBABD");
        for(uint i = 0; i < _updatedAddresses.length; i++) {
            maxBalanceWhitelist[_updatedAddresses[i]] = _isMaxBalanceWhitelisted;
            if(_isMaxBalanceWhitelisted) {
                emit AddedMaxBalanceWhitelistAddress(_updatedAddresses[i]);
            } else {
                emit RemovedMaxBalanceWhitelistAddress(_updatedAddresses[i]);
            }
        }
    }

    function isMaxBalanceWhitelisted(address _address) public view returns (bool) {
        return swapWhitelist[_address];
    }

    function updateMaxBalanceAfterBuy(uint256 _updatedMaxBalanceAfterBuy) public onlyOwner {
        require(taxSettings.maxBalanceAfterBuy, "AMBABD");
        maxBalanceAfterBuy = _updatedMaxBalanceAfterBuy;
        emit UpdatedMaxBalanceAfterBuy(_updatedMaxBalanceAfterBuy);
    }

    function maxBalanceAfterBuyCheck(uint256 amount, address receiver) public view returns(bool) {
        if(maxBalanceWhitelist[receiver]) {
            return true;
        }
        require(taxSettings.maxBalanceAfterBuy);
        uint256 receiverBalance;
        if(taxSettings.holderTax) {
            receiverBalance = _rOwned[receiver];
        } else {
            receiverBalance = _tOwned[receiver];
        }
        receiverBalance += amount;
        require(receiverBalance <= maxBalanceAfterBuy, "MBAB");
        return true;
    }

    // SwapWhitelist

    function addSwapWhitelistedAddress(address _address) public onlyOwner {
        require(swapWhitelistingSettings.isActive, "ASWD");
        swapWhitelist[_address] = true;
        emit AddedSwapWhitelistAddress(_address);
    }

    function removeSwapWhitelistedAddress(address _address) public onlyOwner {
        require(swapWhitelistingSettings.isActive, "ASWD");
        swapWhitelist[_address] = false;
        emit RemovedSwapWhitelistAddress(_address);
    }

    function updateSwapWhitelistBatch(address[] calldata _updatedAddresses, bool _isSwapWhitelisted) public onlyOwner {
        require(swapWhitelistingSettings.isActive, "ASWD");
        for(uint i = 0; i < _updatedAddresses.length; i++) {
            swapWhitelist[_updatedAddresses[i]] = _isSwapWhitelisted;
            if(_isSwapWhitelisted) {
                emit AddedSwapWhitelistAddress(_updatedAddresses[i]);
            } else {
                emit RemovedSwapWhitelistAddress(_updatedAddresses[i]);
            }
        }
    }

    function isSwapWhitelisted(address _address) public view returns (bool) {
        return swapWhitelist[_address];
    }

    function setSwapWhitelistEndDate( uint256 _updatedEndDate) public onlyOwner {
        require(swapWhitelistingSettings.isActive, "ASWD");
        require(_updatedEndDate <= 48, "ED");
        swapWhitelistingSettings.endDate = _updatedEndDate;
        emit UpdatedSwapWhitelistingEndDate(_updatedEndDate);
    }

    function updateSwapWhitelisting(bool _isActive) public onlyOwner {
        require(!marketInit, "AMIE");
        swapWhitelistingSettings.isActive = _isActive;
        emit UpdatedSwapWhitelistingActiveStatus(_isActive);
    }

    function swapWhitelistingCheck(address receiver) public returns(bool) {
        require(marketInit, "AMIE");
        if(block.timestamp > marketInitBlockTime + (swapWhitelistingSettings.endDate * 1 hours)) {
            swapWhitelistingSettings.isActive = false;
            return true;
        }
        require(swapWhitelist[receiver], "SWL");
        return true;
    }
}