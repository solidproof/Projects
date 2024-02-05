// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./interfaces/IRewardDistributor.sol";
import "./EmergencyGuard.sol";

contract RewardDistributor is
    IRewardDistributor,
    Ownable,
    AccessControlEnumerable,
    ReentrancyGuard,
    EmergencyGuard
{
    // Role allowed to do admin operations.
    bytes32 public constant ADMIN = keccak256("ADMIN");

    // Role allowed to do processor operations like adding token to users.
    bytes32 public constant PROCESSOR = keccak256("PROCESSOR");

    // Role allowed to do slayer operations like slaying token.
    bytes32 public constant SLAYER = keccak256("SLAYER");

    // Duration after user token are allowed to be slayed.
    uint256 public constant SLAY_INACTIVE_DURATION = 200 * 24 * 60 * 60; // 200 days in seconds

    // Fee address
    address public constant FEE_ADDRESS =
        0xD70E8C40003AE32b8E82AB5F25607c010532f148;

    // Token instance used for payments
    IERC20 internal immutable _token;

    // Claimable token amount by user
    mapping(address => uint256) internal _claimableByUser;

    // Claimed token amount by user
    mapping(address => uint256) internal _claimedByUser;

    // Slayed token amount by user
    mapping(address => uint256) internal _slayedByUser;

    // Last claim timestamp by user
    mapping(address => uint256) internal _lastClaimedAtByUser;

    // Last slay timestamp by user
    mapping(address => uint256) internal _lastSlayedAtByUser;

    // Total amount of fees collected
    uint256 internal _totalFees;

    constructor(address tokenAddress) {
        // Add creator to admin role
        _setupRole(ADMIN, _msgSender());

        // Set role admin for roles
        _setRoleAdmin(ADMIN, ADMIN);
        _setRoleAdmin(PROCESSOR, ADMIN);
        _setRoleAdmin(SLAYER, ADMIN);

        // Initialize token instance
        _token = IERC20(tokenAddress);
    }

    function claimableToken(
        address user
    ) external view override returns (uint256 amount) {
        return _claimableByUser[user];
    }

    function claimedToken(
        address user
    ) external view override returns (uint256 amount) {
        return _claimedByUser[user];
    }

    function slayedToken(
        address user
    ) external view override returns (uint256 amount) {
        return _slayedByUser[user];
    }

    function lastClaimedAt(
        address user
    ) external view override returns (uint256 timestamp) {
        return _lastClaimedAtByUser[user];
    }

    function lastSlayedAt(
        address user
    ) external view override returns (uint256 timestamp) {
        return _lastSlayedAtByUser[user];
    }

    function totalFees() external view override returns (uint256 amount) {
        return _totalFees;
    }

    function addTokenForUsers(
        address[] memory users,
        uint256[] memory amounts
    ) external override onlyRole(PROCESSOR) {
        // Check if input data is valid
        require(
            users.length == amounts.length,
            "RewardDistributor: Count of users and amounts is mismatching"
        );

        for (uint256 i = 0; i < users.length; i++) {
            addTokenForUser(users[i], amounts[i]);
        }
    }

    function claimToken() external override nonReentrant {
        // Get claimable amount
        address user = _msgSender();
        uint256 amount = _claimableByUser[user];

        // Check amount
        require(
            amount > 0,
            "RewardDistributor: Cannot claim token if claimable amount is zero"
        );

        // Transfer 3% fee
        uint256 fees = (amount * 3) / 100;
        require(
            _token.transfer(FEE_ADDRESS, fees),
            "RewardDistributor: Token transfer failed"
        );

        _totalFees += fees;

        // Send token
        require(
            _token.transfer(user, amount - fees),
            "RewardDistributor: Token transfer failed"
        );

        // Update state
        _claimableByUser[user] -= amount;
        _claimedByUser[user] += amount;

        // Set last claim timestamp
        _lastClaimedAtByUser[user] = block.timestamp;

        // Emit event
        emit TokenClaimed(user, amount);
    }

    function slayTokenForUsers(
        address[] memory users
    ) external override onlyRole(SLAYER) {
        for (uint256 i = 0; i < users.length; i++) {
            slayTokenForUser(users[i]);
        }
    }

    function emergencyWithdraw(
        uint256 amount
    ) external override onlyRole(ADMIN) {
        super._emergencyWithdraw(amount);
    }

    function emergencyWithdrawToken(
        address tokenToWithdraw,
        uint256 amount
    ) external override onlyRole(ADMIN) {
        super._emergencyWithdrawToken(tokenToWithdraw, amount);
    }

    function addTokenForUser(
        address user,
        uint256 amount
    ) public override onlyRole(PROCESSOR) {
        _claimableByUser[user] += amount;

        // Emit event
        emit TokenAdded(user, amount);
    }

    function slayTokenForUser(address user) public override onlyRole(SLAYER) {
        // Get last claim timestamp
        uint256 lastClaimTimestamp = _lastClaimedAtByUser[user];
        require(
            block.timestamp > (lastClaimTimestamp + SLAY_INACTIVE_DURATION),
            "RewardDistributor: Cannot slay token of an active user"
        );

        // Get claimable token amount
        uint256 amount = _claimableByUser[user];
        require(
            amount > 0,
            "RewardDistributor: Cannot slay token if claimable amount is zero"
        );

        // Send token
        require(
            _token.transfer(FEE_ADDRESS, amount),
            "RewardDistributor: Token transfer failed"
        );

        // Update state
        _claimableByUser[user] -= amount;
        _slayedByUser[user] += amount;

        // Set last slay timestamp
        _lastSlayedAtByUser[user] = block.timestamp;

        // Emit event
        emit TokenSlayed(user, amount);
    }
}