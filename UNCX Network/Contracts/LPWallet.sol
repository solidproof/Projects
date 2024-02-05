// SPDX-License-Identifier: UNLICENSED
// ALL RIGHTS RESERVED

// Unicrypt by SDDTech reserves all rights on this code. You may NOT copy these contracts.


pragma solidity 0.8.17;

import "./libraries/Ownable.sol";

import "./interfaces/ITaxToken.sol";
import "./interfaces/ITaxHelper.sol";

import "./interfaces/IMintFactory.sol";


contract LPWallet is Ownable{

    ITaxToken public token;
    IMintFactory public factory;
    uint256 private threshold;

    event UpdatedThreshold(uint256 _newThreshold);
    event ETHtoTaxHelper(uint256 amount);
    event TransferBalancetoTaxHelper(uint256 tokenBalance);

    constructor(address _factory, address _token, uint256 _newThreshold) {
        token = ITaxToken(_token);
        factory = IMintFactory(_factory);
        threshold = _newThreshold;
        emit UpdatedThreshold(_newThreshold);
        transferOwnership(_token);
    }
    
    function checkLPTrigger() public view returns (bool) {
        return address(this).balance > threshold;
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function sendEthToTaxHelper() external returns (uint256) {
        uint index = token.taxHelperIndex();
        require(msg.sender == factory.getTaxHelperAddress(index), "RA");
        uint256 amount = address(this).balance;
        (bool sent,) = msg.sender.call{value: amount}("");
        require(sent, "Failed to send Ether");
        emit ETHtoTaxHelper(amount);
        return amount;
    }

    function transferBalanceToTaxHelper() external {
        uint index = token.taxHelperIndex();
        require(msg.sender == factory.getTaxHelperAddress(index));
        uint256 tokenBalance = token.balanceOf(address(this));
        token.transfer(msg.sender, tokenBalance);
        emit TransferBalancetoTaxHelper(tokenBalance);
    }

    function updateThreshold(uint256 _newThreshold) external onlyOwner {
        threshold = _newThreshold;
        emit UpdatedThreshold(_newThreshold);
    }

    function getThreshold() external view returns (uint256) {
        return threshold;
    }

    receive() payable external {
    }


} 