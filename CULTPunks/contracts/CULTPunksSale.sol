// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import {MerkleProofUpgradeable} from "@openzeppelin/contracts-upgradeable/utils/cryptography/MerkleProofUpgradeable.sol";

/**
 * @notice Represents CULTPunks Smart Contract
 */
contract ICULTPunks {
    function ownerOf(uint256 tokenId) public view virtual returns (address) {}
    function mintTokens(uint256 amount, address _to) external {}
}

contract CULTPunksSale is
    Initializable,
    PausableUpgradeable,
    OwnableUpgradeable,
    AccessControlUpgradeable
{
    ICULTPunks public cultPunksNFT;

    /**
     * @dev MINT DATA
     */
    uint256 public maxSupply;
    uint256 public bought;

    uint256 public wlSaleStartTime;
    uint256 public wlSaleDuration;
    uint256 public publicSaleStartTime;
    uint256 public publicSaleDuration;

    uint256 public wlSalePrice;
    uint256 public publicSalePrice;
    uint256 public publicMaxMintLimit;
    uint256 public wlPerSpotMint;

    bool public isWLMintingFree;
    bool public isPublicMintingFree;

    mapping(address => uint256) public addressToMintsWLSpot;
    mapping(address => uint256) public addressToMintsPublicSale;
    mapping(address => uint256) public addressToMintsWLNFT;
    mapping(address => uint256) public addressToMintsPublicNFT;
    mapping(address => bool) public blacklistUsers;

    bytes32 public merkleRootSpotOne;
    bytes32 public merkleRootSpotTwo;

    /**
     * @dev Events
     */
    event ReceivedEther(address indexed sender, uint256 indexed amount);
    event Purchase(
        address indexed buyer,
        uint256 indexed amount,
        bool indexed permissioned
    );

    event setMaxSupplyEvent(uint256 indexed maxSupply);
    event setPricewlSaleEvent(uint256 indexed price);
    event setPricepublicSaleEvent(uint256 indexed price);
    event setIsPublicMintingFreeEvent(bool status);
    event setIsWLMintingFreeEvent(bool status);
    event setWlPerSpotMintLimitEvent(uint256 indexed wlSpotMintLimit);
    event setmerkleRootSpotOneEvent(bytes32 indexed merkleRoot);
    event setmerkleRootSpotTwoEvent(bytes32 indexed merkleRoot);
    event setwlSaleStartTimeEvent(uint256 indexed time);
    event setwlSaleDurationEvent(uint256 indexed time);
    event setpublicSaleStartTimeEvent(uint256 indexed time);
    event setpublicSaleDurationEvent(uint256 indexed time);
    event setPublicSaleMaxMintLimitEvent(uint256 indexed amount);
    event WithdrawAllEvent(address indexed to, uint256 amount);

    function initialize(
        ICULTPunks _cultPunksNFT,
        uint256 _wlPerSpotMint,
        uint256 _wlSaleStartTime,
        uint256 _wlSaleDuration,
        uint256 _publicSaleStartTime,
        uint256 _publicSaleDuration,
        uint256 _publicMaxMintLimit
    ) public initializer {
        OwnableUpgradeable.__Ownable_init();
        wlPerSpotMint = _wlPerSpotMint;
        maxSupply = 10000;

        wlSaleStartTime = _wlSaleStartTime;
        wlSaleDuration = _wlSaleDuration;
        publicSaleStartTime = _publicSaleStartTime;
        publicSaleDuration = _publicSaleDuration;
        publicMaxMintLimit = _publicMaxMintLimit;

        wlSalePrice = 0.0666 ether;
        publicSalePrice = 0.08 ether;

        cultPunksNFT = _cultPunksNFT;
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
     * @param proofWL1. The proof used to validate if user is whitelisted or not.
     */
    function validatePhaseSpecificPurchase(
        uint256 amount,
        uint256 phase,
        bytes32[] calldata proofWL1,
        bytes32[] calldata proofWL2
    ) internal {
        /// @dev Verifies Merkle Proof submitted by user.
        /// @dev All mint data is embedded in the merkle proof.

        bytes32 leaf = keccak256(abi.encodePacked(msg.sender));
        if (phase == 1) {
            require(
                block.timestamp >= wlSaleStartTime,
                "PHASE ONE SALE HASN'T STARTED YET"
            );
            require(
                block.timestamp < wlSaleStartTime + wlSaleDuration,
                "PHASE ONE SALE IS CLOSED"
            );
            if(!isWLMintingFree) {
                require(
                    msg.value >= wlSalePrice * amount,
                    "ETHER SENT NOT CORRECT"
                );
            }
            
            require(merkleRootSpotOne != "" && merkleRootSpotTwo != "", "PERMISSIONED SALE CLOSED");
            
            if(MerkleProofUpgradeable.verify(proofWL1, merkleRootSpotOne, leaf) == true && MerkleProofUpgradeable.verify(proofWL2, merkleRootSpotTwo, leaf) == true)
            {   
                if(addressToMintsWLNFT[msg.sender] > 0) {
                    require((addressToMintsWLSpot[msg.sender] + amount) <= addressToMintsWLNFT[msg.sender], "BUY AMOUNT EXCEEDS MAX FOR USER WL");
                } else {
                    require((addressToMintsWLSpot[msg.sender] + amount) <= (wlPerSpotMint * 2), "BUY AMOUNT EXCEEDS MAX FOR USER");
                }
                addressToMintsWLSpot[msg.sender] = addressToMintsWLSpot[msg.sender] + amount;
            } else if(MerkleProofUpgradeable.verify(proofWL1, merkleRootSpotOne, leaf) == true) {
                if(addressToMintsWLNFT[msg.sender] > 0) {
                    require((addressToMintsWLSpot[msg.sender] + amount) <= addressToMintsWLNFT[msg.sender], "BUY AMOUNT EXCEEDS MAX FOR USER WL");
                } else {
                    require((addressToMintsWLSpot[msg.sender] + amount) <= wlPerSpotMint, "BUY AMOUNT EXCEEDS MAX FOR USER");
                }
                addressToMintsWLSpot[msg.sender] = addressToMintsWLSpot[msg.sender] + amount;
            } else if(MerkleProofUpgradeable.verify(proofWL2, merkleRootSpotTwo, leaf) == true) {
                if(addressToMintsWLNFT[msg.sender] > 0) {
                    require((addressToMintsWLSpot[msg.sender] + amount) <= addressToMintsWLNFT[msg.sender], "BUY AMOUNT EXCEEDS MAX FOR USER WL");
                } else {
                    require((addressToMintsWLSpot[msg.sender] + amount) <= wlPerSpotMint, "BUY AMOUNT EXCEEDS MAX FOR USER");
                }
                addressToMintsWLSpot[msg.sender] = addressToMintsWLSpot[msg.sender] + amount;
            } else {
                revert("INVALID PROOF");
            }
        } else if (phase == 2) {
            require(
                block.timestamp >= publicSaleStartTime,
                "PHASE TWO SALE HASN'T STARTED YET"
            );
            require(
                block.timestamp < publicSaleStartTime + publicSaleDuration,
                "PHASE TWO SALE IS CLOSED"
            );
            if(!isPublicMintingFree) {
                require(
                    msg.value >= publicSalePrice * amount,
                    "ETHER SENT NOT CORRECT"
                );
            }
            if(addressToMintsPublicNFT[msg.sender] > 0) {
                require((addressToMintsPublicSale[msg.sender] + amount) <= addressToMintsPublicNFT[msg.sender], "BUY AMOUNT EXCEEDS MAX FOR USER Public");
            } else {
                require(
                    addressToMintsPublicSale[msg.sender] + amount <= publicMaxMintLimit,
                    "BUY AMOUNT EXCEEDS MAX FOR USER"
                );
            }
            addressToMintsPublicSale[msg.sender] = addressToMintsPublicSale[msg.sender] + amount;
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
     * @param proofWL1. The Merkle Proof of the user.
     */
    function buy(
        uint256 amount,
        uint256 phase,
        bytes32[] calldata proofWL1,
        bytes32[] calldata proofWL2
    ) external payable {
        /// @dev Verify that user can perform permissioned sale based on the provided parameters.

        require(blacklistUsers[msg.sender] != true, "Not allowed to mint nfts");
        require(
            address(cultPunksNFT) != address(0),
            "NFT SMART CONTRACT NOT SET"
        );
        require(phase > 0 && phase < 3, "INCORRECT PHASE SUPPLIED");

        require(amount > 0, "HAVE TO BUY AT LEAST 1");
        require(
            bought + amount <= maxSupply,
            "BUY AMOUNT GOES OVER MAX SUPPLY"
        );

        /// @dev verify that user can perform permissioned sale based on phase of user
        validatePhaseSpecificPurchase(amount, phase, proofWL1, proofWL2);
        bought += amount;

        cultPunksNFT.mintTokens(amount, msg.sender);
        emit Purchase(msg.sender, amount, true);
    }

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
     * @notice Change the price of tokens that are for sale in phase one.
     *
     * @param newPricewlSale. The new price.
     */
    function setPricewlSale(uint256 newPricewlSale) external onlyOwner {
        wlSalePrice = newPricewlSale;
        emit setPricewlSaleEvent(newPricewlSale);
    }

    /**
     * @notice Change the price of tokens that are for sale in phase two.
     *
     * @param newPricepublicSale. The new price.
     */
    function setPricepublicSale(uint256 newPricepublicSale) external onlyOwner {
        publicSalePrice = newPricepublicSale;
        emit setPricepublicSaleEvent(newPricepublicSale);
    }

    function setPublicSaleMaxMintLimit(uint256 _newMintLimit) external onlyOwner {
        publicMaxMintLimit = _newMintLimit;
        emit setPublicSaleMaxMintLimitEvent(_newMintLimit);
    }

    function setWlPerSpotMint(uint256 _newMintSpotLimit) external onlyOwner {
        wlPerSpotMint = _newMintSpotLimit;
        emit setWlPerSpotMintLimitEvent(_newMintSpotLimit);
    }

    function setIsWLMintingFree(bool _status) external onlyOwner {
        isWLMintingFree = _status;
        emit setIsWLMintingFreeEvent(_status);
    }

    function setIsPublicMintingFree(bool _status) external onlyOwner {
        isPublicMintingFree = _status;
        emit setIsPublicMintingFreeEvent(_status);
    }

    function updateAddressToMintsWLNFT(address _user, uint256 _amount) external onlyOwner {
        addressToMintsWLNFT[_user] = _amount;
    }

    function updateAddressToMintsPublicNFT(address _user, uint256 _amount) external onlyOwner {
        addressToMintsPublicNFT[_user] = _amount;
    }

    function updateBlacklistUser(address _user, bool _status) external onlyOwner {
        blacklistUsers[_user] = _status;
    }

    /**
     * @notice Change the phase one merkle root.
     *
     * @param newRoot. The new merkleRootSpotOne.
     */
    function setmerkleRootSpotOne(bytes32 newRoot) external onlyOwner {
        merkleRootSpotOne = newRoot;
        emit setmerkleRootSpotOneEvent(newRoot);
    }

    /**
     * @notice Change the phase two merkle root.
     *execute
     * @param newRoot. The new merkleRootSpotTwo.
     */
    function setmerkleRootSpotTwo(bytes32 newRoot) external onlyOwner {
        merkleRootSpotTwo = newRoot;
        emit setmerkleRootSpotTwoEvent(newRoot);
    }

    /**
     * @notice Change start time of the phase one sale.
     *
     * @param newTime. The new time.
     */
    function setwlSaleStartTime(uint256 newTime) external onlyOwner {
        wlSaleStartTime = newTime;
        emit setwlSaleStartTimeEvent(newTime);
    }

    /**
     * @notice Change duration of the phase one sale.
     *
     * @param newDuration. The new duration.
     */
    function setwlSaleDuration(uint256 newDuration) external onlyOwner {
        wlSaleDuration = newDuration;
        emit setwlSaleDurationEvent(newDuration);
    }

    /**
     * @notice Change start time of the phase two sale.
     *
     * @param newTime. The new time.
     */
    function setpublicSaleStartTime(uint256 newTime) external onlyOwner {
        publicSaleStartTime = newTime;
        emit setpublicSaleStartTimeEvent(newTime);
    }

    /**
     * @notice Change duration of the phase two sale.
     *
     * @param newDuration. The new duration.
     */
    function setpublicSaleDuration(uint256 newDuration) external onlyOwner {
        publicSaleDuration = newDuration;
        emit setpublicSaleDurationEvent(newDuration);
    }

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

    /**
     * @dev Fallback function for receiving Ether
     */
    receive() external payable {
        emit ReceivedEther(msg.sender, msg.value);
    }
}
