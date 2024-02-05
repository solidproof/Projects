// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/finance/VestingWallet.sol";

contract Airdrop is VestingWallet {
    constructor(
        address beneficiary
    ) VestingWallet(beneficiary, uint64(block.timestamp) + 30 days, 0) {}
}
