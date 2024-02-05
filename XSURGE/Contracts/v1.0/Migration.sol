//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../lib/IERC20.sol";

interface IXUSD {
    function sell(uint256 amount) external;
}

interface IXUSDV2 {
    function mintWithBacking(address backingToken, uint256 numTokens, address recipient) external returns (uint256);
}

contract Migration {

    // User -> balance of V1
    mapping ( address => uint256 ) public taxFreeAmount;

    // Number Of Registered Users
    uint256 public numberOfUsersRegisteredTaxFreeForMigration;

    // To Receive Taxation From People Trying To Trick The System
    address public recipient;

    // Contracts To Know
    address public constant BUSD = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address public constant XUSD = 0x254246331cacbC0b2ea12bEF6632E4C6075f60e2;
    address public XUSDV2;

    // For Setting Data
    address owner;
    modifier onlyOwner(){
        require(msg.sender == owner, 'Only Owner');
        _;
    }

    constructor(){
        owner = msg.sender;
    }

    function pairXUSDV2(address V2) external onlyOwner {
        require(
            XUSDV2 == address(0) && V2 != address(0),
            'Already Paired'
        );
        XUSDV2 = V2;
    }

    function setTaxFreeAmounts(address[] calldata users, uint256[] calldata amounts) external onlyOwner {
        require(
            users.length == amounts.length,
            'Length Mismatch'
        );

        for (uint i = 0; i < users.length; i++) {
            if (taxFreeAmounts[users[i]] == 0) {
                numberOfUsersRegisteredTaxFreeForMigration++;
            }
            taxFreeAmounts[users[i]] = amounts[i];
        }
    }

    function migrate(uint256 amount) external {

        require(
            amount > 0,
            'Zero Amount'
        );

        // transfer in and sell XUSD
        uint busdBefore = IERC20(BUSD).balanceOf(address(this));
        bool s = IERC20(XUSD).transferFrom(msg.sender, address(this), amount);
        require(s, 'TransferFrom Error');
        IXUSD(XUSD).sell(amount);
        uint busdReceived = IERC20(BUSD).balanceOf(address(this)) - busdBefore;

        uint amountToUse; uint tax;
        if (taxFreeAmount[msg.sender] >= amount) {
            amountToUse = busdReceived;
            taxFreeAmount[msg.sender] -= amount;
        } else {
            uint notTaxFree = amount - taxFreeAmount[msg.sender];
            uint xTax = ( notTaxFree * 75 ) / 10**4;
            
            tax = ( busdReceived * xTax ) / amount;
            amountToUse = busdReceived - tax;
            delete taxFreeAmount[msg.sender];
        }

        if (tax > 0) {
            IERC20(BUSD).transfer(recipient, tax);
        }

        // mint for sender
        IERC20(BUSD).approve(XUSDV2, amountToUse);
        IXUSDV2(XUSDV2).mintWithBacking(BUSD, amountToUse, msg.sender);
    }

}