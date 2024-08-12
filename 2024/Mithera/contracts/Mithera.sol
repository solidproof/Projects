/**
 *Submitted for verification at BscScan.com on 2024-04-18
*/

/**
 *Submitted for verification at BscScan.com on 2021-11-05
*/

// SPDX-License-Identifier: UNLISCENSED

/**
Welcome to Mithera Token.
Sale will be available on binance soon. By now or buy later on binance listing. 

Links: 
Website - https://mithera.io
Mithera Wallet - https://wallet.mithera.io
Medium: https://medium.com/@miraqlecoin

 **/

pragma solidity ^0.8.2;

contract Mithera {

    mapping (address => uint) public balances;
    mapping (address => mapping(address => uint)) public allowance;

    uint public totalSupply = 2000000000000000000000000000; // 2B tokens
    string public name = "Mithera";
    string public symbol = "MTR"; 
    uint public decimals = 18;

    event Transfer(address indexed from, address indexed to, uint value);
    event Approval(address indexed owner, address indexed spender, uint value);
    
    constructor() {
        balances[msg.sender] = totalSupply;
    }

    function balanceOf(address owner) public view returns (uint) {
        return balances[owner];
    }

    function transfer (address to, uint value) public  returns(bool) {
        require(balanceOf(msg.sender) >= value, 'balance too low');
        balances[to] += value;
        balances[msg.sender] -= value;
        emit Transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom (address from, address to, uint value) public returns (bool) {
        require(balanceOf(from) >= value, 'balance too low');
        require(allowance[from][msg.sender] >= value, 'allowance too low');
        balances[to] += value;
        balances[from] -= value;
        emit Transfer(from, to, value);
        return true;

    }
    
    function approve (address spender, uint value) public returns (bool) {
        allowance[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }
    
}