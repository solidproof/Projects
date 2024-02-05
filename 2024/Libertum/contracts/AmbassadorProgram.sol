// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "@openzeppelin/contracts/finance/VestingWallet.sol";

contract AmbassadorProgram is VestingWallet {
    constructor(
        address beneficiary
    )
        VestingWallet(
            beneficiary,
            uint64(block.timestamp) + 6 * 30 days,
            24 * 30 days
        )
    {}
}
