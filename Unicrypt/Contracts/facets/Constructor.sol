// SPDX-License-Identifier: UNLICENSED
// ALL RIGHTS RESERVED

// Unicrypt by SDDTech reserves all rights on this code. You may NOT copy these contracts.

pragma solidity 0.8.17;

import "../interfaces/IERC20.sol";
import "../interfaces/ITaxHelper.sol";
import "../interfaces/IMintFactory.sol";
import "../interfaces/IFacetHelper.sol";
import "../interfaces/IBuyBackWallet.sol";
import "../interfaces/ILPWallet.sol";
import "../interfaces/ISettings.sol";
import "../interfaces/IWallets.sol";

import "./Storage.sol";
import "../libraries/Ownable.sol";

contract ConstructorFacet is Storage, Ownable {
    
    struct ConstructorParams {
        string name_; 
        string symbol_; 
        uint8 decimals_; 
        address creator_; 
        uint256 tTotal_;
        uint256 _maxTax;
        TaxSettings _settings;
        TaxSettings _lockedSettings;
        Fees _fees;
        address _transactionTaxWallet;
        CustomTax[] _customTaxes;
        uint256 lpWalletThreshold;
        uint256 buyBackWalletThreshold;
        uint256 _taxHelperIndex;
        address admin_; 
        address recoveryAdmin_; 
        bool isLossless_;
        AntiBotSettings _antiBotSettings;
        uint256 _maxBalanceAfterBuy;
        SwapWhitelistingSettings _swapWhitelistingSettings;
    }

    function constructorHandler(ConstructorParams calldata params, address _factory) external {
        require(IMintFactory(_factory).tokenGeneratorIsAllowed(msg.sender), "RA");
        require(params.creator_ != address(0), "ZA");
        require(params._transactionTaxWallet != address(0), "ZA");
        require(params.admin_ != address(0), "ZA");
        require(params.recoveryAdmin_ != address(0), "ZA");
        require(_factory != address(0), "ZA");

        _name = params.name_;
        _symbol = params.symbol_;
        _decimals = params.decimals_;
        _creator = params.creator_;
        _isExcluded[params.creator_] = true;
        _excluded.push(params.creator_);
        emit ExcludedAccount(_creator);
        // Lossless
        isLosslessOn = params.isLossless_;
        admin = params.admin_;
        emit AdminChanged(address(0), admin);
        recoveryAdmin = params.recoveryAdmin_;
        emit RecoveryAdminChanged(address(0), recoveryAdmin);
        timelockPeriod = 7 days;
        lossless = ILosslessController(IMintFactory(_factory).getLosslessController());
        _isExcluded[address(lossless)] = true;
        _excluded.push(address(lossless));
        emit ExcludedAccount(address(lossless));
        // Tax Settings
        require(params._maxTax <= MaxTax, "MT");
        MaxTax = params._maxTax;
        taxSettings = params._settings;
        emit UpdatedSettings(taxSettings);
        isLocked = params._lockedSettings;
        isLocked.holderTax = true;
        if(taxSettings.holderTax) {
            taxSettings.canMint = false;
            isLocked.canMint = true;
        }
        emit UpdatedLockedSettings(isLocked);
        fees = params._fees;
        emit UpdatedTaxFees(fees);
        require(params._customTaxes.length < MaxCustom + 1, "MCT");
        for(uint i = 0; i < params._customTaxes.length; i++) {
            require(params._customTaxes[i].wallet != address(0));
            customTaxes.push(params._customTaxes[i]);
        }
        emit UpdatedCustomTaxes(customTaxes);
        customTaxLength = params._customTaxes.length;
        transactionTaxWallet = params._transactionTaxWallet;
        emit UpdatedTransactionTaxAddress(transactionTaxWallet);
        // Factory, Wallets, Pair Address
        factory = _factory;
        taxHelperIndex = params._taxHelperIndex;
        emit UpdatedTaxHelperIndex(taxHelperIndex);
        address taxHelper = IMintFactory(factory).getTaxHelperAddress(taxHelperIndex);
        pairAddress = ITaxHelper(taxHelper).createLPToken();
        addLPToken(pairAddress);
        address wallets = IFacetHelper(IMintFactory(factory).getFacetHelper()).getWalletsFacet(); 
        buyBackWallet = IWalletsFacet(wallets).createBuyBackWallet(factory, address(this), params.buyBackWalletThreshold);
        lpWallet = IWalletsFacet(wallets).createLPWallet(factory, address(this), params.lpWalletThreshold);
        // Total Supply and other info
        _rTotal = (MAX - (MAX % params.tTotal_));
        _rOwned[params.creator_] = _rTotal;
        DENOMINATOR = 10000;
        _isExcluded[taxHelper] = true;
        _excluded.push(taxHelper);
        emit ExcludedAccount(taxHelper);
        require(checkMaxTax(true), "BF");
        require(checkMaxTax(false), "SF");
        transferOwnership(params.creator_);
        _mintInitial(params.creator_, params.tTotal_);
        // AntiBot Settings
        require(params._antiBotSettings.endDate <= 48, "ED");
        require(params._swapWhitelistingSettings.endDate <= 48, "ED");
        antiBotSettings = params._antiBotSettings;
        emit UpdatedAntiBotSettings(antiBotSettings);
        maxBalanceAfterBuy = params._maxBalanceAfterBuy;
        emit UpdatedMaxBalanceAfterBuy(maxBalanceAfterBuy);
        swapWhitelistingSettings = params._swapWhitelistingSettings;
        emit UpdatedSwapWhitelistingSettings(swapWhitelistingSettings);
        emit TokenCreated(_name, _symbol, _decimals, _tTotal, _rTotal);
    }

    function _mintInitial(address account, uint256 amount) internal virtual {
        _tTotal += amount;
        _tOwned[account] += amount;
        emit Transfer(address(0), account, amount);
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


    function addLPToken(address _newLPToken) internal {
        lpTokens[_newLPToken] = true;
        emit AddedLPToken(_newLPToken);
    }
}