// SPDX-License-Identifier: UNLICENSED
// ALL RIGHTS RESERVED

// Unicrypt by SDDTech reserves all rights on this code. You may NOT copy these contracts.

pragma solidity 0.8.17;

import "./Storage.sol";
import "../BuyBackWallet.sol";
import "../LPWallet.sol";


import "../interfaces/IBuyBackWallet.sol";
import "../interfaces/ILPWallet.sol";
import "../interfaces/IFeeHelper.sol";
import "../interfaces/IMintFactory.sol";

import "../libraries/Ownable.sol";

contract SettingsFacet is Ownable {
    Storage internal s;

    event AddedLPToken(address _newLPToken);
    event RemovedLPToken(address _lpToken);
    event AddedBlacklistAddress(address _address);
    event RemovedBlacklistAddress(address _address);
    event ToggledPause(bool _isPaused);
    event UpdatedCustomTaxes(CustomTax[] _customTaxes);
    event UpdatedTaxFees(Fees _updatedFees);
    event UpdatedTransactionTaxAddress(address _newAddress);
    event UpdatedLockedSettings(TaxSettings _updatedLocks);
    event UpdatedSettings(TaxSettings _updatedSettings);
    event UpdatedPairAddress(address _newPairAddress);
    event UpdatedTaxHelperIndex(uint _newIndex);
    event AddedTaxWhitelistAddress(address _address);   
    event RemovedTaxWhitelistAddress(address _address);

    function canBlacklistRequire() internal view {
        require(s.taxSettings.canBlacklist, "NB");
    }

    modifier canBlacklist {
        canBlacklistRequire();
        _;
    }

    function addLPToken(address _newLPToken) public onlyOwner {
        s.lpTokens[_newLPToken] = true;
        emit AddedLPToken(_newLPToken);
    }

    function removeLPToken(address _lpToken) public onlyOwner {
        s.lpTokens[_lpToken] = false;
        emit RemovedLPToken(_lpToken);
    }

    function checkMaxTax(bool isBuy) internal view returns (bool) {
        uint256 totalTaxes;
        if(isBuy) {
            totalTaxes += s.fees.transactionTax.buy;
            totalTaxes += s.fees.holderTax;
            for(uint i = 0; i < s.customTaxes.length; i++) {
                totalTaxes += s.customTaxes[i].fee.buy;
            }
        } else {
            totalTaxes += s.fees.transactionTax.sell;
            totalTaxes += s.fees.lpTax;
            totalTaxes += s.fees.holderTax;
            totalTaxes += s.fees.buyBackTax;
            for(uint i = 0; i < s.customTaxes.length; i++) {
                totalTaxes += s.customTaxes[i].fee.sell;
            }
        }
        if(totalTaxes <= s.MaxTax) {
            return true;
        }
        return false;
    }

    function paused() public view returns (bool) {
        if(s.taxSettings.canPause == false) {
            return false;
        }
        return s.isPaused;
    }

    function togglePause() public onlyOwner returns (bool) {
        require(s.taxSettings.canPause, "NP");
        s.isPaused = !s.isPaused;
        emit ToggledPause(s.isPaused);
        return s.isPaused;
    }

    function addBlacklistedAddress(address _address) public onlyOwner canBlacklist {
        IFeeHelper feeHelper = IFeeHelper(IMintFactory(s.factory).getFeeHelper());
        address feeAddress = feeHelper.getFeeAddress();
        require(_address != feeAddress);
        s.blacklist[_address] = true;
        emit AddedBlacklistAddress(_address);
    }

    function removeBlacklistedAddress(address _address) public onlyOwner canBlacklist {
        s.blacklist[_address] = false;
        emit RemovedBlacklistAddress(_address);
    }

    function updateBlacklistBatch(address[] calldata _updatedAddresses, bool _isBlacklisted) public onlyOwner canBlacklist {
        IFeeHelper feeHelper = IFeeHelper(IMintFactory(s.factory).getFeeHelper());
        address feeAddress = feeHelper.getFeeAddress();
        for(uint i = 0; i < _updatedAddresses.length; i++) {
            if(_updatedAddresses[i] != feeAddress) {
                s.blacklist[_updatedAddresses[i]] = _isBlacklisted;
                if(_isBlacklisted) {
                    emit AddedBlacklistAddress(_updatedAddresses[i]);
                } else {
                    emit RemovedBlacklistAddress(_updatedAddresses[i]);
                }
            }
        }
    }

    function isBlacklisted(address _address) public view returns (bool) {
        return s.blacklist[_address];
    }

    function updateCustomTaxes(CustomTax[] calldata _customTaxes) public onlyOwner {
        require(_customTaxes.length < s.MaxCustom + 1, "MCT");
        delete s.customTaxes;

        for(uint i = 0; i < _customTaxes.length; i++) {
            require(_customTaxes[i].wallet != address(0));
            s.customTaxes.push(_customTaxes[i]);
        }
        s.customTaxLength = _customTaxes.length;

        require(checkMaxTax(true), "BF");
        require(checkMaxTax(false), "SF");
        emit UpdatedCustomTaxes(_customTaxes);
    }

    function updateTaxFees(Fees calldata _updatedFees) public onlyOwner {
        s.fees.transactionTax.buy = _updatedFees.transactionTax.buy;
        s.fees.transactionTax.sell = _updatedFees.transactionTax.sell;

        s.fees.buyBackTax = _updatedFees.buyBackTax;

        s.fees.holderTax = _updatedFees.holderTax;

        s.fees.lpTax = _updatedFees.lpTax;

        require(checkMaxTax(true), "BF");
        require(checkMaxTax(false), "SF");
        emit UpdatedTaxFees(_updatedFees);
    }

    function updateTransactionTaxAddress(address _newAddress) public onlyOwner {
        // confirm if this is updateable
        require(_newAddress != address(0));
        s.transactionTaxWallet = _newAddress;
        emit UpdatedTransactionTaxAddress(_newAddress);
    }

    function lockSettings(TaxSettings calldata _updatedLocks) public onlyOwner {
        if(!s.isLocked.transactionTax) {
            s.isLocked.transactionTax = _updatedLocks.transactionTax;
        }
        if(!s.isLocked.holderTax) {
            s.isLocked.holderTax = _updatedLocks.holderTax;
        }
        if(!s.isLocked.buyBackTax) {
            s.isLocked.buyBackTax = _updatedLocks.buyBackTax;
        }
        if(!s.isLocked.lpTax) {
            s.isLocked.lpTax = _updatedLocks.lpTax;
        }
        if(!s.isLocked.canMint) {
            s.isLocked.canMint = _updatedLocks.canMint;
        }
        if(!s.isLocked.canPause) {
            s.isLocked.canPause = _updatedLocks.canPause;
        }
        if(!s.isLocked.canBlacklist) {
            s.isLocked.canBlacklist = _updatedLocks.canBlacklist;
        }
        if(!s.isLocked.maxBalanceAfterBuy) {
            s.isLocked.maxBalanceAfterBuy = _updatedLocks.maxBalanceAfterBuy;
        }
        emit UpdatedLockedSettings(s.isLocked);
    }

    function updateSettings(TaxSettings calldata _updatedSettings) public onlyOwner {
        if(!s.isLocked.transactionTax && s.taxSettings.transactionTax != _updatedSettings.transactionTax) {
            s.taxSettings.transactionTax = _updatedSettings.transactionTax;
        }
        if(!s.isLocked.holderTax && s.taxSettings.holderTax != _updatedSettings.holderTax && !_updatedSettings.canMint) {
            s.taxSettings.holderTax = _updatedSettings.holderTax;
        }
        if(!s.isLocked.buyBackTax && s.taxSettings.buyBackTax != _updatedSettings.buyBackTax) {
            s.taxSettings.buyBackTax = _updatedSettings.buyBackTax;
        }
        if(!s.isLocked.lpTax && s.taxSettings.lpTax != _updatedSettings.lpTax) {
            s.taxSettings.lpTax = _updatedSettings.lpTax;
        }
        if(!s.isLocked.canMint && s.taxSettings.canMint != _updatedSettings.canMint && !s.taxSettings.holderTax) {
            s.taxSettings.canMint = _updatedSettings.canMint;
        }
        if(!s.isLocked.canPause && s.taxSettings.canPause != _updatedSettings.canPause) {
            s.taxSettings.canPause = _updatedSettings.canPause;
        }
        if(!s.isLocked.canBlacklist && s.taxSettings.canBlacklist != _updatedSettings.canBlacklist) {
            s.taxSettings.canBlacklist = _updatedSettings.canBlacklist;
        }
        if(!s.isLocked.maxBalanceAfterBuy && s.taxSettings.maxBalanceAfterBuy != _updatedSettings.maxBalanceAfterBuy) {
            s.taxSettings.maxBalanceAfterBuy = _updatedSettings.maxBalanceAfterBuy;
        }
        emit UpdatedSettings(s.taxSettings);
    }

    function updatePairAddress(address _newPairAddress) public onlyOwner {
        s.pairAddress = _newPairAddress;
        s.lpTokens[_newPairAddress] = true;
        emit AddedLPToken(_newPairAddress);
        emit UpdatedPairAddress(_newPairAddress);
    }

    function updateTaxHelperIndex(uint8 _newIndex) public onlyOwner {
        s.taxHelperIndex = _newIndex;
        emit UpdatedTaxHelperIndex(_newIndex);
    }

    function addTaxWhitelistedAddress(address _address) public onlyOwner {
        s.taxWhitelist[_address] = true;
        emit AddedTaxWhitelistAddress(_address);
    }

    function removeTaxWhitelistedAddress(address _address) public onlyOwner {
        s.taxWhitelist[_address] = false;
        emit RemovedTaxWhitelistAddress(_address);
    }

    function updateTaxWhitelistBatch(address[] calldata _updatedAddresses, bool _isTaxWhitelisted) public onlyOwner {
        for(uint i = 0; i < _updatedAddresses.length; i++) {
            s.taxWhitelist[_updatedAddresses[i]] = _isTaxWhitelisted;
            if(_isTaxWhitelisted) {
                emit AddedTaxWhitelistAddress(_updatedAddresses[i]);
            } else {
                emit RemovedTaxWhitelistAddress(_updatedAddresses[i]);
            }
        }
    }
}