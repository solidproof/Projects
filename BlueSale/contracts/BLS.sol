// SPDX-License-Identifier: MIT
pragma solidity ^0.8.1;

import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol';
import '@openzeppelin/contracts/security/Pausable.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';

contract BLSToken is ERC20, ERC20Burnable, Pausable, Ownable {
    using SafeMath for uint256;
    uint256 private _maxCap = 100000000 * 10**decimals();
    uint256 public constant DIVI = 10000;
    uint256 public sellTax = 400; 
    uint256 public buyTax = 0;
    address public feeWallet;
    mapping(address => bool) public lps;
    mapping(address => bool) public blacklisted;
    mapping(address => bool) public whitelisted;
    event SetLiquidPair(address LP, bool Status);

    constructor() ERC20('BLS Token', 'BLS') {
        _mint(msg.sender, _maxCap);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        require(!blacklisted[from] && !blacklisted[to], "Transfer blacklisted");
        super._beforeTokenTransfer(from, to, amount);
    }


    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused{
         if (lps[from] == true && !whitelisted[to] && buyTax > 0 && feeWallet != address(0)) {
            uint256 fee = amount.mul(buyTax).div(DIVI);
            uint256 transferA = amount.sub(fee);
            super._transfer(from, feeWallet, fee);
            super._transfer(from, to, transferA);
        } 
        else if (lps[to] == true && !whitelisted[from] && sellTax > 0 && feeWallet != address(0)) {
            uint256 fee = amount.mul(sellTax).div(DIVI);
            uint256 transferA = amount.sub(fee);
            super._transfer(from, feeWallet, fee);
            super._transfer(from, to, transferA);
        }
        else {
            super._transfer(from, to, amount);
        }
    }

    function blacklist(address _user, bool _isBlacklisted) external onlyOwner {
        blacklisted[_user] = _isBlacklisted;
    }


    function whitelist(address _user, bool _enable) external onlyOwner {
        whitelisted[_user] = _enable;
    }

    function setLiquidPair(address _lp, bool _status) external onlyOwner {
        require(address(0) != _lp,"_lp zero address");
        lps[_lp] = _status;
        emit SetLiquidPair(_lp, _status);
    }

    function setFeeWallet(address _feeWallet) public onlyOwner {
        feeWallet = _feeWallet;
    }

    function setSellTax(uint256 _taxPercent) public onlyOwner {
        sellTax = _taxPercent;
    }

     function setBuyTax(uint256 _taxPercent) public onlyOwner {
        buyTax = _taxPercent;
    }

    function eWToken(address _token, address _to) external onlyOwner {
        require(_token != address(this),"Invalid token");
        uint256 _amount = ERC20(_token).balanceOf(address(this));
        if (ERC20.balanceOf(address(this)) > 0) {
            payable(_to).transfer(ERC20.balanceOf(address(this)));
        }
        ERC20(_token).transfer(_to, _amount);
    }
}