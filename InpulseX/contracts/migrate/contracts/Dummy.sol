// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

contract Dummy {
    mapping(address => uint256) private _balances;

    constructor() {
        _balances[msg.sender] = 1000;
    }

    function balanceOf(address addr) external view returns (uint256) {
        return _balances[addr];
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool) {
        _balances[to] += amount;
        _balances[from] -= amount;
        return true;
    }
}
