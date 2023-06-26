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

contract ConstructorFacet is Ownable {
    Storage internal s;

    event ExcludedAccount(address account);
    event AdminChanged(address indexed previousAdmin, address indexed newAdmin);
    event RecoveryAdminChanged(address indexed previousAdmin, address indexed newAdmin);
    event UpdatedCustomTaxes(CustomTax[] _customTaxes);
    event UpdatedTaxFees(Fees _updatedFees);
    event UpdatedTransactionTaxAddress(address _newAddress);
    event UpdatedLockedSettings(TaxSettings _updatedLocks);
    event UpdatedSettings(TaxSettings _updatedSettings);
    event UpdatedTaxHelperIndex(uint _newIndex);
    event UpdatedAntiBotSettings(AntiBotSettings _antiBotSettings);
    event UpdatedSwapWhitelistingSettings(SwapWhitelistingSettings _swapWhitelistingSettings);
    event UpdatedMaxBalanceAfterBuy(uint256 _newMaxBalance);
    event AddedLPToken(address _newLPToken);
    event TokenCreated(string name, string symbol, uint8 decimals, uint256 totalSupply, uint256 reflectionTotalSupply);
    event Transfer(address indexed from, address indexed to, uint256 value);
    
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

        // Set inital values
        s.CONTRACT_VERSION = 1;
        s.customTaxLength = 0;
        s.MaxTax = 3000;
        s.MaxCustom = 10;
        s.MAX = ~uint256(0);
        s.isPaused = false;
        s.isTaxed = false;
        s.marketInit = false;

        s._name = params.name_;
        s._symbol = params.symbol_;
        s._decimals = params.decimals_;
        s._creator = params.creator_;
        s._isExcluded[params.creator_] = true;
        s._excluded.push(params.creator_);
        emit ExcludedAccount(s._creator);
        // Lossless
        s.isLosslessOn = params.isLossless_;
        s.admin = params.admin_;
        emit AdminChanged(address(0), s.admin);
        s.recoveryAdmin = params.recoveryAdmin_;
        emit RecoveryAdminChanged(address(0), s.recoveryAdmin);
        s.timelockPeriod = 7 days;
        address lossless = IMintFactory(_factory).getLosslessController();
        s._isExcluded[lossless] = true;
        s._excluded.push(lossless);
        emit ExcludedAccount(lossless);
        // Tax Settings
        require(params._maxTax <= s.MaxTax, "MT");
        s.MaxTax = params._maxTax;
        s.taxSettings = params._settings;
        emit UpdatedSettings(s.taxSettings);
        s.isLocked = params._lockedSettings;
        s.isLocked.holderTax = true;
        if(s.taxSettings.holderTax) {
            s.taxSettings.canMint = false;
            s.isLocked.canMint = true;
        }
        emit UpdatedLockedSettings(s.isLocked);
        s.fees = params._fees;
        emit UpdatedTaxFees(s.fees);
        require(params._customTaxes.length < s.MaxCustom + 1, "MCT");
        for(uint i = 0; i < params._customTaxes.length; i++) {
            require(params._customTaxes[i].wallet != address(0));
            s.customTaxes.push(params._customTaxes[i]);
        }
        emit UpdatedCustomTaxes(s.customTaxes);
        s.customTaxLength = params._customTaxes.length;
        s.transactionTaxWallet = params._transactionTaxWallet;
        emit UpdatedTransactionTaxAddress(s.transactionTaxWallet);
        // Factory, Wallets, Pair Address
        s.factory = _factory;
        s.taxHelperIndex = params._taxHelperIndex;
        emit UpdatedTaxHelperIndex(s.taxHelperIndex);
        address taxHelper = IMintFactory(s.factory).getTaxHelperAddress(s.taxHelperIndex);
        s.pairAddress = ITaxHelper(taxHelper).createLPToken();
        addLPToken(s.pairAddress);
        address wallets = IFacetHelper(IMintFactory(s.factory).getFacetHelper()).getWalletsFacet(); 
        s.buyBackWallet = IWalletsFacet(wallets).createBuyBackWallet(s.factory, address(this), params.buyBackWalletThreshold);
        s.lpWallet = IWalletsFacet(wallets).createLPWallet(s.factory, address(this), params.lpWalletThreshold);
        // Total Supply and other info
        s._rTotal = (s.MAX - (s.MAX % params.tTotal_));
        s._rOwned[params.creator_] = s._rTotal;
        s.DENOMINATOR = 10000;
        s._isExcluded[taxHelper] = true;
        s._excluded.push(taxHelper);
        emit ExcludedAccount(taxHelper);
        require(checkMaxTax(true), "BF");
        require(checkMaxTax(false), "SF");
        transferOwnership(params.creator_);
        _mintInitial(params.creator_, params.tTotal_);
        // AntiBot Settings
        require(params._antiBotSettings.endDate <= 48, "ED");
        require(params._swapWhitelistingSettings.endDate <= 48, "ED");
        s.antiBotSettings = params._antiBotSettings;
        emit UpdatedAntiBotSettings(s.antiBotSettings);
        s.maxBalanceAfterBuy = params._maxBalanceAfterBuy;
        emit UpdatedMaxBalanceAfterBuy(s.maxBalanceAfterBuy);
        s.swapWhitelistingSettings = params._swapWhitelistingSettings;
        emit UpdatedSwapWhitelistingSettings(s.swapWhitelistingSettings);
        emit TokenCreated(s._name, s._symbol, s._decimals, s._tTotal, s._rTotal);
    }

    function _mintInitial(address account, uint256 amount) internal virtual {
        s._tTotal += amount;
        s._tOwned[account] += amount;
        emit Transfer(address(0), account, amount);
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


    function addLPToken(address _newLPToken) internal {
        s.lpTokens[_newLPToken] = true;
        emit AddedLPToken(_newLPToken);
    }
}