pragma solidity ^0.8.14;

// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

import {LootboxTicket} from "./LootboxTicket.sol";

import {IEvoturesNFT} from "./interface/IEvoturesNFT.sol";
import {ILootboxTicket} from "./interface/ILootboxTicket.sol";

contract EvoturesNFT is ERC721("Evotures NFTs","EVOTURES"), IEvoturesNFT, IERC721Receiver {
    using Address for address;
    using Strings for uint256;

    address public immutable ticketsContract;
    uint public lastTokenId;

    // tokenId => Stats
    mapping(uint256 => Stats) private _stats;

    constructor() {
        // Create LiquidityBundles contract
        bytes memory bytecode = type(LootboxTicket).creationCode;
        bytes32 salt = keccak256(abi.encodePacked(address(this)));
        address _ticketsContract;
        assembly {
            _ticketsContract := create2(0, add(bytecode, 32), mload(bytecode), salt)
        }
        ticketsContract = _ticketsContract;
        ILootboxTicket(ticketsContract).initialize(msg.sender);
    }

    function mint(address _to, uint _ticketChances) external {
        require(msg.sender == ticketsContract, "EvoturesNFT: CALLER_IS_NOT_TICKET");
        _safeMint(_to, lastTokenId);
        _stats[lastTokenId] = _getRandomStats(_ticketChances);
        lastTokenId++;
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        _requireMinted(tokenId);

        string memory baseURI = _baseURI();
        return bytes(baseURI).length > 0 ? string(abi.encodePacked(baseURI, _stats[tokenId].no.toString(), ".json")) : "";
    }

    // TODO: SET BASE URI
    function _baseURI() internal pure override returns (string memory) {
        return "ipfs://TODO/";
    }

    // TODO: SET CONTARCT URI
    function contractURI() public pure returns (string memory) {
        return "ipfs://TODO/0.json";
    }

    function _pseudoRand(uint _chances, uint _seed) private view returns(uint256) {
        uint256 seed = uint256(
            keccak256(
                abi.encodePacked(
                    _seed +
                    block.timestamp +
                    block.difficulty +
                    ((
                        uint256(keccak256(abi.encodePacked(block.coinbase)))
                    ) / (block.timestamp)) +
                    block.gaslimit +
                    ((uint256(keccak256(abi.encodePacked(tx.origin)))) /
                        (block.timestamp)) +
                    block.number +
                    ((uint256(keccak256(abi.encodePacked(address(this))))) /
                        (block.timestamp)) +
                    ((uint256(keccak256(abi.encodePacked(msg.sender)))) /
                        (block.timestamp))
                )
            )
        );

        return (seed % _chances);
    }

    function _randomBoolean() private view returns (bool) {
        return uint256(keccak256(abi.encodePacked(block.difficulty, block.coinbase, block.timestamp))) % 2 > 0;
    }

    function _getRandomStats(uint _chances) private view returns(Stats memory s) {
        uint rand = _pseudoRand(_chances, 0);
        // ANCIENT
        if (rand == 0) {
            s.rarity = Rarity.ANCIENT;
            s.no = 1;
            s.multiplier = 50;
            s.hp = _pseudoRand(51, 0) + 100;
            s.attack = _pseudoRand(51, s.hp) + 100;
            s.defense = _pseudoRand(51, s.attack) + 100;
            s.speed = _pseudoRand(51, s.defense) + 100;
            s.special = _pseudoRand(51, s.special) + 100;
        // MYTHICAL
        } else if (rand <= 999) {
            s.rarity = Rarity.MYTHICAL;
            s.no = (rand % 3) + 2;
            s.multiplier = 25;
            s.hp = _pseudoRand(51, 0) + 75;
            s.attack = _pseudoRand(51, s.hp) + 75;
            s.defense = _pseudoRand(51, s.attack) + 75;
            s.speed = _pseudoRand(51, s.defense) + 75;
            s.special = _pseudoRand(51, s.special) + 75;
        // ULTRARARE
        } else if (rand <= 9999) {
            s.rarity = Rarity.ULTRARARE;
            s.no = (rand % 10) + 5;
            s.multiplier = 10;
            s.hp = _pseudoRand(41, 0) + 60;
            s.attack = _pseudoRand(41, s.hp) + 60;
            s.defense = _pseudoRand(41, s.attack) + 60;
            s.speed = _pseudoRand(41, s.defense) + 60;
            s.special = _pseudoRand(41, s.special) + 60;
        // RARE
        } else if (rand <= 29999) {
            s.rarity = Rarity.RARE;
            s.no = (rand % 15) + 15;
            s.multiplier = 5;
            s.hp = _pseudoRand(51, 0) + 40;
            s.attack = _pseudoRand(51, s.hp) + 40;
            s.defense = _pseudoRand(51, s.attack) + 40;
            s.speed = _pseudoRand(51, s.defense) + 40;
            s.special = _pseudoRand(51, s.special) + 40;
        // COMMON
        } else {
            s.rarity = Rarity.COMMON;
            s.no = (rand % 21) + 30;
            s.multiplier = 1;
            s.hp = _pseudoRand(61, 0) + 5;
            s.attack = _pseudoRand(61, s.hp) + 5;
            s.defense = _pseudoRand(61, s.attack) + 5;
            s.speed = _pseudoRand(61, s.defense) + 5;
            s.special = _pseudoRand(61, s.special) + 5;
        }

        if (_randomBoolean()) {
            s.alignment = Alignment.ABOMINATION;
            s.no += 1000;
        } else {
            s.alignment = Alignment.DIVINE;
        }
    }

    function onERC721Received(
        address,
        address,
        uint256,
        bytes calldata
    ) external returns (bytes4) {
        return IERC721Receiver.onERC721Received.selector;
    }

    function stats(uint _tokenId) external view returns(Stats memory) {
        _requireMinted(_tokenId);
        return _stats[_tokenId];
    }
}