// SPDX-License-Identifier: UNLICENSED
// ALL RIGHTS RESERVED

// Unicrypt by SDDTech reserves all rights on this code. You may NOT copy these contracts.

pragma solidity 0.8.17;

import "./Storage.sol";

import "../interfaces/IMintFactory.sol";

import "../libraries/Ownable.sol";

contract AntiBotFacet is Ownable {
    Storage internal s;

    event UpdatedAntiBotIncrement(uint256 _updatedIncrement);
    event UpdatedAntiBotEndDate(uint256 _updatedEndDate);
    event UpdatedAntiBotInitialMaxHold(uint256 _updatedInitialMaxHold);
    event UpdatedAntiBotActiveStatus(bool _isActive);
    event UpdatedSwapWhitelistingEndDate(uint256 _updatedEndDate);
    event UpdatedSwapWhitelistingActiveStatus(bool _isActive);
    event UpdatedMaxBalanceAfterBuy(uint256 _newMaxBalance);

    event AddedMaxBalanceWhitelistAddress(address _address);   
    event RemovedMaxBalanceWhitelistAddress(address _address);        
    event AddedSwapWhitelistAddress(address _address);
    event RemovedSwapWhitelistAddress(address _address);
    
    // AntiBot

    function antiBotIsActiveModifier() view internal {
        require(s.antiBotSettings.isActive, "ABD");
    }

    modifier antiBotIsActive() {
        antiBotIsActiveModifier();
        _;
    }

    function setIncrement(uint256 _updatedIncrement) public onlyOwner antiBotIsActive {
        s.antiBotSettings.increment = _updatedIncrement;
        emit UpdatedAntiBotIncrement(_updatedIncrement);
    }

    function setEndDate( uint256 _updatedEndDate) public onlyOwner antiBotIsActive {
        require(_updatedEndDate <= 48, "ED");
        s.antiBotSettings.endDate = _updatedEndDate;
        emit UpdatedAntiBotEndDate(_updatedEndDate);
    }

    function setInitialMaxHold( uint256 _updatedInitialMaxHold) public onlyOwner antiBotIsActive {
        s.antiBotSettings.initialMaxHold = _updatedInitialMaxHold;
        emit UpdatedAntiBotInitialMaxHold(_updatedInitialMaxHold);
    }

    function updateAntiBot(bool _isActive) public onlyOwner {
        require(!s.marketInit, "AMIE");
        s.antiBotSettings.isActive = _isActive;
        emit UpdatedAntiBotActiveStatus(_isActive);
    }

    function antiBotCheck(uint256 amount, address receiver) public returns(bool) {
        // restrict it to being only called by registered tokens
        require(IMintFactory(s.factory).tokenIsRegistered(address(this)));
        require(s.marketInit, "AMIE");
        if(block.timestamp > s.marketInitBlockTime + (s.antiBotSettings.endDate * 1 hours)) {
            s.antiBotSettings.isActive = false;
            return true;
        }

        s.antiBotBalanceTracker[receiver] += amount;
        uint256 userAntiBotBalance = s.antiBotBalanceTracker[receiver];
        uint256 maxAntiBotBalance = ((block.number - s.antiBotSettings.startBlock) * s.antiBotSettings.increment) + s.antiBotSettings.initialMaxHold;

        require((userAntiBotBalance <= maxAntiBotBalance), "ABMSA");
        return true;
    }

    // MaxBalanceAfterBuy
   
    function addMaxBalanceWhitelistedAddress(address _address) public onlyOwner {
        require(s.taxSettings.maxBalanceAfterBuy, "AMBABD");
        s.maxBalanceWhitelist[_address] = true;
        emit AddedMaxBalanceWhitelistAddress(_address);
    }

    function removeMaxBalanceWhitelistedAddress(address _address) public onlyOwner {
        require(s.taxSettings.maxBalanceAfterBuy, "AMBABD");
        s.maxBalanceWhitelist[_address] = false;
        emit RemovedMaxBalanceWhitelistAddress(_address);
    }

    function updateMaxBalanceWhitelistBatch(address[] calldata _updatedAddresses, bool _isMaxBalanceWhitelisted) public onlyOwner {
        require(s.taxSettings.maxBalanceAfterBuy, "AMBABD");
        for(uint i = 0; i < _updatedAddresses.length; i++) {
            s.maxBalanceWhitelist[_updatedAddresses[i]] = _isMaxBalanceWhitelisted;
            if(_isMaxBalanceWhitelisted) {
                emit AddedMaxBalanceWhitelistAddress(_updatedAddresses[i]);
            } else {
                emit RemovedMaxBalanceWhitelistAddress(_updatedAddresses[i]);
            }
        }
    }

    function isMaxBalanceWhitelisted(address _address) public view returns (bool) {
        return s.maxBalanceWhitelist[_address];
    }

    function updateMaxBalanceAfterBuy(uint256 _updatedMaxBalanceAfterBuy) public onlyOwner {
        require(s.taxSettings.maxBalanceAfterBuy, "AMBABD");
        s.maxBalanceAfterBuy = _updatedMaxBalanceAfterBuy;
        emit UpdatedMaxBalanceAfterBuy(_updatedMaxBalanceAfterBuy);
    }

    function maxBalanceAfterBuyCheck(uint256 amount, address receiver) public view returns(bool) {
        if(s.maxBalanceWhitelist[receiver]) {
            return true;
        }
        require(s.taxSettings.maxBalanceAfterBuy);
        uint256 receiverBalance;
        if(s.taxSettings.holderTax) {
            receiverBalance = s._rOwned[receiver];
        } else {
            receiverBalance = s._tOwned[receiver];
        }
        receiverBalance += amount;
        require(receiverBalance <= s.maxBalanceAfterBuy, "MBAB");
        return true;
    }

    // SwapWhitelist

    function addSwapWhitelistedAddress(address _address) public onlyOwner {
        require(s.swapWhitelistingSettings.isActive, "ASWD");
        s.swapWhitelist[_address] = true;
        emit AddedSwapWhitelistAddress(_address);
    }

    function removeSwapWhitelistedAddress(address _address) public onlyOwner {
        require(s.swapWhitelistingSettings.isActive, "ASWD");
        s.swapWhitelist[_address] = false;
        emit RemovedSwapWhitelistAddress(_address);
    }

    function updateSwapWhitelistBatch(address[] calldata _updatedAddresses, bool _isSwapWhitelisted) public onlyOwner {
        require(s.swapWhitelistingSettings.isActive, "ASWD");
        for(uint i = 0; i < _updatedAddresses.length; i++) {
            s.swapWhitelist[_updatedAddresses[i]] = _isSwapWhitelisted;
            if(_isSwapWhitelisted) {
                emit AddedSwapWhitelistAddress(_updatedAddresses[i]);
            } else {
                emit RemovedSwapWhitelistAddress(_updatedAddresses[i]);
            }
        }
    }

    function isSwapWhitelisted(address _address) public view returns (bool) {
        return s.swapWhitelist[_address];
    }

    function setSwapWhitelistEndDate( uint256 _updatedEndDate) public onlyOwner {
        require(s.swapWhitelistingSettings.isActive, "ASWD");
        require(_updatedEndDate <= 48, "ED");
        s.swapWhitelistingSettings.endDate = _updatedEndDate;
        emit UpdatedSwapWhitelistingEndDate(_updatedEndDate);
    }

    function updateSwapWhitelisting(bool _isActive) public onlyOwner {
        require(!s.marketInit, "AMIE");
        s.swapWhitelistingSettings.isActive = _isActive;
        emit UpdatedSwapWhitelistingActiveStatus(_isActive);
    }

    function swapWhitelistingCheck(address receiver) public returns(bool) {
        require(s.marketInit, "AMIE");
        if(block.timestamp > s.marketInitBlockTime + (s.swapWhitelistingSettings.endDate * 1 hours)) {
            s.swapWhitelistingSettings.isActive = false;
            return true;
        }
        require(s.swapWhitelist[receiver], "SWL");
        return true;
    }
}