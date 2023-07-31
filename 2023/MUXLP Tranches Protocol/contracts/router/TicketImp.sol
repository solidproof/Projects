// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

import "./Type.sol";

enum Action {
    Invalid,
    DepositJunior,
    WithdrawJunior,
    WithdrawSenior
}

enum Status {
    Invalid,
    Init,
    Pending,
    Failed
}

struct Ticket {
    Action action;
    Status status;
    uint64 id;
    uint64 orderId;
    bytes params;
}

struct DepositJuniorParams {
    uint256 assets;
}

struct JuniorWithdrawParams {
    address caller;
    address account;
    uint256 shares;
    uint256 debts;
    uint256 assets;
    uint256 removals;
}

struct SeniorWithdrawParams {
    address caller;
    address account;
    uint256 shares;
    uint256 removals;
    uint256 minRepayments;
}

library TicketImp {
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;

    event CreateTicket(Ticket ticket);
    event UpdateTicket(Ticket ticket);
    event RemoveTicket(Ticket ticket);

    function getTicket(
        RouterStateStore storage store,
        uint64 ticketId
    ) internal view returns (Ticket storage ticket) {
        ticket = store.ticket.tickets[ticketId];
        require(ticket.action != Action.Invalid, "TicketImp::INVALID_ACTION");
    }

    function getTicketByOrderId(
        RouterStateStore storage store,
        uint64 orderId
    ) internal view returns (Ticket storage ticket) {
        uint64 ticketId = store.ticket.ticketIndex[orderId];
        require(ticketId != 0, "TicketImp::ORDER_ID");
        ticket = store.ticket.tickets[ticketId];
        require(ticket.action != Action.Invalid, "TicketImp::INVALID_ACTION");
    }

    function createTicket(
        RouterStateStore storage store,
        Action action,
        bytes memory params
    ) internal returns (Ticket storage ticket) {
        uint64 ticketId = store.ticket.nextId++;
        ticket = store.ticket.tickets[ticketId];
        ticket.id = ticketId;
        ticket.status = Status.Init;
        ticket.action = action;
        ticket.params = params;
        require(store.ticket.ticketIds.add(ticketId), "TicketImp::FAILED_TO_ADD");

        emit CreateTicket(ticket);
    }

    function updateTicket(
        RouterStateStore storage store,
        Ticket storage ticket,
        uint64 orderId,
        Status status,
        bytes memory params
    ) internal {
        ticket.params = params;
        updateTicket(store, ticket, orderId, status);
    }

    function updateTicket(
        RouterStateStore storage store,
        Ticket storage ticket,
        uint64 orderId,
        Status status
    ) internal {
        // clean previous order id (which is already cancelled)
        if (ticket.orderId != 0) {
            store.ticket.ticketIndex[ticket.orderId] = 0;
        }
        ticket.status = status;
        ticket.orderId = orderId;
        store.ticket.ticketIndex[orderId] = ticket.id;

        emit UpdateTicket(ticket);
    }

    function removeTicket(RouterStateStore storage store, Ticket storage ticket) internal {
        uint64 ticketId = ticket.id;
        uint64 orderId = ticket.orderId;
        if (orderId != 0) {
            delete store.ticket.ticketIndex[orderId];
        }
        require(store.ticket.ticketIds.remove(ticketId), "TicketImp::FAILED_TO_REMOVE");
        delete store.ticket.tickets[ticketId];

        emit RemoveTicket(ticket);
    }
}
