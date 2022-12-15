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

contract SettingsFacet is Storage, Ownable {

    function canBlacklistRequire() internal view {
        require(taxSettings.canBlacklist, "NB");
    }

    modifier canBlacklist {
        canBlacklistRequire();
        _;
    }

    function addLPToken(address _newLPToken) public onlyOwner {
        lpTokens[_newLPToken] = true;
        emit AddedLPToken(_newLPToken);
    }

    function removeLPToken(address _lpToken) public onlyOwner {
        lpTokens[_lpToken] = false;
        emit RemovedLPToken(_lpToken);
    }

    function checkMaxTax(bool isBuy) internal view returns (bool) {
        uint256 totalTaxes;
        if(isBuy) {
            totalTaxes += fees.transactionTax.buy;
            totalTaxes += fees.holderTax;
            for(uint i = 0; i < customTaxes.length; i++) {
                totalTaxes += customTaxes[i].fee.buy;
            }
        } else {
            totalTaxes += fees.transactionTax.sell;
            totalTaxes += fees.lpTax;
            totalTaxes += fees.holderTax;
            totalTaxes += fees.buyBackTax;
            for(uint i = 0; i < customTaxes.length; i++) {
                totalTaxes += customTaxes[i].fee.sell;
            }
        }
        if(totalTaxes <= MaxTax) {
            return true;
        }
        return false;
    }

    function paused() public view returns (bool) {
        if(taxSettings.canPause == false) {
            return false;
        }
        return isPaused;
    }

    function togglePause() public onlyOwner returns (bool) {
        require(taxSettings.canPause, "NP");
        isPaused = !isPaused;
        emit ToggledPause(isPaused);
        return isPaused;
    }

    function addBlacklistedAddress(address _address) public onlyOwner canBlacklist {
        IFeeHelper feeHelper = IFeeHelper(IMintFactory(factory).getFeeHelper());
        address feeAddress = feeHelper.getFeeAddress();
        require(_address != feeAddress);
        blacklist[_address] = true;
        emit AddedBlacklistAddress(_address);
    }

    function removeBlacklistedAddress(address _address) public onlyOwner canBlacklist {
        blacklist[_address] = false;
        emit RemovedBlacklistAddress(_address);
    }

    function updateBlacklistBatch(address[] calldata _updatedAddresses, bool _isBlacklisted) public onlyOwner canBlacklist {
        IFeeHelper feeHelper = IFeeHelper(IMintFactory(factory).getFeeHelper());
        address feeAddress = feeHelper.getFeeAddress();
        for(uint i = 0; i < _updatedAddresses.length; i++) {
            if(_updatedAddresses[i] != feeAddress) {
                blacklist[_updatedAddresses[i]] = _isBlacklisted;
                if(_isBlacklisted) {
                    emit AddedBlacklistAddress(_updatedAddresses[i]);
                } else {
                    emit RemovedBlacklistAddress(_updatedAddresses[i]);
                }
            }
        }
    }

    function isBlacklisted(address _address) public view returns (bool) {
        return blacklist[_address];
    }

    function updateCustomTaxes(CustomTax[] calldata _customTaxes) public onlyOwner {
        require(_customTaxes.length < MaxCustom + 1, "MCT");
        delete customTaxes;

        for(uint i = 0; i < _customTaxes.length; i++) {
            require(_customTaxes[i].wallet != address(0));
            customTaxes.push(_customTaxes[i]);
        }
        customTaxLength = _customTaxes.length;

        require(checkMaxTax(true), "BF");
        require(checkMaxTax(false), "SF");
        emit UpdatedCustomTaxes(_customTaxes);
    }

    function updateTaxFees(Fees calldata _updatedFees) public onlyOwner {
        fees.transactionTax.buy = _updatedFees.transactionTax.buy;
        fees.transactionTax.sell = _updatedFees.transactionTax.sell;

        fees.buyBackTax = _updatedFees.buyBackTax;

        fees.holderTax = _updatedFees.holderTax;

        fees.lpTax = _updatedFees.lpTax;

        require(checkMaxTax(true), "BF");
        require(checkMaxTax(false), "SF");
        emit UpdatedTaxFees(_updatedFees);
    }

    function updateTransactionTaxAddress(address _newAddress) public onlyOwner {
        // confirm if this is updateable
        require(_newAddress != address(0));
        transactionTaxWallet = _newAddress;
        emit UpdatedTransactionTaxAddress(_newAddress);
    }

    function lockSettings(TaxSettings calldata _updatedLocks) public onlyOwner {
        if(!isLocked.transactionTax) {
            isLocked.transactionTax = _updatedLocks.transactionTax;
        }
        if(!isLocked.holderTax) {
            isLocked.holderTax = _updatedLocks.holderTax;
        }
        if(!isLocked.buyBackTax) {
            isLocked.buyBackTax = _updatedLocks.buyBackTax;
        }
        if(!isLocked.lpTax) {
            isLocked.lpTax = _updatedLocks.lpTax;
        }
        if(!isLocked.canMint) {
            isLocked.canMint = _updatedLocks.canMint;
        }
        if(!isLocked.canPause) {
            isLocked.canPause = _updatedLocks.canPause;
        }
        if(!isLocked.canBlacklist) {
            isLocked.canBlacklist = _updatedLocks.canBlacklist;
        }
        if(!isLocked.maxBalanceAfterBuy) {
            isLocked.maxBalanceAfterBuy = _updatedLocks.maxBalanceAfterBuy;
        }
        emit UpdatedLockedSettings(isLocked);
    }

    function updateSettings(TaxSettings calldata _updatedSettings) public onlyOwner {
        if(!isLocked.transactionTax && taxSettings.transactionTax != _updatedSettings.transactionTax) {
            taxSettings.transactionTax = _updatedSettings.transactionTax;
        }
        if(!isLocked.holderTax && taxSettings.holderTax != _updatedSettings.holderTax && !_updatedSettings.canMint) {
            taxSettings.holderTax = _updatedSettings.holderTax;
        }
        if(!isLocked.buyBackTax && taxSettings.buyBackTax != _updatedSettings.buyBackTax) {
            taxSettings.buyBackTax = _updatedSettings.buyBackTax;
        }
        if(!isLocked.lpTax && taxSettings.lpTax != _updatedSettings.lpTax) {
            taxSettings.lpTax = _updatedSettings.lpTax;
        }
        if(!isLocked.canMint && taxSettings.canMint != _updatedSettings.canMint && !taxSettings.holderTax) {
            taxSettings.canMint = _updatedSettings.canMint;
        }
        if(!isLocked.canPause && taxSettings.canPause != _updatedSettings.canPause) {
            taxSettings.canPause = _updatedSettings.canPause;
        }
        if(!isLocked.canBlacklist && taxSettings.canBlacklist != _updatedSettings.canBlacklist) {
            taxSettings.canBlacklist = _updatedSettings.canBlacklist;
        }
        if(!isLocked.maxBalanceAfterBuy && taxSettings.maxBalanceAfterBuy != _updatedSettings.maxBalanceAfterBuy) {
            taxSettings.maxBalanceAfterBuy = _updatedSettings.maxBalanceAfterBuy;
        }
        emit UpdatedSettings(taxSettings);
    }

    function updatePairAddress(address _newPairAddress) public onlyOwner {
        pairAddress = _newPairAddress;
        emit UpdatedPairAddress(_newPairAddress);
    }

    function updateTaxHelperIndex(uint8 _newIndex) public onlyOwner {
        taxHelperIndex = _newIndex;
        emit UpdatedTaxHelperIndex(_newIndex);
    }
}