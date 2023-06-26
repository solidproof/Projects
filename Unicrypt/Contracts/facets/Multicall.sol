// SPDX-License-Identifier: UNLICENSED
// ALL RIGHTS RESERVED

// Unicrypt by SDDTech reserves all rights on this code. You may NOT copy these contracts.

pragma solidity 0.8.17;

import "./Storage.sol";

import "../libraries/Ownable.sol";
import "../interfaces/ILPWallet.sol";
import "../interfaces/IBuyBackWallet.sol";

contract MulticallFacet is Ownable {
    Storage internal s;

    event UpdatedSettings(TaxSettings _updatedSettings);
    event UpdatedLockedSettings(TaxSettings _updatedLocks);
    event UpdatedCustomTaxes(CustomTax[] _customTaxes);
    event UpdatedTaxFees(Fees _updatedFees);
    event UpdatedTransactionTaxAddress(address _newAddress);
    event UpdatedMaxBalanceAfterBuy(uint256 _newMaxBalance);
    event UpdatedBuyBackWalletThreshold(uint256 _newThreshold);
    event UpdatedLPWalletThreshold(uint256 _newThreshold);
    event UpdatedAntiBotIncrement(uint256 _updatedIncrement);
    event UpdatedAntiBotEndDate(uint256 _updatedEndDate);
    event UpdatedAntiBotInitialMaxHold(uint256 _updatedInitialMaxHold);
    event UpdatedAntiBotActiveStatus(bool _isActive);
    event UpdatedSwapWhitelistingEndDate(uint256 _updatedEndDate);
    event UpdatedSwapWhitelistingActiveStatus(bool _isActive);

    struct MulticallAdminUpdateParams {
        TaxSettings _taxSettings;
        TaxSettings _lockSettings;
        CustomTax[] _customTaxes;
        Fees _fees;
        address _transactionTaxWallet;
        uint256 _maxBalanceAfterBuy;
        uint256 _lpWalletThreshold;
        uint256 _buyBackWalletThreshold;
    }

    function multicallAdminUpdate(MulticallAdminUpdateParams calldata params) public onlyOwner {
        // Tax Settings
        if(!s.isLocked.transactionTax && s.taxSettings.transactionTax != params._taxSettings.transactionTax) {
            s.taxSettings.transactionTax = params._taxSettings.transactionTax;
        }
        if(!s.isLocked.holderTax && s.taxSettings.holderTax != params._taxSettings.holderTax && !params._taxSettings.canMint) {
            s.taxSettings.holderTax = params._taxSettings.holderTax;
        }
        if(!s.isLocked.buyBackTax && s.taxSettings.buyBackTax != params._taxSettings.buyBackTax) {
            s.taxSettings.buyBackTax = params._taxSettings.buyBackTax;
        }
        if(!s.isLocked.lpTax && s.taxSettings.lpTax != params._taxSettings.lpTax) {
            s.taxSettings.lpTax = params._taxSettings.lpTax;
        }
        if(!s.isLocked.canMint && s.taxSettings.canMint != params._taxSettings.canMint && !s.taxSettings.holderTax) {
            s.taxSettings.canMint = params._taxSettings.canMint;
        }
        if(!s.isLocked.canPause && s.taxSettings.canPause != params._taxSettings.canPause) {
            s.taxSettings.canPause = params._taxSettings.canPause;
        }
        if(!s.isLocked.canBlacklist && s.taxSettings.canBlacklist != params._taxSettings.canBlacklist) {
            s.taxSettings.canBlacklist = params._taxSettings.canBlacklist;
        }
        if(!s.isLocked.maxBalanceAfterBuy && s.taxSettings.maxBalanceAfterBuy != params._taxSettings.maxBalanceAfterBuy) {
            s.taxSettings.maxBalanceAfterBuy = params._taxSettings.maxBalanceAfterBuy;
        }
        emit UpdatedSettings(s.taxSettings);


        // Lock Settings
        if(!s.isLocked.transactionTax) {
            s.isLocked.transactionTax = params._lockSettings.transactionTax;
        }
        if(!s.isLocked.holderTax) {
            s.isLocked.holderTax = params._lockSettings.holderTax;
        }
        if(!s.isLocked.buyBackTax) {
            s.isLocked.buyBackTax = params._lockSettings.buyBackTax;
        }
        if(!s.isLocked.lpTax) {
            s.isLocked.lpTax = params._lockSettings.lpTax;
        }
        if(!s.isLocked.canMint) {
            s.isLocked.canMint = params._lockSettings.canMint;
        }
        if(!s.isLocked.canPause) {
            s.isLocked.canPause = params._lockSettings.canPause;
        }
        if(!s.isLocked.canBlacklist) {
            s.isLocked.canBlacklist = params._lockSettings.canBlacklist;
        }
        if(!s.isLocked.maxBalanceAfterBuy) {
            s.isLocked.maxBalanceAfterBuy = params._lockSettings.maxBalanceAfterBuy;
        }
        emit UpdatedLockedSettings(s.isLocked);


        // Custom Taxes
        require(params._customTaxes.length < s.MaxCustom + 1, "MCT");
        delete s.customTaxes;

        for(uint i = 0; i < params._customTaxes.length; i++) {
            require(params._customTaxes[i].wallet != address(0), "ZA");
            s.customTaxes.push(params._customTaxes[i]);
        }
        s.customTaxLength = params._customTaxes.length;
        emit UpdatedCustomTaxes(params._customTaxes);

        // Fees        
        s.fees.transactionTax.buy = params._fees.transactionTax.buy;
        s.fees.transactionTax.sell = params._fees.transactionTax.sell;

        s.fees.buyBackTax = params._fees.buyBackTax;

        s.fees.holderTax = params._fees.holderTax;

        s.fees.lpTax = params._fees.lpTax;

        require(checkMaxTax(true), "BF");
        require(checkMaxTax(false), "SF");
        emit UpdatedTaxFees(params._fees);
        
        // transactionTax address
        require(params._transactionTaxWallet != address(0), "ZA");
        s.transactionTaxWallet = params._transactionTaxWallet;
        emit UpdatedTransactionTaxAddress(params._transactionTaxWallet);

        // maxBalanceAfterBuy
        if(s.taxSettings.maxBalanceAfterBuy) {
            s.maxBalanceAfterBuy = params._maxBalanceAfterBuy;
            emit UpdatedMaxBalanceAfterBuy(params._maxBalanceAfterBuy);
        }

        // update wallet thresholds
        ILPWallet(s.lpWallet).updateThreshold(params._lpWalletThreshold);
        emit UpdatedLPWalletThreshold(params._lpWalletThreshold);

        IBuyBackWallet(s.buyBackWallet).updateThreshold(params._buyBackWalletThreshold);
        emit UpdatedBuyBackWalletThreshold(params._buyBackWalletThreshold);
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

    struct AntiBotUpdateParams {
        AntiBotSettings _antiBotSettings;
        SwapWhitelistingSettings _swapWhitelistingSettings;
    }

    // Multicall AntiBot Update
    function multicallAntiBotUpdate(AntiBotUpdateParams calldata params) public onlyOwner {
        // AntiBot
        s.antiBotSettings.increment = params._antiBotSettings.increment;
        emit UpdatedAntiBotIncrement(s.antiBotSettings.increment);

        require(params._antiBotSettings.endDate <= 48, "ED");
        s.antiBotSettings.endDate = params._antiBotSettings.endDate;
        emit UpdatedAntiBotEndDate(s.antiBotSettings.endDate);

        s.antiBotSettings.initialMaxHold = params._antiBotSettings.initialMaxHold;
        emit UpdatedAntiBotInitialMaxHold(s.antiBotSettings.initialMaxHold);

        if(!s.marketInit) {
            s.antiBotSettings.isActive = params._antiBotSettings.isActive;
            emit UpdatedAntiBotActiveStatus(s.antiBotSettings.isActive);
        }

        // SwapWhitelisting
        require(params._swapWhitelistingSettings.endDate <= 48, "ED");
        s.swapWhitelistingSettings.endDate = params._swapWhitelistingSettings.endDate;
        emit UpdatedSwapWhitelistingEndDate(s.antiBotSettings.endDate);

        if(!s.marketInit) {
            s.swapWhitelistingSettings.isActive = params._swapWhitelistingSettings.isActive;
            emit UpdatedSwapWhitelistingActiveStatus(s.swapWhitelistingSettings.isActive);
        }
    }
}