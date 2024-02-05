// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "../interfaces/ISeniorVault.sol";
import "../interfaces/IJuniorVault.sol";
import "../interfaces/IRewardController.sol";

import "../libraries/LibConfigSet.sol";
import "../common/Keys.sol";
import "./TicketImp.sol";

uint256 constant ONE = 1e18;

enum RouterStatus {
    Normal,
    Rebalance,
    Liquidation
}

struct TicketStates {
    uint64 nextId;
    mapping(uint64 => Ticket) tickets;
    mapping(uint64 => uint64) ticketIndex;
    EnumerableSetUpgradeable.UintSet ticketIds;
    bytes32[20] __reserves;
}

struct MuxOrderContext {
    uint64 orderId;
    uint8 seniorAssetId;
    uint96 seniorPrice;
    uint96 juniorPrice;
    uint96 currentSeniorValue;
    uint96 targetSeniorValue;
}

struct RouterStateStore {
    // components
    ISeniorVault seniorVault;
    IJuniorVault juniorVault;
    IRewardController rewardController;
    // properties
    TicketStates ticket;
    LibConfigSet.ConfigSet config;
    RouterStatus status;
    uint256 totalPendingSeniorWithdrawal;
    mapping(address => uint256) pendingSeniorWithdrawals;
    uint256 totalPendingJuniorWithdrawal;
    mapping(address => uint256) pendingJuniorWithdrawals;
    mapping(address => uint8) idLookupTable;
    bytes32[20] __reserves;
}
