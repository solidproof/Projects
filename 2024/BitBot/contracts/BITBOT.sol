// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BITBOT is ERC20, Ownable {
    address private feeReceiver;
    uint256 public feeRate = 0;

    mapping(address => bool) fromTaxWhitelist;
    mapping(address => bool) toTaxWhitelist;

    constructor(address mintTarget, address _feeReceiver) ERC20("Bitbot", "BITBOT") {
        feeReceiver = _feeReceiver;
        _mint(mintTarget, 1_000_000_000 * (10 ** decimals()));
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        bool disableTax = fromTaxWhitelist[_msgSender()] || toTaxWhitelist[recipient] || feeRate == 0;
        uint256 tax = disableTax ? 0 : getTransferTax(amount);
        uint256 amountAfterTax = amount - tax;

        _transfer(_msgSender(), recipient, amountAfterTax);

        if (tax > 0) {
            _transfer(_msgSender(), feeReceiver, tax);
        }

        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override returns (bool) {
        bool disableTax = fromTaxWhitelist[from] || toTaxWhitelist[to] || feeRate == 0;
        uint256 tax = disableTax ? 0 : getTransferTax(amount);
        uint256 amountAfterTax = amount - tax;

        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amountAfterTax);

        if (tax > 0) {
            _transfer(from, feeReceiver, tax);
        }

        return true;
    }

    function setFromTaxWhitelist(address account, bool isWhitelisted) public onlyOwner {
        fromTaxWhitelist[account] = isWhitelisted;
    }

    function setToTaxWhitelist(address account, bool isWhitelisted) public onlyOwner {
        toTaxWhitelist[account] = isWhitelisted;
    }

    function getFromTaxWhitelist(address account) public view returns (bool) {
        return fromTaxWhitelist[account];
    }

    function getToTaxWhitelist(address account) public view returns (bool) {
        return toTaxWhitelist[account];
    }

    function getTransferTax(uint256 amount) private view returns (uint256) {
        if (feeRate == 0) {
            return 0;
        }

        return (amount * feeRate) / 10000;
    }

    function setFeeReceiver(address _feeReceiver) public onlyOwner {
        feeReceiver = _feeReceiver;
    }

    function setFeeRate(uint256 _feeRate) public onlyOwner {
        require(_feeRate <= 500, "Invalid fee rate");
        feeRate = _feeRate;
    }
}