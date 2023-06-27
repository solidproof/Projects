// SPDX-License-Identifier: UNLICENSED
// ALL RIGHTS RESERVED

// Unicrypt by SDDTech reserves all rights on this code. You may NOT copy these contracts.

// This contract logs all tokens on the platform

pragma solidity 0.8.17;

import "../interfaces/IERC20.sol";
import "../interfaces/ITaxHelper.sol";
import "../interfaces/IMintFactory.sol";
import "../interfaces/ILosslessController.sol";
import "../interfaces/IFeeHelper.sol";

import "../libraries/Ownable.sol";
import "../libraries/FullMath.sol";

import "./Storage.sol";

import "../BuyBackWallet.sol";
import "../LPWallet.sol";


contract TaxFacet is Ownable {
    Storage internal s;

    event MarketInit(uint256 timestamp, uint256 blockNumber);
    event BuyBackTaxInitiated(address _sender, uint256 _fee, address _wallet, bool _isBuy);
    event TransactionTaxInitiated(address _sender, uint256 _fee, address _wallet, bool _isBuy);
    event LPTaxInitiated(address _sender, uint256 _fee, address _wallet, bool _isBuy);
    event CustomTaxInitiated(address _sender, uint256 _fee, address _wallet, bool _isBuy);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Reflect(uint256 tAmount, uint256 rAmount, uint256 rTotal_, uint256 teeTotal_);
    event ExcludedAccount(address account);
    event IncludedAccount(address account);

    function paused() internal view returns (bool) {
        return s.isPaused;
    }

    function isBlacklisted(address _address) internal view returns (bool) {
        return s.blacklist[_address];
    }

    /// @notice Handles the taxes for the token.
    /// Calls the appropriate tax helper contract to handle 
    /// LP and BuyBack tax logic
    /// @dev handles every tax within the tax facet. 
    /// @param sender the one sending the transaction
    /// @param recipient the one receiving the transaction
    /// @param amount the amount of tokens being sent
    /// @return totalTaxAmount the total amount of the token taxed
    function handleTaxes(address sender, address recipient, uint256 amount) public virtual returns (uint256 totalTaxAmount) {
        // restrict it to being only called by registered tokens
        require(IMintFactory(s.factory).tokenIsRegistered(address(this)));
        bool isBuy = false;

        if(s.lpTokens[sender]) {
            isBuy = true;
            if(!s.marketInit) {
                s.marketInit = true;
                s.antiBotSettings.startBlock = block.number;
                s.marketInitBlockTime = block.timestamp;
                emit MarketInit(block.timestamp, block.number);
            }
        }

        if(!s.lpTokens[sender] && !s.lpTokens[recipient]) {
            return 0;
        }

        if(isBuy && s.taxWhitelist[recipient]) {
            return 0;
        }

        if(!isBuy && s.taxWhitelist[sender]) {
            return 0;
        }

        ITaxHelper TaxHelper = ITaxHelper(IMintFactory(s.factory).getTaxHelperAddress(s.taxHelperIndex));
        if(sender == address(TaxHelper) || recipient == address(TaxHelper)) {
            return 0;
        }
        totalTaxAmount;
        uint256 fee;
        if(s.taxSettings.buyBackTax && !isBuy) {
            if(TaxHelper.lpTokenHasReserves(s.pairAddress)) {
                fee = amount * s.fees.buyBackTax / s.DENOMINATOR;
            }
            
            if(fee != 0) {
                _transfer(sender, address(TaxHelper), fee);

                TaxHelper.initiateBuyBackTax(address(this), address(s.buyBackWallet));
                emit BuyBackTaxInitiated(sender, fee, address(s.buyBackWallet), isBuy);
                totalTaxAmount += fee;
            }
            fee = 0;
        }
        if(s.taxSettings.transactionTax) {
            if(isBuy) {
                fee = amount * s.fees.transactionTax.buy / s.DENOMINATOR;
            } else {
                fee = amount * s.fees.transactionTax.sell / s.DENOMINATOR;
            }
            if(fee != 0) {
                _transfer(sender, s.transactionTaxWallet, fee);
                emit TransactionTaxInitiated(sender, fee, s.transactionTaxWallet, isBuy);
                totalTaxAmount += fee;
            }
            fee = 0;
        }
        if(s.taxSettings.lpTax && !isBuy) {
            if(TaxHelper.lpTokenHasReserves(s.pairAddress)) {
                fee = amount * s.fees.lpTax / s.DENOMINATOR;
            }
            if(fee != 0) {
                _transfer(sender, address(TaxHelper), fee);
                TaxHelper.initiateLPTokenTax(address(this), address(s.lpWallet));
                emit LPTaxInitiated(sender, fee, address(s.lpWallet), isBuy);
                totalTaxAmount += fee;
            }
            fee = 0;
        }
        if(s.customTaxes.length > 0) {
            for(uint8 i = 0; i < s.customTaxes.length; i++) {
                uint256 customFee;
                if(isBuy) {
                    customFee = amount * s.customTaxes[i].fee.buy / s.DENOMINATOR;
                } else {
                    customFee = amount * s.customTaxes[i].fee.sell / s.DENOMINATOR;
                }
                fee += customFee;
                if(fee != 0) {
                    totalTaxAmount += fee;
                    _transfer(sender, s.customTaxes[i].wallet, fee);
                    emit CustomTaxInitiated(sender, fee, s.customTaxes[i].wallet, isBuy);
                    fee = 0;
                }
            }
        }    
    }

    /// @notice internal transfer method
    /// @dev includes checks for all features not handled by handleTaxes()
    /// @param sender the one sending the transaction
    /// @param recipient the one receiving the transaction
    /// @param amount the amount of tokens being sent
    function _transfer(address sender, address recipient, uint256 amount) public {
        // restrict it to being only called by registered tokens
        if(!IMintFactory(s.factory).tokenGeneratorIsAllowed(msg.sender)) {
            require(IMintFactory(s.factory).tokenIsRegistered(address(this)));
        }
        require(sender != address(0), "ETFZ");
        require(recipient != address(0), "ETTZ");
        require(amount > 0, "TGZ");
        require(!paused(), "TP");
        require(!isBlacklisted(sender), "SB");
        require(!isBlacklisted(recipient), "RB"); 
        require(!isBlacklisted(tx.origin), "SB");
        // Reflection Transfers
        if(s.taxSettings.holderTax) {
            if (s._isExcluded[sender] && !s._isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
            } else if (!s._isExcluded[sender] && s._isExcluded[recipient]) {
                _transferToExcluded(sender, recipient, amount);
            } else if (!s._isExcluded[sender] && !s._isExcluded[recipient]) {
                _transferStandard(sender, recipient, amount);
            } else if (s._isExcluded[sender] && s._isExcluded[recipient]) {
                _transferBothExcluded(sender, recipient, amount);
            } else {
                _transferStandard(sender, recipient, amount);
            }
        } else {
            // Non Reflection Transfer
            _beforeTokenTransfer(sender, recipient, amount);

            uint256 senderBalance = s._tOwned[sender];
            require(senderBalance >= amount, "ETA");
            s._tOwned[sender] = senderBalance - amount;
            s._tOwned[recipient] += amount;

            emit Transfer(sender, recipient, amount);
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }


    // Reflection Functions


    function reflect(uint256 tAmount) public {
        address sender = _msgSender();
        require(!s._isExcluded[sender], "EA");
        (uint256 rAmount,,,,) = _getValues(tAmount);
        s._rOwned[sender] = s._rOwned[sender] - rAmount;
        s._rTotal = s._rTotal - rAmount;
        s._tFeeTotal = s._tFeeTotal + tAmount;
        emit Reflect(tAmount, rAmount, s._rTotal, s._tFeeTotal);
        ITaxHelper TaxHelper = ITaxHelper(IMintFactory(s.factory).getTaxHelperAddress(s.taxHelperIndex));
        TaxHelper.sync(s.pairAddress);
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns(uint256) {
        require(tAmount <= s._tTotal, "ALS");
        if (!deductTransferFee) {
            (uint256 rAmount,,,,) = _getValues(tAmount);
            return rAmount;
        } else {
            (,uint256 rTransferAmount,,,) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount) public view returns(uint256)  {
        require(rAmount <= s._rTotal, "ALR");
        uint256 currentRate = _getRate();
        return rAmount / currentRate;
    }

    function excludeAccount(address account) external onlyOwner {
        require(!s._isExcluded[account], "AE");
        if(s._rOwned[account] > 0) {
            s._tOwned[account] = tokenFromReflection(s._rOwned[account]);
        }
        s._isExcluded[account] = true;
        s._excluded.push(account);
        emit ExcludedAccount(account);
    }

    function includeAccount(address account) external onlyOwner {
        require(s._isExcluded[account], "AI");
        for (uint256 i = 0; i < s._excluded.length; i++) {
            if (s._excluded[i] == account) {
                s._excluded[i] = s._excluded[s._excluded.length - 1];
                s._tOwned[account] = 0;
                s._isExcluded[account] = false;
                s._excluded.pop();
                break;
            }
        }
        emit IncludedAccount(account);
    }

    function isExcluded(address account) external view returns(bool) {
        return s._isExcluded[account];
    }

    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee) = _getValues(tAmount);
        s._rOwned[sender] = s._rOwned[sender] - rAmount;
        s._rOwned[recipient] = s._rOwned[recipient] + rTransferAmount;    
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee) = _getValues(tAmount);
        s._rOwned[sender] = s._rOwned[sender] - rAmount;
        s._tOwned[recipient] = s._tOwned[recipient] + tTransferAmount;
        s._rOwned[recipient] = s._rOwned[recipient] + rTransferAmount;           
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee) = _getValues(tAmount);
        s._tOwned[sender] = s._tOwned[sender] - tAmount;
        s._rOwned[sender] = s._rOwned[sender] - rAmount;
        s._rOwned[recipient] = s._rOwned[recipient] + rTransferAmount;   
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferBothExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee) = _getValues(tAmount);
        s._tOwned[sender] = s._tOwned[sender] - tAmount;
        s._rOwned[sender] = s._rOwned[sender] - rAmount;
        s._tOwned[recipient] = s._tOwned[recipient] + tTransferAmount;
        s._rOwned[recipient] = s._rOwned[recipient] + rTransferAmount;        
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        s._rTotal = s._rTotal - rFee;
        s._tFeeTotal = s._tFeeTotal + tFee;
    }

    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee) = _getTValues(tAmount);
        uint256 currentRate = _getRate();
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, currentRate);
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee);
    }

    function _getTValues(uint256 tAmount) private view returns (uint256, uint256) {
        uint256 tFee = tAmount / s.fees.holderTax;
        uint256 tTransferAmount = tAmount - tFee;
        return (tTransferAmount, tFee);
    }

    function _getRValues(uint256 tAmount, uint256 tFee, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount * currentRate;
        uint256 rFee = tFee * currentRate;
        uint256 rTransferAmount = rAmount - rFee;
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply / tSupply;
    }

    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = s._rTotal;
        uint256 tSupply = s._tTotal;      
        for (uint256 i = 0; i < s._excluded.length; i++) {
            if (s._rOwned[s._excluded[i]] > rSupply || s._tOwned[s._excluded[i]] > tSupply) return (s._rTotal, s._tTotal);
            rSupply = rSupply - s._rOwned[s._excluded[i]];
            tSupply = tSupply - s._tOwned[s._excluded[i]];
        }
        if (rSupply < s._rTotal / s._tTotal) return (s._rTotal, s._tTotal);
        return (rSupply, tSupply);
    }

    function burn(uint256 amount) public {
        address taxHelper = IMintFactory(s.factory).getTaxHelperAddress(s.taxHelperIndex);
        require(msg.sender == taxHelper || msg.sender == owner(), "RA");
        _burn(owner(), amount);
    }

    /// @notice custom burn to handle reflection
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "EBZ");

        if (s.isLosslessOn) {
            ILosslessController(IMintFactory(s.factory).getLosslessController()).beforeBurn(account, amount);
        } 

        _beforeTokenTransfer(account, address(0), amount);

        if(s.taxSettings.holderTax && !s._isExcluded[account]) {
            (uint256 rAmount,,,,) = _getValues(amount);
            s._rOwned[account] = s._rOwned[account] - rAmount;
            s._rTotal = s._rTotal - rAmount;
            s._tFeeTotal = s._tFeeTotal + amount;
        }

        uint256 accountBalance = s._tOwned[account];
        require(accountBalance >= amount, "EBB");
        s._tOwned[account] = accountBalance - amount;
        s._tTotal -= amount;

        emit Transfer(account, address(0), amount);
    }
    
}