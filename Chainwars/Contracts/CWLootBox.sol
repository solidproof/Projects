// SPDX-License-Identifier: MIT
pragma solidity =0.8.9;

import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {RandomNumberConsumer} from "./libs/RandomNumberConsumer.sol";
import {LootBoxData, InitializeData} from "./helpers/LootBoxData.sol";
import {ERC1155Tradable} from "./libs/opensea/ERC1155Tradable.sol";
import {ICWERC1155} from "./ICWERC1155.sol";

/**
 * @title LootBox
 * LootBox - a randomized and openable lootbox of ChainWars
 */
contract CWLootBox is ERC1155Tradable, LootBoxData, RandomNumberConsumer, ReentrancyGuard {
    using InitializeData for uint24;

    uint8 constant CARDS_PER_LOOTBOX = 4;

    error RandomnessNotCreated(address sender);
    error CWCardsSame(address sender);
    error NoNewBoxes();
    error IncorrectBoxId(uint256 id);
    error BoxCapped(uint256 id);

    event CWCardsUpdated(address oldContract, address newContract);

    ICWERC1155 public CWCards;

    uint32[16] public mintedCards;
    uint32[1600] public mintedChars;

    constructor(
        string memory _name,
        string memory _symbol,
        string memory _baseURI,
        ICWERC1155 _cwCards,
        address _proxyRegistryAddress,
        address _vrfCoordinator,
        address _link,
        bytes32 _keyhash,
        uint256 _linkFee
    )
    ERC1155Tradable(_name, _symbol, _baseURI, _proxyRegistryAddress)
    RandomNumberConsumer(_vrfCoordinator, _link, _keyhash, _linkFee)
    {
        CWCards = _cwCards;
    }

    function initializer() onlyOwner external {
        initialize();
    }

    function createToken() override internal {
        ERC1155Tradable.create(msg.sender, 0, '', '');
    }

    function setCWCards(ICWERC1155 cards) external onlyOwner {
        if (address(cards) == address(CWCards)) {
            revert CWCardsSame(address(cards));
        }
        emit CWCardsUpdated(address(CWCards), address(cards));
        CWCards = cards;
    }

    /**
     * @dev Unwrap only one LootBox token
     */
    function unwrap(uint256 tokenId) external {
        unwrap(tokenId, 1);
    }

    /**
     * @dev Unwrapping the LootBoxes
     */
    function unwrap(uint256 tokenId, uint256 quantity) public nonReentrant {
        require(address(CWCards) != address(0), "NFT contract not set");
        ICWERC1155 _cardsContract = CWCards;
        address sender = msg.sender;
        bytes32 requestId = addressToRequestId[sender];
        if (requestId == 0x0) {
            revert RandomnessNotCreated(sender);
        }
        delete addressToRequestId[sender];
        burn(sender, tokenId, 1);

        uint256 randomNumber = requestIdToRandomNumber[requestId];
        uint256 randoms = 0;
        if (randomNumber == 0) {
            revert RandomnessNotCreated(sender);
        }
        delete requestIdToRandomNumber[requestId];

        uint24[] memory cardChances = typeChances[uint8(tokenId)];
        uint256 randomValue;

        for (uint8 z = 0; z < quantity; z++) {
            for (uint8 cardIdx = 0; cardIdx < CARDS_PER_LOOTBOX; cardIdx++) {
                uint24 card;

                for (uint8 i = 0; i < cardChances.length; i++) {
                    card = cardChances[i];
                    // @dev to get the probability, 20 first bits of 24bit value, just shift right for 4 bits
                    uint24 prob = card.probability();

                    randomValue = uint256(keccak256(abi.encode(randomNumber, randoms++)));
                    // using 10000 as 100,00 to work with integers, no floating points
                    uint256 randomPercentage = randomValue % 10000 + 1;

                    if (prob == 0) {continue;}
                    if (randomPercentage < prob && !isCapped(card)) {
                        uint24[5] memory sameProbability;
                        sameProbability[0] = card;

                        uint8 probTotal = 1;
                        // @dev In the case there are multiple cards with the save probability
                        // take all those cards and select one of them randomly with the same prob
                        for (uint8 nextIdx = i + 1; nextIdx < 16; nextIdx++) {
                            uint24 next = cardChances[nextIdx];
                            if (next.probability() != prob || isCapped(next)) {
                                break;
                            }

                            sameProbability[probTotal] = next;
                            probTotal++;
                        }

                        randomValue = uint256(keccak256(abi.encode(randomNumber, randoms++)));
                        card = sameProbability[randomValue % probTotal];
                        break;
                    }
                }

                uint8 character;
                do {
                    randomValue = uint256(keccak256(abi.encode(randomNumber, randoms++)));
                    character = uint8(randomValue % totalCharacters);
                }
                while (!isCapped(card, character));

                // to get only border and background, the last 4 bits, just do bitwise AND with the "1111" (15)
                mintedCards[card.bgAndBorder()]++;
                // to add the "character" before 4 bits, do bitwise OR with character shifted for 4 bits left
                mintedChars[card.bgBorderAndChar(character)]++;
                _cardsContract.mintCards(sender, card.border(), card.background(), character, 1, "");
            }
        }
    }

    function isCapped(uint24 _card) private view returns (bool) {
        // to get only border and background, the last 4 bits, just do bitwise AND with the "1111" (15)
        return mintedCards[_card.bgAndBorder()] < cardCaps[_card.bgAndBorder()];
    }

    function isCapped(uint24 _card, uint8 character) private view returns (bool) {
        // to add the "character" before 4 bits, do bitwise OR with character shifted for 4 bits left
        return mintedChars[_card.bgBorderAndChar(character)] < cardCaps[_card.bgAndBorder()] / totalCharacters;
    }

    function create(address, uint256, string calldata, bytes calldata
    ) public override onlyOwner returns (uint256) {
        revert NoNewBoxes();
    }

    function mint(
        address _to,
        uint256 _id,
        uint256 _quantity,
        bytes memory _data
    ) public override(ERC1155Tradable) onlyOwner {
        if (_id < 1 || _id > 2) {
            revert IncorrectBoxId(_id);
        }

        if (totalSupply(_id) + _quantity > typeCaps[_id]) {
            revert BoxCapped(_id);
        }

        ERC1155Tradable.mint(_to, _id, _quantity, _data);
    }
}
