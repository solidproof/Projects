// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";

import "@chainlink/contracts/src/v0.8/VRFConsumerBase.sol";

import "./KryxiviaNft.sol";

contract KryxiviaMysteryBoxes is AccessControl, Pausable, VRFConsumerBase {
    KryxiviaNft kryxiviaNft;

    bytes32 internal keyHash;
    uint256 internal fee;

    struct RandomItem {
        string ipfsHash;
        uint256 weight;
    }

    struct MysteryBox {
        uint256 price;
        mapping(uint8 => RandomItem[]) randomItemsBatches;
        uint8 randomItemsBatchesCount;
        string[] fixItems;
        bool isActive;
    }

    string[] public boxNames;
    mapping(string => MysteryBox) public boxes;

    mapping(bytes32 => address) private requestIdToAddress;
    mapping(bytes32 => string) private requestIdToBoxName;

    event BoxCreated(string indexed refName, string name, uint256 price, address creator);

    event BoxEnabled(string indexed refName, string name);
    event BoxDisabled(string indexed refName, string name);

    event BoxOpened(string indexed refName, string name, address indexed refPayer, address payer);
    event BoxRandomItemRevealed(string indexed refName, string name, string indexed refIpfsHash, string ipfsHash, address indexed refPayer, address payer);

    /**
     * @dev Grants `DEFAULT_ADMIN_ROLE` to the
     * account that deploys the contract.
     *
     */
    constructor(
        address _kryxiviaNft,
        bytes32 _keyHash,
        uint256 _fee,
        address _vrfCoordinator,
        address _link
    ) VRFConsumerBase(_vrfCoordinator, _link) {
        kryxiviaNft = KryxiviaNft(_kryxiviaNft);

        keyHash = _keyHash;
        fee = _fee;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @dev Create a Mystery Box.
     */
    function createBox(string calldata _name, uint256 _price, string[] memory _fixItems) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "KryxiviaMysteryBoxes: Must have ADMIN_ROLE to create a box");
        require(boxes[_name].price == 0, "KryxiviaMysteryBoxes: Box name already exists");
        require(_price > 0, "KryxiviaMysteryBoxes: Box price must be greater than zero");

        MysteryBox storage box = boxes[_name];
        box.isActive = true;
        box.price = _price;
        box.fixItems = _fixItems;

        boxNames.push(_name);

        emit BoxCreated(_name, _name, _price, msg.sender);
        emit BoxEnabled(_name, _name);
    }

    /**
     * @dev Enable or disable a Mystery Box depending on its actual state.
     */
    function flipBoxState(string calldata _name) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "KryxiviaMysteryBoxes: Must have ADMIN_ROLE to flip a box state");
        require(boxes[_name].price > 0, "KryxiviaMysteryBoxes: This box does not exist");

        MysteryBox storage box = boxes[_name];
        box.isActive = !box.isActive;

        if (box.isActive) {
            emit BoxEnabled(_name, _name);
        } else {
            emit BoxDisabled(_name, _name);
        }
    }

    /**
     * @dev Add a batch of random items to an existing Mystery Box.
     */
    function addRandomItemsBatchToBox(string calldata _name, RandomItem[] memory _randomItems) public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "KryxiviaMysteryBoxes: Must have ADMIN_ROLE to fill a box");
        require(boxes[_name].price > 0, "KryxiviaMysteryBoxes: This box does not exist");
        require(boxes[_name].isActive, "KryxiviaMysteryBoxes: This box is disabled");

        uint8 count = boxes[_name].randomItemsBatchesCount;

        for (uint256 i = 0; i < _randomItems.length; i++) {
            RandomItem memory randomItem = _randomItems[i];
            boxes[_name].randomItemsBatches[count].push(randomItem);
        }

        boxes[_name].randomItemsBatchesCount = count + 1;
    }

    /**
     * @dev Payable function to open a Mystery Box.
     */
    function open(string calldata _name) public payable whenNotPaused {
        require(boxes[_name].price > 0, "KryxiviaMysteryBoxes: This box does not exist");
        require(boxes[_name].isActive, "KryxiviaMysteryBoxes: This box is disabled");

        MysteryBox storage box = boxes[_name];
        require(box.price <= msg.value, "KryxiviaMysteryBoxes: BNB value sent is not correct");

        if (box.randomItemsBatchesCount > 0) {
            require(LINK.balanceOf(address(this)) >= fee, "KryxiviaMysteryBoxes: Not enough LINK on the contract");

            bytes32 requestId = requestRandomness(keyHash, fee);
            requestIdToAddress[requestId] = msg.sender;
            requestIdToBoxName[requestId] = _name;
        }

        if (box.fixItems.length > 0) {
            for (uint256 i = 0; i < box.fixItems.length; i++) {
                string storage itemIpfsHash = box.fixItems[i];
                kryxiviaNft.mint(msg.sender, itemIpfsHash);
            }
        }

        emit BoxOpened(_name, _name, msg.sender, msg.sender);
    }

    /**
     * @dev Callback function used by VRF Coordinator.
     */
    function fulfillRandomness(bytes32 requestId, uint256 randomness) internal override {
        address requestAddress = requestIdToAddress[requestId];
        string storage requestBoxName = requestIdToBoxName[requestId];

        MysteryBox storage box = boxes[requestBoxName];

        for (uint8 i = 0; i < box.randomItemsBatchesCount; i++) {
            string memory itemIpfsHash = getWeightedRandomItemIpfsHash(box, i, randomness);
            kryxiviaNft.mint(requestAddress, itemIpfsHash);

            emit BoxRandomItemRevealed(requestBoxName, requestBoxName, itemIpfsHash, itemIpfsHash, requestAddress, requestAddress);
        }
    }

    /**
     * @dev Returns one batch item randomly considering its weight.
     */
    function getWeightedRandomItemIpfsHash(MysteryBox storage box, uint8 batchIndex, uint256 randomness) internal view returns (string memory) {
        RandomItem[] storage randomItems = box.randomItemsBatches[batchIndex];

        uint256 sumOfWeight = 0;
        for (uint256 i = 0; i < randomItems.length; i++) {
            sumOfWeight += randomItems[i].weight;
        }

        uint256 rand = (randomness % sumOfWeight) - 1;
        for (uint256 i = 0; i < randomItems.length; i++) {
            if (rand < randomItems[i].weight) return randomItems[i].ipfsHash;
            rand -= randomItems[i].weight;
        }

        return "";
    }

    /**
     * @dev Returns boxNames array length.
     */
    function boxNamesLength() public view returns (uint256 length) {
        return boxNames.length;
    }

    /**
     * @dev Pauses the contract.
     */
    function pause() public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "KryxiviaMysteryBoxes: Must have ADMIN_ROLE to pause");
        _pause();
    }

    /**
     * @dev Unpauses the contract.
     */
    function unpause() public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "KryxiviaMysteryBoxes: Must have ADMIN_ROLE to unpause");
        _unpause();
    }

    /**
     * @dev Withdraw BNB from the contract.
     */
    function withdraw() public {
        require(hasRole(DEFAULT_ADMIN_ROLE, msg.sender), "KryxiviaMysteryBoxes: Must have ADMIN_ROLE to withdraw BNB");

        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }
}