// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";

import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {IERC721} from "@openzeppelin/contracts/token/ERC721/IERC721.sol";
import {IERC1155} from "@openzeppelin/contracts/token/ERC1155/IERC1155.sol";
import {FraktalMarket} from "./FraktalMarket.sol";

contract FraktalAirdrop is Pausable, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    //for referencing auction listing
    struct AuctionListing {
        address tokenAddress;
        uint256 reservePrice;
        uint256 numberOfShares;
        uint256 auctionEndTime;
    }

    IERC20 public immutable fraktalToken;
    uint256 public immutable MAXIMUM_AMOUNT_TO_CLAIM;

    bool public isMerkleRootSet;

    bytes32 public merkleRoot;

    uint256 public endTimestamp;

    uint256 public startTimestamp;

    mapping(address => bool) public hasClaimed;

    address public fraktalMarket;

    event AirdropRewardsClaim(address indexed user, uint256 amount);
    event MerkleRootSet(bytes32 merkleRoot);
    event NewEndTimestamp(uint256 endTimestamp);
    event TokensWithdrawn(uint256 amount);

    constructor(
        uint256 _startTimestamp,//1647518400
        uint256 _endTimestamp,//1648382400
        uint256 _maximumAmountToClaim,//10000*10**18
        address _fraktalToken,
        address _market,
        bytes32 _merkleRoot//0x8dfab5f1445c86bab8ddecc22981110b60bb14aa0e326226e3974785643a4e57
    ) {
        startTimestamp = _startTimestamp;
        endTimestamp = _endTimestamp;
        MAXIMUM_AMOUNT_TO_CLAIM = _maximumAmountToClaim;

        fraktalToken = IERC20(_fraktalToken);
        fraktalMarket = _market;
        merkleRoot = _merkleRoot;
        isMerkleRootSet = true;
    }

    function claim(
        uint256 amount,
        bytes32[] calldata merkleProof,
        address listedToken
    ) external whenNotPaused nonReentrant {
        require(isMerkleRootSet, "Airdrop: Merkle root not set");
        require(amount <= MAXIMUM_AMOUNT_TO_CLAIM, "Airdrop: Amount too high");
        require(block.timestamp >= startTimestamp, "Airdrop: Too early to claim");
        require(block.timestamp <= endTimestamp, "Airdrop: Too late to claim");

        // Verify the user has claimed
        require(!hasClaimed[msg.sender], "Airdrop: Already claimed");

        uint256 listedAmount = FraktalMarket(payable(fraktalMarket)).getListingAmount(msg.sender,listedToken);
        (,,uint256 listedAuctionAmount,) = FraktalMarket(payable(fraktalMarket)).auctionListings(listedToken,msg.sender,0);

        //check if any listing available
        bool isListed = listedAmount > 0 || listedAuctionAmount > 0;
        require(isListed,"No NFT listed");


        // Compute the node and verify the merkle proof
        bytes32 node = keccak256(abi.encodePacked(msg.sender, amount));
        require(MerkleProof.verify(merkleProof, merkleRoot, node), "Airdrop: Invalid proof");

        // Set as claimed
        hasClaimed[msg.sender] = true;

        // parse to Fraktal distribution
        amount = this.parseTier(amount);

        // Transfer tokens
        fraktalToken.safeTransfer(msg.sender, amount);

        emit AirdropRewardsClaim(msg.sender, amount);
    }

    function canClaim(
        address user,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external view returns (bool) {
        if (block.timestamp <= endTimestamp) {
            // Compute the node and verify the merkle proof
            bytes32 node = keccak256(abi.encodePacked(user, amount));
            return MerkleProof.verify(merkleProof, merkleRoot, node);
        } else {
            return false;
        }
    }

    function pauseAirdrop() external onlyOwner whenNotPaused {
        _pause();
    }

    function unpauseAirdrop() external onlyOwner whenPaused {
        _unpause();
    }

    function updateEndTimestamp(uint256 newEndTimestamp) external onlyOwner {
        require(block.timestamp + 30 days > newEndTimestamp, "Owner: New timestamp too far");
        endTimestamp = newEndTimestamp;

        emit NewEndTimestamp(newEndTimestamp);
    }

    function withdrawTokenRewards() external onlyOwner {
        require(block.timestamp > (endTimestamp + 1 days), "Owner: Too early to remove rewards");
        uint256 balanceToWithdraw = fraktalToken.balanceOf(address(this));
        fraktalToken.safeTransfer(msg.sender, balanceToWithdraw);

        emit TokensWithdrawn(balanceToWithdraw);
    }

    //refer https://docs.fraktal.io/fraktal-governance-token-frak/airdrop
    function parseTier(uint256 amount) public pure returns (uint256 parsed){
        if(amount == 10000 ether){
            return 7900 ether;
        }
        if(amount == 4540 ether){
            return 3160 ether;
        }
        if(amount == 2450 ether){
            return 2370 ether;
        }
        if(amount == 1500 ether){
            return 1580 ether;
        }
        if(amount == 1200 ether){
            return 790 ether;
        }
        if(amount == 800 ether){
            return 474 ether;
        }
        if(amount == 400 ether){
            return 316 ether;
        }
        if(amount == 200 ether){
            return 252 ether;
        }
        if(amount == 125 ether){
            return 126 ether;
        }
        return 0;
    }

    function setFraktalMarket(address _market) external{
        fraktalMarket = _market;
    }
}