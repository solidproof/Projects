// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Pausable} from "@openzeppelin/contracts/security/Pausable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {MerkleProof} from "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title TradingRewardsDistributor
 * @notice It distributes HLM tokens with rolling Merkle airdrops.
 */
contract TradingRewardsDistributor is Pausable, ReentrancyGuard, Ownable {
    using SafeERC20 for IERC20;

    uint256 public constant BUFFER_ADMIN_WITHDRAW = 3 days;

    IERC20 public immutable helixmetaToken;

    // Current reward round (users can only claim pending rewards for the current round)
    uint256 public currentRewardRound;

    // Last paused timestamp
    uint256 public lastPausedTimestamp;

    // Max amount per user in current tree
    uint256 public maximumAmountPerUserInCurrentTree;

    // Total amount claimed by user (in HLM)
    mapping(address => uint256) public amountClaimedByUser;

    // Merkle root for a reward round
    mapping(uint256 => bytes32) public merkleRootOfRewardRound;

    // Checks whether a merkle root was used
    mapping(bytes32 => bool) public merkleRootUsed;

    // Keeps track on whether user has claimed at a given reward round
    mapping(uint256 => mapping(address => bool)) public hasUserClaimedForRewardRound;

    event RewardsClaim(address indexed user, uint256 indexed rewardRound, uint256 amount);
    event UpdateTradingRewards(uint256 indexed rewardRound);
    event TokenWithdrawnOwner(uint256 amount);

    /**
     * @notice Constructor
     * @param _helixmetaToken address of the helixmetaToken 
     */
    constructor(address _helixmetaToken) {
        helixmetaToken = IERC20(_helixmetaToken);
        // _pause();
    }

    /**
     * @notice Claim pending rewards
     * @param amount amount to claim
     * @param merkleProof array containing the merkle proof
     */
    function claim(uint256 amount, bytes32[] calldata merkleProof) external whenNotPaused nonReentrant {
        // Verify the reward round is not claimed already
        require(!hasUserClaimedForRewardRound[currentRewardRound][msg.sender], "Rewards: Already claimed");

        (bool claimStatus, uint256 adjustedAmount) = _canClaim(msg.sender, amount, merkleProof);

        require(claimStatus, "Rewards: Invalid proof");
        require(maximumAmountPerUserInCurrentTree >= amount, "Rewards: Amount higher than max");

        // Set mapping for user and round as true
        hasUserClaimedForRewardRound[currentRewardRound][msg.sender] = true;

        // Adjust amount claimed
        amountClaimedByUser[msg.sender] += adjustedAmount;

        // Transfer adjusted amount
        helixmetaToken.safeTransfer(msg.sender, adjustedAmount);

        emit RewardsClaim(msg.sender, currentRewardRound, adjustedAmount);
    }

    /**
     * @notice Update trading rewards with a new merkle root
     * @dev It automatically increments the currentRewardRound
     * @param merkleRoot root of the computed merkle tree
     */
    function updateTradingRewards(bytes32 merkleRoot, uint256 newMaximumAmountPerUser) external onlyOwner {
        require(!merkleRootUsed[merkleRoot], "Owner: Merkle root already used");

        currentRewardRound++;
        merkleRootOfRewardRound[currentRewardRound] = merkleRoot;
        merkleRootUsed[merkleRoot] = true;
        maximumAmountPerUserInCurrentTree = newMaximumAmountPerUser;

        emit UpdateTradingRewards(currentRewardRound);
    }

    /**
     * @notice Pause distribution
     */
    function pauseDistribution() external onlyOwner whenNotPaused {
        lastPausedTimestamp = block.timestamp;
        _pause();
    }

    /**
     * @notice Unpause distribution
     */
    function unpauseDistribution() external onlyOwner whenPaused {
        _unpause();
    }

    /**
     * @notice Transfer HLM tokens back to owner
     * @dev It is for emergency purposes
     * @param amount amount to withdraw
     */
    function withdrawTokenRewards(uint256 amount) external onlyOwner whenPaused {
        require(block.timestamp > (lastPausedTimestamp + BUFFER_ADMIN_WITHDRAW), "Owner: Too early to withdraw");
        helixmetaToken.safeTransfer(msg.sender, amount);

        emit TokenWithdrawnOwner(amount);
    }

    /**
     * @notice Check whether it is possible to claim and how much based on previous distribution
     * @param user address of the user
     * @param amount amount to claim
     * @param merkleProof array with the merkle proof
     */
    function canClaim(
        address user,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) external view returns (bool, uint256) {
        return _canClaim(user, amount, merkleProof);
    }

    /**
     * @notice Check whether it is possible to claim and how much based on previous distribution
     * @param user address of the user
     * @param amount amount to claim
     * @param merkleProof array with the merkle proof
     */
    function _canClaim(
        address user,
        uint256 amount,
        bytes32[] calldata merkleProof
    ) internal view returns (bool, uint256) {
        // Compute the node and verify the merkle proof
        bytes32 node = keccak256(abi.encodePacked(user, amount));
        bool canUserClaim = MerkleProof.verify(merkleProof, merkleRootOfRewardRound[currentRewardRound], node);

        if ((!canUserClaim) || (hasUserClaimedForRewardRound[currentRewardRound][user])) {
            return (false, 0);
        } else {
            return (true, amount - amountClaimedByUser[user]);
        }
    }
}