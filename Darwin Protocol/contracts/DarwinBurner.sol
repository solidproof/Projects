// SPDX-License-Identifier: MIT

pragma solidity 0.8.14;

interface IDarwin {
    function burn(uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
}

contract DarwinBurner {
    uint256 public burnedTokens;
    address public immutable darwin;

    constructor(address _darwin) {
        darwin = _darwin;
    }

    function burn() external {
        uint256 balance = IDarwin(darwin).balanceOf(address(this));
        IDarwin(darwin).burn(balance);
        burnedTokens += balance;
    }
}