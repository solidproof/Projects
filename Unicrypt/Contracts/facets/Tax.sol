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


contract TaxFacet is Storage, Ownable{

    function paused() internal view returns (bool) {
        return isPaused;
    }

    function isBlacklisted(address _address) internal view returns (bool) {
        return blacklist[_address];
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
        require(IMintFactory(factory).tokenIsRegistered(address(this)));
        bool isBuy = false;

        if(lpTokens[sender]) {
            isBuy = true;
            if(!marketInit) {
                marketInit = true;
                antiBotSettings.startBlock = block.number;
                marketInitBlockTime = block.timestamp;
                emit MarketInit(block.timestamp, block.number);
            }
        }

        if(!lpTokens[sender] && !lpTokens[recipient]) {
            return 0;
        }

        ITaxHelper TaxHelper = ITaxHelper(IMintFactory(factory).getTaxHelperAddress(taxHelperIndex));
        if(sender == address(TaxHelper) || recipient == address(TaxHelper)) {
            return 0;
        }
        totalTaxAmount;
        uint256 fee;
        if(taxSettings.buyBackTax && !isBuy) {
            if(TaxHelper.lpTokenHasReserves(pairAddress)) {
                fee = amount * fees.buyBackTax / DENOMINATOR;
            }
            
            if(fee != 0) {
                _transfer(sender, address(TaxHelper), fee);

                TaxHelper.initiateBuyBackTax(address(this), address(buyBackWallet));
                emit BuyBackTaxInitiated(sender, fee, address(buyBackWallet), isBuy);
                totalTaxAmount += fee;
            }
            fee = 0;
        }
        if(taxSettings.transactionTax) {
            if(isBuy) {
                fee = amount * fees.transactionTax.buy / DENOMINATOR;
            } else {
                fee = amount * fees.transactionTax.sell / DENOMINATOR;
            }
            if(fee != 0) {
                _transfer(sender, transactionTaxWallet, fee);
                emit TransactionTaxInitiated(sender, fee, transactionTaxWallet, isBuy);
                totalTaxAmount += fee;
            }
            fee = 0;
        }
        if(taxSettings.lpTax && !isBuy) {
            if(TaxHelper.lpTokenHasReserves(pairAddress)) {
                fee = amount * fees.lpTax / DENOMINATOR;
            }
            if(fee != 0) {
                _transfer(sender, address(TaxHelper), fee);
                TaxHelper.initiateLPTokenTax(address(this), address(lpWallet));
                emit LPTaxInitiated(sender, fee, address(lpWallet), isBuy);
                totalTaxAmount += fee;
            }
            fee = 0;
        }
        if(customTaxes.length > 0) {
            for(uint8 i = 0; i < customTaxes.length; i++) {
                uint256 customFee;
                if(isBuy) {
                    customFee = amount * customTaxes[i].fee.buy / DENOMINATOR;
                } else {
                    customFee = amount * customTaxes[i].fee.sell / DENOMINATOR;
                }
                fee += customFee;
                if(fee != 0) {
                    totalTaxAmount += fee;
                    _transfer(sender, customTaxes[i].wallet, fee);
                    emit CustomTaxInitiated(sender, fee, customTaxes[i].wallet, isBuy);
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
        if(!IMintFactory(factory).tokenGeneratorIsAllowed(msg.sender)) {
            require(IMintFactory(factory).tokenIsRegistered(address(this)));
        }
        require(sender != address(0), "ETFZ");
        require(recipient != address(0), "ETTZ");
        require(amount > 0, "TGZ");
        require(!paused(), "TP");
        require(!isBlacklisted(msg.sender), "SB");
        require(!isBlacklisted(recipient), "RB"); 
        require(!isBlacklisted(tx.origin), "SB");
        // Reflection Transfers
        if(taxSettings.holderTax) {
            if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
            } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
                _transferToExcluded(sender, recipient, amount);
            } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
                _transferStandard(sender, recipient, amount);
            } else if (_isExcluded[sender] && _isExcluded[recipient]) {
                _transferBothExcluded(sender, recipient, amount);
            } else {
                _transferStandard(sender, recipient, amount);
            }
        } else {
            // Non Reflection Transfer
            _beforeTokenTransfer(sender, recipient, amount);

            uint256 senderBalance = _tOwned[sender];
            require(senderBalance >= amount, "ETA");
            _tOwned[sender] = senderBalance - amount;
            _tOwned[recipient] += amount;

            emit Transfer(sender, recipient, amount);
        }
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual { }


    // Reflection Functions


    function reflect(uint256 tAmount) public {
        address sender = _msgSender();
        require(!_isExcluded[sender], "EA");
        (uint256 rAmount,,,,) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _rTotal = _rTotal - rAmount;
        _tFeeTotal = _tFeeTotal + tAmount;
        emit Reflect(tAmount, rAmount, _rTotal, _tFeeTotal);
    }

    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns(uint256) {
        require(tAmount <= _tTotal, "ALS");
        if (!deductTransferFee) {
            (uint256 rAmount,,,,) = _getValues(tAmount);
            return rAmount;
        } else {
            (,uint256 rTransferAmount,,,) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(uint256 rAmount) public view returns(uint256)  {
        require(rAmount <= _rTotal, "ALR");
        uint256 currentRate = _getRate();
        return rAmount / currentRate;
    }

    function excludeAccount(address account) external onlyOwner {
        require(!_isExcluded[account], "AE");
        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
        emit ExcludedAccount(account);
    }

    function includeAccount(address account) external onlyOwner {
        require(_isExcluded[account], "AI");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
        emit IncludedAccount(account);
    }

    function isExcluded(address account) external view returns(bool) {
        return _isExcluded[account];
    }

    function _transferStandard(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _rOwned[recipient] = _rOwned[recipient] + rTransferAmount;    
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferToExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _tOwned[recipient] = _tOwned[recipient] + tTransferAmount;
        _rOwned[recipient] = _rOwned[recipient] + rTransferAmount;           
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferFromExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender] - tAmount;
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _rOwned[recipient] = _rOwned[recipient] + rTransferAmount;   
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _transferBothExcluded(address sender, address recipient, uint256 tAmount) private {
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee, uint256 tTransferAmount, uint256 tFee) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender] - tAmount;
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _tOwned[recipient] = _tOwned[recipient] + tTransferAmount;
        _rOwned[recipient] = _rOwned[recipient] + rTransferAmount;        
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal - rFee;
        _tFeeTotal = _tFeeTotal + tFee;
    }

    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee) = _getTValues(tAmount);
        uint256 currentRate = _getRate();
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, currentRate);
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee);
    }

    function _getTValues(uint256 tAmount) private view returns (uint256, uint256) {
        uint256 tFee = tAmount / fees.holderTax;
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
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;      
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply - _rOwned[_excluded[i]];
            tSupply = tSupply - _tOwned[_excluded[i]];
        }
        if (rSupply < _rTotal / _tTotal) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function burn(uint256 amount) public {
        if (isLosslessOn) {
            lossless.beforeBurn(_msgSender(), amount);
        } 
        address taxHelper = IMintFactory(factory).getTaxHelperAddress(taxHelperIndex);
        require(msg.sender == taxHelper || msg.sender == owner(), "RA");
        _burn(owner(), amount);
    }

    /// @notice custom burn to handle reflection
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "EBZ");

        if (isLosslessOn) {
            lossless.beforeBurn(account, amount);
        } 

        _beforeTokenTransfer(account, address(0), amount);

        if(taxSettings.holderTax && !_isExcluded[account]) {
            (uint256 rAmount,,,,) = _getValues(amount);
            _rOwned[account] = _rOwned[account] - rAmount;
            _rTotal = _rTotal - rAmount;
            _tFeeTotal = _tFeeTotal + amount;
        }

        uint256 accountBalance = _tOwned[account];
        require(accountBalance >= amount, "EBB");
        _tOwned[account] = accountBalance - amount;
        _tTotal -= amount;

        emit Transfer(account, address(0), amount);
    }
    
}