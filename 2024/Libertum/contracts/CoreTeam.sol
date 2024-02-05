// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/finance/VestingWallet.sol";

contract CoreTeam is VestingWallet {
    constructor(
        address beneficiary
    )
        VestingWallet(
            beneficiary,
            uint64(block.timestamp) + 12 * 30 days,
            48 * 30 days
        )
    {}
}
