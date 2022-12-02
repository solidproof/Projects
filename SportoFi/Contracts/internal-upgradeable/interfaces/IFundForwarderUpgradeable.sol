// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../../interfaces/ITreasury.sol";

interface IFundForwarderUpgradeable {
    event TreasuryUpdated(ITreasury indexed from, ITreasury indexed to);

    function updateTreasury(ITreasury treasury_) external;
}