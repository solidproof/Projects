pragma solidity ^0.8.14;

// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";

import {IEvoturesNFT} from "./interface/IEvoturesNFT.sol";
import {ILootboxTicket} from "./interface/ILootboxTicket.sol";

contract LootboxTicket is ERC721("Evotures Lootbox Tickets","EVOTICK"), ILootboxTicket {
    address public immutable evoturesContract;
    address public dev;
    uint public lastTicketId;

    uint256 private constant _COMMON_CHANCES = 100000;
    uint256 private constant _RARE_CHANCES = 30000;
    uint256 private constant _ULTRARARE_CHANCES = 10000;
    uint256 private constant _MYTHICAL_CHANCES = 1000;
    uint256 private constant _ANCIENT_CHANCES = 1;

    // tokenId => Rarity
    mapping(uint256 => Rarity) public rarity;

    constructor() {
        evoturesContract = msg.sender;
    }

    function initialize(address _dev) external {
        require(msg.sender == evoturesContract, "LootboxTicket: CALLER_NOT_EVOTURES");
        require(dev == address(0), "LootboxTicket: ALREADY_INITIALIZED");
        require(_dev != address(0), "LootboxTicket: ZERO_ADDRESS");
        dev = _dev;
    }

    function mint(address _to, Rarity _rarity) external {
        require(msg.sender == dev, "EvoturesNFT: CALLER_IS_NOT_DEV");
        _safeMint(_to, lastTicketId);
        rarity[lastTicketId] = _rarity;
        lastTicketId++;
    }

    function openLootBox(uint _ticketId) external {
        safeTransferFrom(msg.sender, evoturesContract, _ticketId);
        uint ticketChances;
        if (rarity[_ticketId] == Rarity.COMMON) {
            ticketChances = _COMMON_CHANCES;
        } else if (rarity[_ticketId] == Rarity.RARE) {
            ticketChances = _RARE_CHANCES;
        } else if (rarity[_ticketId] == Rarity.ULTRARARE) {
            ticketChances = _ULTRARARE_CHANCES;
        } else if (rarity[_ticketId] == Rarity.MYTHICAL) {
            ticketChances = _MYTHICAL_CHANCES;
        } else if (rarity[_ticketId] == Rarity.ANCIENT) {
            ticketChances = _ANCIENT_CHANCES;
        }
        IEvoturesNFT(evoturesContract).mint(msg.sender, ticketChances);
    }
}