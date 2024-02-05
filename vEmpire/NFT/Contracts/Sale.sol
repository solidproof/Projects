// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import {MerkleProofUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";

/**
 * @notice Represents Vempire Smart Contract
 */
contract IVempire {
    /**
     * @dev ERC-721 INTERFACE
     */
    function ownerOf(uint256 tokenId) public view virtual returns (address) {}

    /**
     * @dev CUSTOM INTERFACE
     */
    function mintTokens(uint256 amount, address _to) external {}
}

contract Sale is
    Initializable,
    UUPSUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    AccessControlUpgradeable
{
    /**
     * @notice The Smart Contract of Vempire
     * @dev ERC-721 Smart Contract
     */
    IVempire public vempireNFT;

    /**
     * @dev MINT DATA
     */
    uint256 public maxSupply;
    uint256 public maxSupplyPhaseOne;
    uint256 public bought;

    uint256 public phaseOneStartTime;
    uint256 public phaseOneDuration;
    uint256 public phaseTwoStartTime;
    uint256 public phaseTwoDuration;
    uint256 public phaseThreeStartTime;

    uint256 public phaseOnePrice;
    uint256 public phaseTwoPrice;
    uint256 public phaseThreePrice;
    uint256 public limit;

    mapping(uint256 => uint256) public phaseMints;
    mapping(address => uint256) public addressToTicketsPermissioned;
    mapping(address => uint256) public addressToMints;

    bytes32 public merkleRootPhaseOne;
    bytes32 public merkleRootPhaseTwo;

    /**
     * @dev Events
     */
    event ReceivedEther(address indexed sender, uint256 indexed amount);
    event Purchase(
        address indexed buyer,
        uint256 indexed amount,
        bool indexed permissioned
    );
    event Redeem(address indexed redeemer, uint256 amount);
    event setMaxSupplyEvent(uint256 indexed maxSupply);
    event setMaxSupplyPhaseOneEvent(uint256 indexed maxSupply);
    event setMaxSupplyPhaseTwoEvent(uint256 indexed maxSupply);
    event setLimitEvent(uint256 indexed limit);
    event setPricePhaseOneEvent(uint256 indexed price);
    event setPricePhaseTwoEvent(uint256 indexed price);
    event setPricePhaseThreeEvent(uint256 indexed price);
    event setMerkleRootPhaseOneEvent(bytes32 indexed merkleRoot);
    event setMerkleRootPhaseTwoEvent(bytes32 indexed merkleRoot);
    event setPhaseOneStartTimeEvent(uint256 indexed time);
    event setPhaseOneDurationEvent(uint256 indexed time);
    event setPhaseTwoStartTimeEvent(uint256 indexed time);
    event setPhaseTwoDurationEvent(uint256 indexed time);
    event setPhaseThreeStartTimeEvent(uint256 indexed time);
    event WithdrawAllEvent(address indexed to, uint256 amount);

    function initialize(
        IVempire _vempireNFT,
        uint256 _phaseOneStartTime,
        uint256 _phaseOneDuration,
        uint256 _phaseTwoStartTime,
        uint256 _phaseTwoDuration,
        uint256 _phaseThreeStartTime
    ) public initializer {
        OwnableUpgradeable.__Ownable_init();
        maxSupply = 4500;
        maxSupplyPhaseOne = 1000;
        limit = 5;

        phaseOneStartTime = _phaseOneStartTime;
        phaseOneDuration = _phaseOneDuration;
        phaseTwoStartTime = _phaseTwoStartTime;
        phaseTwoDuration = _phaseTwoDuration;
        phaseThreeStartTime = _phaseThreeStartTime;

        phaseOnePrice = 0.5 ether;
        phaseTwoPrice = 0.75 ether;
        phaseThreePrice = 1 ether;

        vempireNFT = _vempireNFT;
    }

    /**
     * @notice Validates the sale data for each phase per user
     *
     * @dev For each phase validates that the time is correct,
     * that the ether supplied is correct and that the purchase
     * amount doesn't exceed the max amount
     *
     * @param amount. The amount the user want's to purchase
     * @param phase. The sale phase of the user
     * @param proof. The proof used to validate if user is whitelisted or not.
     */
    function validatePhaseSpecificPurchase(
        uint256 amount,
        uint256 phase,
        bytes32[] calldata proof
    ) internal {
        /// @dev Verifies Merkle Proof submitted by user.
        /// @dev All mint data is embedded in the merkle proof.

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        if (phase == 1) {
            require(
                block.timestamp >= phaseOneStartTime,
                "PHASE ONE SALE HASN'T STARTED YET"
            );
            require(
                block.timestamp < phaseOneStartTime + phaseOneDuration,
                "PHASE ONE SALE IS CLOSED"
            );
            require(
                msg.value >= phaseOnePrice * amount,
                "ETHER SENT NOT CORRECT"
            );
            require(merkleRootPhaseOne != "", "PERMISSIONED SALE CLOSED");
            require(
                MerkleProofUpgradeable.verify(proof, merkleRootPhaseOne, leaf),
                "INVALID PROOF"
            );
            require(
                bought + amount <= maxSupplyPhaseOne,
                "BUY AMOUNT GOES OVER MAX SUPPLY FOR PHASE"
            );
            require(
                addressToTicketsPermissioned[msg.sender] + amount <= limit,
                "BUY AMOUNT EXCEEDS MAX FOR USER"
            );
        } else if (phase == 2) {
            require(
                block.timestamp >= phaseTwoStartTime,
                "PHASE TWO SALE HASN'T STARTED YET"
            );
            require(
                block.timestamp < phaseTwoStartTime + phaseTwoDuration,
                "PHASE TWO SALE IS CLOSED"
            );
            require(
                msg.value >= phaseTwoPrice * amount,
                "ETHER SENT NOT CORRECT"
            );
            require(merkleRootPhaseTwo != "", "PERMISSIONED SALE CLOSED");
            require(
                MerkleProofUpgradeable.verify(proof, merkleRootPhaseTwo, leaf),
                "INVALID PROOF"
            );
        } else if (phase == 3) {
            require(
                block.timestamp >= phaseThreeStartTime,
                "PHASE THREE SALE HASN'T STARTED YET"
            );
            require(
                msg.value >= phaseThreePrice * amount,
                "ETHER SENT NOT CORRECT"
            );
        } else {
            revert("INCORRECT PHASE");
        }
    }

    /**
     * @notice Function to buy one or more tickets.
     * @dev First the Merkle Proof is verified.
     * Then the buy is verified with the data embedded in the Merkle Proof.
     * Finally the tokens are bought to the user's wallet.
     *
     * @param amount. The amount of tickets to buy.
     * @param phase. The permissioned sale phase.
     * @param proof. The Merkle Proof of the user.
     */
    function buy(
        uint256 amount,
        uint256 phase,
        bytes32[] calldata proof
    ) external payable {
        /// @dev Verify that user can perform permissioned sale based on the provided parameters.

        require(
            address(vempireNFT) != address(0),
            "NFT SMART CONTRACT NOT SET"
        );
        require(phase > 0 && phase < 4, "INCORRECT PHASE SUPPLIED");

        require(amount > 0, "HAVE TO BUY AT LEAST 1");
        require(
            bought + amount <= maxSupply,
            "BUY AMOUNT GOES OVER MAX SUPPLY"
        );

        /// @dev verify that user can perform permissioned sale based on phase of user
        validatePhaseSpecificPurchase(amount, phase, proof);
        bought += amount;
        addressToTicketsPermissioned[msg.sender] += amount;
        phaseMints[phase] += amount;
        emit Purchase(msg.sender, amount, true);
    }

    /**
     * @dev MINTING
     */

    /**
     * @notice Allows users to redeem their tickets for NFTs.
     *
     */
    function redeem() external {
        uint256 ticketsOfSender = addressToTicketsPermissioned[msg.sender];
        uint256 mintsOfSender = addressToMints[msg.sender];
        uint256 mintable = ticketsOfSender - mintsOfSender;

        require(mintable > 0, "NO MINTABLE TICKETS");

        addressToMints[msg.sender] = addressToMints[msg.sender] + mintable;

        vempireNFT.mintTokens(mintable, msg.sender);
        emit Redeem(msg.sender, mintable);
    }

    /**
     * @dev OWNER ONLY
     */

    /**
     * @notice Change the maximum supply of tokens that are for sale.
     *
     * @param newMaxSupply. The new max supply.
     */
    function setMaxSupply(uint256 newMaxSupply) external onlyOwner {
        maxSupply = newMaxSupply;
        emit setMaxSupplyEvent(newMaxSupply);
    }

    /**
     * @notice Change the maximum supply of tokens that are for sale in phase one.
     *
     * @param newMaxSupplyPhaseOne. The new max supply.
     */
    function setMaxSupplyPhaseOne(uint256 newMaxSupplyPhaseOne)
        external
        onlyOwner
    {
        maxSupplyPhaseOne = newMaxSupplyPhaseOne;
        emit setMaxSupplyPhaseOneEvent(newMaxSupplyPhaseOne);
    }

    /**
     * @notice Change the limit of tokens per wallet in phase one sale.
     *
     * @param newLimit. The new max supply.
     */
    function setLimit(uint256 newLimit) external onlyOwner {
        limit = newLimit;
        emit setLimitEvent(newLimit);
    }

    /**
     * @notice Change the price of tokens that are for sale in phase one.
     *
     * @param newPricePhaseOne. The new price.
     */
    function setPricePhaseOne(uint256 newPricePhaseOne) external onlyOwner {
        phaseOnePrice = newPricePhaseOne;
        emit setPricePhaseOneEvent(newPricePhaseOne);
    }

    /**
     * @notice Change the price of tokens that are for sale in phase two.
     *
     * @param newPricePhaseTwo. The new price.
     */
    function setPricePhaseTwo(uint256 newPricePhaseTwo) external onlyOwner {
        phaseTwoPrice = newPricePhaseTwo;
        emit setPricePhaseTwoEvent(newPricePhaseTwo);
    }

    /**
     * @notice Change the price of tokens that are for sale in phase three.
     *
     * @param newPricePhaseThree. The new price.
     */
    function setPricePhaseThree(uint256 newPricePhaseThree) external onlyOwner {
        phaseThreePrice = newPricePhaseThree;
        emit setPricePhaseThreeEvent(newPricePhaseThree);
    }

    /**
     * @notice Change the phase one merkle root.
     *
     * @param newRoot. The new merkleRootPhaseOne.
     */
    function setMerkleRootPhaseOne(bytes32 newRoot) external onlyOwner {
        merkleRootPhaseOne = newRoot;
        emit setMerkleRootPhaseOneEvent(newRoot);
    }

    /**
     * @notice Change the phase two merkle root.
     *
     * @param newRoot. The new merkleRootPhaseTwo.
     */
    function setMerkleRootPhaseTwo(bytes32 newRoot) external onlyOwner {
        merkleRootPhaseTwo = newRoot;
        emit setMerkleRootPhaseTwoEvent(newRoot);
    }

    /**
     * @notice Change start time of the phase one sale.
     *
     * @param newTime. The new time.
     */
    function setPhaseOneStartTime(uint256 newTime) external onlyOwner {
        phaseOneStartTime = newTime;
        emit setPhaseOneStartTimeEvent(newTime);
    }

    /**
     * @notice Change duration of the phase one sale.
     *
     * @param newDuration. The new duration.
     */
    function setPhaseOneDuration(uint256 newDuration) external onlyOwner {
        phaseOneDuration = newDuration;
        emit setPhaseOneDurationEvent(newDuration);
    }

    /**
     * @notice Change start time of the phase two sale.
     *
     * @param newTime. The new time.
     */
    function setPhaseTwoStartTime(uint256 newTime) external onlyOwner {
        phaseTwoStartTime = newTime;
        emit setPhaseTwoStartTimeEvent(newTime);
    }

    /**
     * @notice Change duration of the phase two sale.
     *
     * @param newDuration. The new duration.
     */
    function setPhaseTwoDuration(uint256 newDuration) external onlyOwner {
        phaseTwoDuration = newDuration;
        emit setPhaseTwoDurationEvent(newDuration);
    }

    /**
     * @notice Change start time of the phase three sale.
     *
     * @param newTime. The new time.
     */
    function setPhaseThreeStartTime(uint256 newTime) external onlyOwner {
        phaseThreeStartTime = newTime;
        emit setPhaseThreeStartTimeEvent(newTime);
    }

    /**
     * @dev FINANCE
     */

    /**
     * @notice Allows owner to withdraw funds generated from sale.
     */
    function withdrawAll() external onlyOwner {
        address _to = msg.sender;
        uint256 contractBalance = address(this).balance;

        require(contractBalance > 0, "NO ETHER TO WITHDRAW");

        payable(_to).transfer(contractBalance);
        emit WithdrawAllEvent(_to, contractBalance);
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    /**
     * @dev Fallback function for receiving Ether
     */
    receive() external payable {
        emit ReceivedEther(msg.sender, msg.value);
    }
}
