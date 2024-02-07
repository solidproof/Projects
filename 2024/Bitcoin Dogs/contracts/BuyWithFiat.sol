// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract BuyWithFiat {
    using SafeERC20 for IERC20;

    constructor(address _feeReceiver, address _adminAddress) {
        feeReceiver = _feeReceiver;
        adminAddress = _adminAddress;
    }

    event Buy(address wallet, uint256 memeAmount, uint256 ethAmount);

    address immutable feeReceiver;
    address immutable adminAddress;

    mapping(address => uint256) buyRecord;

    struct BuyRecord {
        address user;
        uint256 amount;
    }

    function recover(BuyRecord[] memory records) public {
        require(msg.sender == adminAddress, "Only admin can recover");
        for (uint256 i = 0; i < records.length; i++) {
            buyRecord[records[i].user] = records[i].amount;
        }
    }

    function buy(address wallet, uint256 memeAmount) public payable {
        buyRecord[wallet] = buyRecord[wallet] + memeAmount;

        emit Buy(wallet, memeAmount, msg.value);

        payable(feeReceiver).transfer(msg.value);
    }

    function getPurchased(address wallet) public view returns (uint256) {
        return buyRecord[wallet];
    }

    receive() external payable {
        // Handle the received Ether
    }
}