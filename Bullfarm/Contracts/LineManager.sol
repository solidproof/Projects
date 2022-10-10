// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IBullFarm.sol";

contract LineManager {
    uint[3] lines = [0.1 ether, 0.5 ether, 1 ether];
    mapping(address => uint) deposits;
    mapping(address => bool) migrated;
    IBullFarm public farm;

    event Deposit(address account, uint value);
    event Migration(address, uint value);

    constructor(IBullFarm _farm) {
        farm = _farm;
    }

    receive() external payable {
        deposits[msg.sender] += msg.value;
        require(deposits[msg.sender] <= 1 ether, "Max deposit reached");

        uint openLines = calcOpenLines(deposits[msg.sender]);
        farm.setOpenLines(msg.sender, openLines);
        emit Deposit(msg.sender, msg.value);
    }

    function migrate() external {
        require(!migrated[msg.sender], "Already migrated");
        migrated[msg.sender] = true;
        farm.depositTo{value: deposits[msg.sender]}(msg.sender);
        emit Migration(msg.sender, deposits[msg.sender]);
    }

    function getDeposit(address account) external view returns(uint) {
        return deposits[account];
    }

    function isMigrated(address account) external view returns(bool) {
        return migrated[account];
    }

    function calcOpenLines(uint dep) public view returns(uint) {
        if (dep >= lines[2]) {
            return 3;
        } else if (dep >= lines[1]) {
            return 2;
        } else if (dep >= lines[0]) {
            return 1;
        }

        return 0;
    }
}