
// SPDX-License-Identifier: MIT
pragma solidity 0.8.7;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

/// @custom:security-contact security@kurusetra.net
contract TokenWithTax is ERC20, Ownable {
    uint256 taxPercentage;
    uint256 maxTransfer;

    using SafeMath for uint256;

    mapping(address => bool) private isExcludedFromFee;
    mapping(address => bool) private isExcludedFromMaxTransfer;

    event taxSelected(uint256 tax);
    event maxTransferSelected(uint256 amount);
    event walletsWithoutFeeIncluded(address wallet);
    event walletsExcludedMaxTransfer(address wallet);

    constructor() ERC20("KRSTC", "KURUSETRA") {
        _mint(msg.sender, 10000000 * 10**decimals());
        taxPercentage = 5;
        maxTransfer = 100000 * 10**decimals();
    }

    //EXECUTE IS TOKEN IS LISTED IN EXCHANGE
    function setTax(uint256 percent) external onlyOwner {
        require(percent <= 5, "Percent is > 5");
        taxPercentage = percent;
    }

    function setMaxTransfer(uint256 amount) external onlyOwner {
        require(
            amount * 10**decimals() >= 100000 * 10**decimals(),
            "You cannot place less than 100,000 tokens."
        );
        maxTransfer = amount * 10**decimals();
    }

    function setWalletsWithoutFee(address wallet) external onlyOwner {
        require(wallet != address(0), "Wallet can't be zero address");
        require(!isExcludedFromFee[wallet], "This wallet is excluded");
        isExcludedFromFee[wallet] = true;
    }

    function setWalletsExcludedFromMaxTransfer(address wallet) external onlyOwner {
        require(wallet != address(0), "Wallet can't be zero address");
        require(!isExcludedFromMaxTransfer[wallet], "This wallet is excluded");
        isExcludedFromMaxTransfer[wallet] = true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
      

        bool hasFee = true;
        bool hasMaxTransfer = true;

        if(isExcludedFromMaxTransfer[from]) {
            hasMaxTransfer = false;    
        }

        require(amount <= maxTransfer || !hasMaxTransfer, "You cannot exceed the maximum transfer rate");
        
        if (isExcludedFromFee[from]) {
            hasFee = false;
        }

        if (!hasFee) {
            //Tax free
            super._transfer(from, to, amount);
        } else {
            //It has tax
            uint256 taxAmount = amount.mul(taxPercentage).div(100);
            super._transfer(from, owner(), taxAmount);
            amount -= taxAmount;
            super._transfer(from, to, amount);
        }
    }
}
