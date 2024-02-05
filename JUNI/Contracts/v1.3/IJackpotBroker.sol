// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

enum JackpotState {
    Inactive,
    Active,
    Decision,
    Awarded
}
enum JackpotRank {
    Bronze,
    Silver,
    Gold,
    Misc
}

struct User {
    address wallet;
    uint256 bronzeTickets;
    uint256 bronzeId;
    uint256 silverTickets;
    uint256 silverId;
    uint256 goldTickets;
    uint256 goldId;
    uint256 miscTickets;
    uint256 miscId;
}

struct RankedJackpot {
    uint256 id;
    JackpotRank rank;
    JackpotState state;
    bool isNative;
    address ticketToken;
    address awardToken;
    uint256 value;
    uint256 timespan;
    uint256 createdAt;
    uint256 lastUserAmount;
    address lastUser;
    uint256 totalUsers;
    uint256 totalTickets;
}

interface IJackpotBroker {
    function fundJackpots(
        uint256 bronze,
        uint256 silver,
        uint256 gold
    ) external payable;

    function processBroker() external;
}
