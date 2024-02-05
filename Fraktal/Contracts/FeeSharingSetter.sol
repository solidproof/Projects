// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20Upgradeable, SafeERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {FeeSharingSystem} from "./FeeSharingSystem.sol";

import {IRewardConvertor} from "./IRewardConvertor.sol";

contract FeeSharingSetter is ReentrancyGuard, AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    // Operator role
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // Min duration for each fee-sharing period (in blocks)
    uint256 public immutable MIN_REWARD_DURATION_IN_BLOCKS;

    // Max duration for each fee-sharing period (in blocks)
    uint256 public immutable MAX_REWARD_DURATION_IN_BLOCKS;

    IERC20Upgradeable public immutable frakToken;

    // IERC20Upgradeable public immutable rewardToken;

    FeeSharingSystem public feeSharingSystem;

    // Reward convertor (tool to convert other currencies to rewardToken)
    IRewardConvertor public rewardConvertor;

    // Last reward block of distribution
    uint256 public lastRewardDistributionBlock;

    // Next reward duration in blocks
    uint256 public nextRewardDurationInBlocks;

    // Reward duration in blocks
    uint256 public rewardDurationInBlocks;

    // Set of addresses that are staking only the fee sharing
    EnumerableSet.AddressSet private _feeStakingAddresses;

    event ConversionToRewardToken(address indexed token, uint256 amountConverted, uint256 amountReceived);
    event FeeStakingAddressesAdded(address[] feeStakingAddresses);
    event FeeStakingAddressesRemoved(address[] feeStakingAddresses);
    event NewFeeSharingSystemOwner(address newOwner);
    event NewRewardDurationInBlocks(uint256 rewardDurationInBlocks);
    event NewRewardConvertor(address rewardConvertor);

    constructor(
        address payable _feeSharingSystem,
        uint256 _minRewardDurationInBlocks,
        uint256 _maxRewardDurationInBlocks,
        uint256 _rewardDurationInBlocks
    ) {
        require(
            (_rewardDurationInBlocks <= _maxRewardDurationInBlocks) &&
                (_rewardDurationInBlocks >= _minRewardDurationInBlocks),
            "Owner: Reward duration in blocks outside of range"
        );

        MIN_REWARD_DURATION_IN_BLOCKS = _minRewardDurationInBlocks;
        MAX_REWARD_DURATION_IN_BLOCKS = _maxRewardDurationInBlocks;

        feeSharingSystem = FeeSharingSystem(_feeSharingSystem);

        // rewardToken = feeSharingSystem.rewardToken();
        frakToken = feeSharingSystem.frakToken();

        rewardDurationInBlocks = _rewardDurationInBlocks;
        nextRewardDurationInBlocks = _rewardDurationInBlocks;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    function updateRewards() external onlyRole(OPERATOR_ROLE) {
        if (lastRewardDistributionBlock > 0) {
            require(block.number > (rewardDurationInBlocks + lastRewardDistributionBlock), "Reward: Too early to add");
        }

        // Adjust for this period
        if (rewardDurationInBlocks != nextRewardDurationInBlocks) {
            rewardDurationInBlocks = nextRewardDurationInBlocks;
        }

        lastRewardDistributionBlock = block.number;

        // Calculate the reward to distribute as the balance held by this address
        // uint256 reward = rewardToken.balanceOf(address(this));
        uint256 reward = address(this).balance;

        require(reward != 0, "Reward: Nothing to distribute");

        // Transfer tokens to fee sharing system
        // rewardToken.safeTransfer(address(feeSharingSystem), reward);
        (bool sent,) = address(feeSharingSystem).call{value: reward}("");
        require(sent, "Failed to send Ether");

        // Update rewards
        feeSharingSystem.updateRewards(reward, rewardDurationInBlocks);
    }

    function convertCurrencyToRewardToken(address token, bytes calldata additionalData)
        external
        nonReentrant
        onlyRole(OPERATOR_ROLE)
    {
        require(address(rewardConvertor) != address(0), "Convert: RewardConvertor not set");
        // require(token != address(rewardToken), "Convert: Cannot be reward token");

        uint256 amountToConvert = IERC20Upgradeable(token).balanceOf(address(this));
        require(amountToConvert != 0, "Convert: Amount to convert must be > 0");

        // Adjust allowance for this transaction only
        IERC20Upgradeable(token).safeIncreaseAllowance(address(rewardConvertor), amountToConvert);

        // Exchange token to reward token
        uint256 amountReceived = rewardConvertor.convert(token, amountToConvert, additionalData);

        emit ConversionToRewardToken(token, amountToConvert, amountReceived);
    }

    function addFeeStakingAddresses(address[] calldata _stakingAddresses) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < _stakingAddresses.length; i++) {
            require(!_feeStakingAddresses.contains(_stakingAddresses[i]), "Owner: Address already registered");
            _feeStakingAddresses.add(_stakingAddresses[i]);
        }

        emit FeeStakingAddressesAdded(_stakingAddresses);
    }

    function removeFeeStakingAddresses(address[] calldata _stakingAddresses) external onlyRole(DEFAULT_ADMIN_ROLE) {
        for (uint256 i = 0; i < _stakingAddresses.length; i++) {
            require(_feeStakingAddresses.contains(_stakingAddresses[i]), "Owner: Address not registered");
            _feeStakingAddresses.remove(_stakingAddresses[i]);
        }

        emit FeeStakingAddressesRemoved(_stakingAddresses);
    }

    function setNewRewardDurationInBlocks(uint256 _newRewardDurationInBlocks) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(
            (_newRewardDurationInBlocks <= MAX_REWARD_DURATION_IN_BLOCKS) &&
                (_newRewardDurationInBlocks >= MIN_REWARD_DURATION_IN_BLOCKS),
            "Owner: New reward duration in blocks outside of range"
        );

        nextRewardDurationInBlocks = _newRewardDurationInBlocks;

        emit NewRewardDurationInBlocks(_newRewardDurationInBlocks);
    }

    function setRewardConvertor(address _rewardConvertor) external onlyRole(DEFAULT_ADMIN_ROLE) {
        rewardConvertor = IRewardConvertor(_rewardConvertor);

        emit NewRewardConvertor(_rewardConvertor);
    }

    function transferOwnershipOfFeeSharingSystem(address _newOwner) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_newOwner != address(0), "Owner: New owner cannot be null address");
        feeSharingSystem.transferOwnership(_newOwner);

        emit NewFeeSharingSystemOwner(_newOwner);
    }

    function viewFeeStakingAddresses() external view returns (address[] memory) {
        uint256 length = _feeStakingAddresses.length();

        address[] memory feeStakingAddresses = new address[](length);

        for (uint256 i = 0; i < length; i++) {
            feeStakingAddresses[i] = _feeStakingAddresses.at(i);
        }

        return (feeStakingAddresses);
    }

    function retrieveERC20(address tokenAddress) external onlyRole(DEFAULT_ADMIN_ROLE){
        uint256 balance = IERC20Upgradeable(tokenAddress).balanceOf(address(this));
        IERC20Upgradeable(tokenAddress).transfer(msg.sender, balance);
    }

    receive() external payable{

    }
}