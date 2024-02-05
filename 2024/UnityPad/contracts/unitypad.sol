// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";


contract Unitypad is ERC20, ERC20Burnable, Ownable {
    uint256 private ALLOCATION_FEE = 4;
    uint256 private TEAM_FEE = 1;
    address private ALLOCATION_ADDRESS = 0xd9C4854Bd8Bd24cbc1c8183Aae883a41eD73E69F;
    address private TEAM_ADDRESS = 0x3D1e4566B51AcF8e7F09a15C45CFD226335A26C8;
    address private MARKETING_ADDRESS = 0xfE9a5e418df4758410429e3945bF339227Fce644;

    mapping(address => bool) public _isExcludedFromFee;

    constructor()
        ERC20("Unitypad", "UPAD")
    {
        _mint(msg.sender, 1000000000 * 10 ** decimals());
        _isExcludedFromFee[msg.sender] = true;
        _isExcludedFromFee[ALLOCATION_ADDRESS] = true;
        _isExcludedFromFee[TEAM_ADDRESS] = true;
        _isExcludedFromFee[MARKETING_ADDRESS] = true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal override(ERC20) {
        if (_isExcludedFromFee[sender] || _isExcludedFromFee[recipient]) {
            super._transfer(sender, recipient, amount);
        } else {
            uint256 allocationFeeAmount = ((amount * ALLOCATION_FEE) / 100);
            super._transfer(sender, ALLOCATION_ADDRESS, allocationFeeAmount);

            uint256 teamFeeAmount = ((amount * TEAM_FEE) / 100);
            super._transfer(sender, TEAM_ADDRESS, teamFeeAmount);

            amount = amount - allocationFeeAmount - teamFeeAmount;
            super._transfer(sender, recipient, amount);
        }
    }


    function excludeFromFee(address account, bool status) public onlyOwner {
        _isExcludedFromFee[account] = status;
    }
}