// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {EnumerableSet} from "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";

import {FeeSharingSystem} from "./FeeSharingSystem.sol";
import {TokenDistributor} from "./TokenDistributor.sol";

import {IRewardConvertor} from "../interfaces/IRewardConvertor.sol";

/**
 * @title FeeSharingSetter
 * @notice It receives Helixmeta protocol fees and owns the FeeSharingSystem contract.
 * It can plug to AMMs for converting all received currencies to WETH.
 */
contract FeeSharingSetter is ReentrancyGuard, AccessControl {
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;

    // Operator role
    bytes32 public constant OPERATOR_ROLE = keccak256("OPERATOR_ROLE");

    // Min duration for each fee-sharing period (in blocks)
    uint256 public immutable MIN_REWARD_DURATION_IN_BLOCKS;

    // Max duration for each fee-sharing period (in blocks)
    uint256 public immutable MAX_REWARD_DURATION_IN_BLOCKS;

    IERC20 public immutable helixmetaToken;

    IERC20 public immutable rewardToken;

    FeeSharingSystem public feeSharingSystem;

    TokenDistributor public immutable tokenDistributor;

    // Reward convertor (tool to convert other currencies to rewardToken)
    IRewardConvertor public rewardConvertor;

    // Last reward block of distribution
    uint256 public lastRewardDistributionBlock;

    // Next reward duration in blocks
    uint256 public nextRewardDurationInBlocks;

    // Reward duration in blocks
    uint256 public rewardDurationInBlocks;

    uint256 public percentForFeeStaking;

    struct FeeSharingSystemShare {
        // Set of addresses that are staking only the fee sharing
        address _feeStakingAddresses;
        uint256 share;
    }

    FeeSharingSystemShare[] private _feeStakingInfo;

    event ConversionToRewardToken(
        address indexed token,
        uint256 amountConverted,
        uint256 amountReceived
    );
    event FeeStakingAddressesAdded(
        address[] feeStakingAddresses,
        uint256[] share
    );
    event FeeStakingAddressesRemoved(address[] feeStakingAddresses);
    event NewFeeSharingSystemOwner(address newOwner);
    event NewRewardDurationInBlocks(uint256 rewardDurationInBlocks);
    event NewRewardConvertor(address rewardConvertor);

    /**
     * @notice Constructor
     * @param _feeSharingSystem address of the fee sharing system
     * @param _minRewardDurationInBlocks minimum reward duration in blocks
     * @param _maxRewardDurationInBlocks maximum reward duration in blocks
     * @param _rewardDurationInBlocks reward duration between two updates in blocks
     * @param _percentForFeeStaking reward duration between two updates in blocks
     */
    constructor(
        address _feeSharingSystem,
        uint256 _minRewardDurationInBlocks,
        uint256 _maxRewardDurationInBlocks,
        uint256 _rewardDurationInBlocks,
        uint256 _percentForFeeStaking
    ) {
        require(_percentForFeeStaking < 100, "can not greater than 100");
        require(
            (_rewardDurationInBlocks <= _maxRewardDurationInBlocks) &&
                (_rewardDurationInBlocks >= _minRewardDurationInBlocks),
            "Owner: Reward duration in blocks outside of range"
        );

        MIN_REWARD_DURATION_IN_BLOCKS = _minRewardDurationInBlocks;
        MAX_REWARD_DURATION_IN_BLOCKS = _maxRewardDurationInBlocks;

        feeSharingSystem = FeeSharingSystem(_feeSharingSystem);

        rewardToken = feeSharingSystem.rewardToken();
        helixmetaToken = feeSharingSystem.helixmetaToken();
        tokenDistributor = feeSharingSystem.tokenDistributor();

        rewardDurationInBlocks = _rewardDurationInBlocks;
        nextRewardDurationInBlocks = _rewardDurationInBlocks;

        percentForFeeStaking = _percentForFeeStaking;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
    }

    /**
     * @notice Update the reward per block (in rewardToken)
     * @dev It automatically retrieves the number of pending WETH and adjusts
     * based on the balance of HLM in fee-staking addresses that exist in the set.
     */
    function updateRewards() external onlyRole(OPERATOR_ROLE) {
        if (lastRewardDistributionBlock > 0) {
            require(
                block.number >
                    (rewardDurationInBlocks + lastRewardDistributionBlock),
                "Reward: Too early to add"
            );
        }

        // Adjust for this period
        if (rewardDurationInBlocks != nextRewardDurationInBlocks) {
            rewardDurationInBlocks = nextRewardDurationInBlocks;
        }

        lastRewardDistributionBlock = block.number;

        // Calculate the reward to distribute as the balance held by this address
        uint256 reward = rewardToken.balanceOf(address(this));

        require(reward != 0, "Reward: Nothing to distribute");

        // Check if there is any address eligible for fee-sharing only
        uint256 numberAddressesForFeeStaking = _feeStakingInfo.length;

        // If there are eligible addresses for fee-sharing only, calculate their shares
        if (numberAddressesForFeeStaking > 0) {
            for (uint256 i = 0; i < numberAddressesForFeeStaking; i++) {
                uint256 amountToTransfer = (_feeStakingInfo[i].share * reward) /
                    100;
                if (amountToTransfer > 0) {
                    // adjustedReward -= amountToTransfer;
                    rewardToken.safeTransfer(
                        _feeStakingInfo[i]._feeStakingAddresses,
                        amountToTransfer
                    );
                }
            }
        }

        // Transfer tokens to fee sharing system
        rewardToken.safeTransfer(
            address(feeSharingSystem),
            ((100 - percentForFeeStaking) * reward) / 100
        );

        // Update rewards
        feeSharingSystem.updateRewards(
            ((100 - percentForFeeStaking) * reward) / 100,
            rewardDurationInBlocks
        );
    }

    /**
     * @notice Convert currencies to reward token
     * @dev Function only usable only for whitelisted currencies (where no potential side effect)
     * @param token address of the token to sell
     * @param additionalData additional data (e.g., slippage)
     */
    function convertCurrencyToRewardToken(
        address token,
        bytes calldata additionalData
    ) external nonReentrant onlyRole(OPERATOR_ROLE) {
        require(
            address(rewardConvertor) != address(0),
            "Convert: RewardConvertor not set"
        );
        require(
            token != address(rewardToken),
            "Convert: Cannot be reward token"
        );

        uint256 amountToConvert = IERC20(token).balanceOf(address(this));
        require(amountToConvert != 0, "Convert: Amount to convert must be > 0");

        // Adjust allowance for this transaction only
        IERC20(token).safeIncreaseAllowance(
            address(rewardConvertor),
            amountToConvert
        );

        // Exchange token to reward token
        uint256 amountReceived = rewardConvertor.convert(
            token,
            address(rewardToken),
            amountToConvert,
            additionalData
        );

        emit ConversionToRewardToken(token, amountToConvert, amountReceived);
    }

    /**
     * @notice Add staking addresses
     * @param _stakingAddresses array of addresses eligible for fee-sharing only
     * @param _share array of percentage eligible for fee-sharing only

     */
    function updateFeeStakingAddresses(
        address[] memory _stakingAddresses,
        uint256[] memory _share
    ) external onlyRole(DEFAULT_ADMIN_ROLE) {
        require(_stakingAddresses.length == _share.length, "Have to map");
        uint256 totalShare = 0;
        delete _feeStakingInfo;
        for (uint256 i = 0; i < _stakingAddresses.length; i++) {
            _feeStakingInfo.push(
                FeeSharingSystemShare(_stakingAddresses[i], _share[i])
            );
            totalShare += _share[i];
        }
        require(totalShare == percentForFeeStaking, "Can not divide");
        emit FeeStakingAddressesAdded(_stakingAddresses, _share);
    }

    /**
     * @notice Set new reward duration in blocks for next update
     * @param _newRewardDurationInBlocks number of blocks for new reward period
     */
    function setNewRewardDurationInBlocks(uint256 _newRewardDurationInBlocks)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            (_newRewardDurationInBlocks <= MAX_REWARD_DURATION_IN_BLOCKS) &&
                (_newRewardDurationInBlocks >= MIN_REWARD_DURATION_IN_BLOCKS),
            "Owner: New reward duration in blocks outside of range"
        );

        nextRewardDurationInBlocks = _newRewardDurationInBlocks;

        emit NewRewardDurationInBlocks(_newRewardDurationInBlocks);
    }

    /**
     * @notice Set reward convertor contract
     * @param _rewardConvertor address of the reward convertor (set to null to deactivate)
     */
    function setRewardConvertor(address _rewardConvertor)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        rewardConvertor = IRewardConvertor(_rewardConvertor);

        emit NewRewardConvertor(_rewardConvertor);
    }

    /**
     * @notice Transfer ownership of fee sharing system
     * @param _newOwner address of the new owner
     */
    function transferOwnershipOfFeeSharingSystem(address _newOwner)
        external
        onlyRole(DEFAULT_ADMIN_ROLE)
    {
        require(
            _newOwner != address(0),
            "Owner: New owner cannot be null address"
        );
        feeSharingSystem.transferOwnership(_newOwner);

        emit NewFeeSharingSystemOwner(_newOwner);
    }

    /**
     * @notice See addresses eligible for fee-staking
     */
    function viewFeeStakingAddresses()
        external
        view
        returns (FeeSharingSystemShare[] memory)
    {
        uint256 length = _feeStakingInfo.length;

        FeeSharingSystemShare[]
            memory feeStakingAddresses = new FeeSharingSystemShare[](length);

        for (uint256 i = 0; i < length; i++) {
            feeStakingAddresses[i] = _feeStakingInfo[i];
        }

        return (feeStakingAddresses);
    }
}
