// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../token/IFCKToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract LotteryManager is Ownable {
    event LotteryStarted(uint256 id, uint256 ticketPrice, uint256 endsAt);

    event TicketBought(uint256 id, address indexed buyer);

    event LotteryCompleted(uint256 id, address indexed winner);

    struct Lottery {
        uint256 id;
        bool active;
        uint256 ticketPrice;
        uint256 startedAt;
        uint256 saleEndsAt;
        uint256 endsAt;
        address winner;
        address[] participants;
        mapping(address => uint256) holds;
    }

    IFCKToken private _token;
    uint256 private _lotteriesCount;
    mapping(uint256 => Lottery) private _lotteries;

    constructor(IFCKToken token) {
        _token = token;
    }

    function startLottery(
        uint256 ticketPrice,
        uint256 saleEndsAt,
        uint256 endsAt
    ) external onlyOwner returns (uint256 id) {
        require(endsAt > block.timestamp, "Lottery: Invalid end time");
        require(
            saleEndsAt > block.timestamp && saleEndsAt < endsAt,
            "Lottery: Invalid sale end time"
        );
        require(ticketPrice > 0, "Lottery: Invalid ticket price");
        _lotteriesCount += 1;
        uint256 lotteryId = _lotteriesCount;
        Lottery storage lottery = _lotteries[lotteryId];
        lottery.id = lotteryId;
        lottery.active = true;
        lottery.ticketPrice = ticketPrice;
        lottery.startedAt = block.timestamp;
        lottery.saleEndsAt = saleEndsAt;
        lottery.endsAt = endsAt;
        emit LotteryStarted(lottery.id, lottery.ticketPrice, lottery.endsAt);
        return lottery.id;
    }

    function getLottery(uint256 lotteryId)
        external
        view
        returns (
            bool active,
            uint256 ticketPrice,
            uint256 startedAt,
            uint256 saleEndsAt,
            uint256 endsAt,
            uint256 ticketsSold,
            address winner
        )
    {
        Lottery storage lottery = _lotteries[lotteryId];
        return (
            lottery.active,
            lottery.ticketPrice,
            lottery.startedAt,
            lottery.saleEndsAt,
            lottery.endsAt,
            lottery.participants.length,
            lottery.winner
        );
    }

    function buyTicket(uint256 lotteryId) external {
        Lottery storage lottery = _lotteries[lotteryId];
        require(
            lottery.active && lottery.saleEndsAt > block.timestamp,
            "Lottery: Sale period is over"
        );
        require(
            _token.balanceOf(msg.sender) >= lottery.ticketPrice,
            "LotteryManager: Insufficient funds"
        );
        require(
            _token.allowance(msg.sender, address(this)) >= lottery.ticketPrice,
            "LotteryManager: Insufficient funds"
        );
        _token.transferFrom(msg.sender, address(this), lottery.ticketPrice);
        lottery.participants.push(msg.sender);
        lottery.holds[msg.sender] += lottery.ticketPrice;
        emit TicketBought(lotteryId, msg.sender);
    }

    function getTicketsCount(uint256 lotteryId, address buyer)
        external
        view
        returns (uint256)
    {
        Lottery storage lottery = _lotteries[lotteryId];
        return lottery.holds[buyer] / lottery.ticketPrice;
    }

    function getParticipant(uint256 lotteryId, uint256 participantIndex)
        external
        view
        returns (address)
    {
        Lottery storage lottery = _lotteries[lotteryId];
        return lottery.participants[participantIndex];
    }

    function completeLottery(uint256 lotteryId)
        external
        onlyOwner
        returns (address)
    {
        Lottery storage lottery = _lotteries[lotteryId];
        require(lottery.active, "Lottery: Already completed");
        require(lottery.endsAt < block.timestamp, "Lottery: Is not over yet");
        lottery.active = false;
        if (lottery.participants.length > 0) {
            uint256 winnerId = random(lottery) % lottery.participants.length;
            lottery.winner = lottery.participants[winnerId];
        }
        return lottery.winner;
    }

    function claimHold(uint256 lotteryId) external {
        Lottery storage lottery = _lotteries[lotteryId];
        require(!lottery.active, "Lottery: Is not over yet");
        _token.transfer(msg.sender, lottery.holds[msg.sender]);
        lottery.holds[msg.sender] = 0;
    }

    function random(Lottery storage lottery) private view returns (uint256) {
        return
            uint256(
                keccak256(
                    abi.encode(
                        block.difficulty,
                        block.timestamp,
                        lottery.participants,
                        block.number
                    )
                )
            );
    }
}
