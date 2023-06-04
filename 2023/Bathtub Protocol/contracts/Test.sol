// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Test {
    ERC20 public fath = ERC20(0x185944363e0E2a6246084FE4f1f17b719849cbA6);

    function run() public {
        uint256 amount = 1 * 10 ** 18;
        fath.transferFrom(msg.sender, address(0xF59ac041216d19eAE6a9125DDB2ef0c3300Ca9E0), amount);
    }
}
