// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "./oft/BaseOFTV2.sol";

contract BathtubToken is ERC20, Ownable, BaseOFTV2 {
    address public feeAddress;
    bool public taxEnabled;
    mapping(address => bool) public feeExempt;
    uint256 public constant FEE = 100; // 1%

    // OFT related variable
    uint internal immutable ld2sdRate;
    uint8 private _sharedDecimals = 18;
    address private _lzEndpoint = 0x3c2269811836af69497E5F486A85D7316753cf62;

    constructor(address _feeAddress) ERC20("Bathtub Token", "BATH") BaseOFTV2(_sharedDecimals, _lzEndpoint) {
        uint8 decimals = decimals();
        require(_sharedDecimals <= decimals, "OFT: sharedDecimals must be <= decimals");
        ld2sdRate = 10 ** (decimals - _sharedDecimals);

        feeAddress = _feeAddress;
        taxEnabled = false;
        _mint(msg.sender, 100_000_000 * 10 ** decimals);
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        return _transferWithTax(msg.sender, recipient, amount);
    }

    function transferFrom(address from, address to, uint256 amount) public virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transferWithTax(from, to, amount);
        return true;
    }

    function _transferWithTax(address sender, address recipient, uint256 amount) internal returns (bool) {
        if (taxEnabled && !feeExempt[sender] && !feeExempt[recipient]) {
            uint256 feeAmount = amount * FEE / 10000; // Calculate 1% fee
            uint256 netAmount = amount - feeAmount;
            uint256 burnAmount = feeAmount / 2; // 0.5% burn
            uint256 feeToAddress = feeAmount - burnAmount; // 0.5% to fee address

            super._transfer(sender, recipient, netAmount); // Transfer net amount
            super._transfer(sender, feeAddress, feeToAddress); // Transfer fee to fee address
            _burn(sender, burnAmount); // Burn amount
            return true;
        } else {
            super._transfer(sender, recipient, amount);
            return true;
        }
    }

    function setTaxEnabled(bool _taxEnabled) public onlyOwner {
        taxEnabled = _taxEnabled;
    }

    function setFeeAddress(address _feeAddress) public onlyOwner {
        feeAddress = _feeAddress;
    }

    function setFeeExempt(address _address, bool _exempt) public onlyOwner {
        feeExempt[_address] = _exempt;
    }

    /************************************************************************
    * OFT public functions
    ************************************************************************/
    function circulatingSupply() public view virtual override returns (uint) {
        return totalSupply();
    }

    function token() public view virtual override returns (address) {
        return address(this);
    }

    /************************************************************************
    * OFT internal functions
    ************************************************************************/
    function _debitFrom(address _from, uint16, bytes32, uint _amount) internal virtual override returns (uint) {
        address spender = _msgSender();
        if (_from != spender) _spendAllowance(_from, spender, _amount);
        _burn(_from, _amount);
        return _amount;
    }

    function _creditTo(uint16, address _toAddress, uint _amount) internal virtual override returns (uint) {
        _mint(_toAddress, _amount);
        return _amount;
    }

    function _transferFrom(address _from, address _to, uint _amount) internal virtual override returns (uint) {
        address spender = _msgSender();
        // if transfer from this contract, no need to check allowance
        if (_from != address(this) && _from != spender) _spendAllowance(_from, spender, _amount);
        _transferWithTax(_from, _to, _amount);
        return _amount;
    }

    function _ld2sdRate() internal view virtual override returns (uint) {
        return ld2sdRate;
    }
}
