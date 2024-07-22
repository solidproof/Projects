//  /$$$$$$$                            /$$$$$$$$ /$$
// | $$__  $$                          | $$_____/|__/
// | $$  \ $$  /$$$$$$  /$$   /$$      | $$       /$$ /$$$$$$$   /$$$$$$  /$$$$$$$   /$$$$$$$  /$$$$$$
// | $$$$$$$/ |____  $$| $$  | $$      | $$$$$   | $$| $$__  $$ |____  $$| $$__  $$ /$$_____/ /$$__  $$
// | $$__  $$  /$$$$$$$| $$  | $$      | $$__/   | $$| $$  \ $$  /$$$$$$$| $$  \ $$| $$      | $$$$$$$$
// | $$  \ $$ /$$__  $$| $$  | $$      | $$      | $$| $$  | $$ /$$__  $$| $$  | $$| $$      | $$_____/
// | $$  | $$|  $$$$$$$|  $$$$$$$      | $$      | $$| $$  | $$|  $$$$$$$| $$  | $$|  $$$$$$$|  $$$$$$$
// |__/  |__/ \_______/ \____  $$      |__/      |__/|__/  |__/ \_______/|__/  |__/ \_______/ \_______/
//                      /$$  | $$
//                     |  $$$$$$/
//                      \______/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {EnumerableMap} from "@openzeppelin/contracts/utils/structs/EnumerableMap.sol";
import {Checkpoints} from "@openzeppelin/contracts/utils/structs/Checkpoints.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

/**
 * @title RayFi
 * @author 0xC4LL3
 * @notice This contract is the core and the underlying token of the Ray Finance ecosystem
 * It is responsible for tracking staked RayFi tokens, distributing rewards and reinvesting them in vaults
 * @notice The primary purpose of the RayFi token is owning (or trading) shares of the Ray Finance protocol
 * Acquiring sufficient shares enables users to automagically earn rewards in the form of stablecoin airdrops
 * Users may stake their RayFi tokens in lockless vaults to have their rewards reinvested in RayFi or other tokens
 */
contract RayFi is ERC20, Ownable {
    //////////////
    // Types    //
    //////////////

    using EnumerableMap for EnumerableMap.AddressToUintMap;
    using Checkpoints for Checkpoints.Trace160;

    /**
     * @title The state of the distribution process
     * @dev The state of of the distribution is only tracked in stateful mode
     * @dev The purpose of this enum is to correctly resume unfinished distributions
     * @param Inactive There is no stateful distribution in progress
     * @param ProcessingVaults The distribution is processing vaults, which implies reinvestment already happened
     * @param ProcessingRewards The distribution is processing rewards, which implies vaults have been processed
     */
    enum DistributionState {
        Inactive,
        ProcessingVaults,
        ProcessingRewards
    }

    /**
     * @title The state of a staking vault
     * @dev The state of a vault is used in stateful distributions for the same purpose of the `DistributionState`
     * @param Ready The vault is ready to be processed
     * @param Processing The vault is being processed, meaning its distribution parameters should not be modified
     * @param ResetPending The vault has finished processing and is waiting to be reset after all vaults are done
     */
    enum VaultState {
        Ready,
        Processing,
        ResetPending
    }

    /**
     * @title A data structure cointaining all data for a staking vault
     * @param vaultId The id of the vault
     * @param magnifiedRewardPerShare The magnified reward per share for the vault
     * @param lastProcessedIndex The last index processed for the vault, tracked in stateful distributions
     * @param stakersSnapshots Snapshots of the stakers in the vault and their staked amounts
     * @param stakers The list of stakers in the vault and their staked amounts
     * @param totalVaultSharesSnapshots Snapshots of the total amount of RayFi staked in the vault
     * @param state The state of the vault, see `VaultState` documentation
     */
    struct Vault {
        uint256 vaultId;
        uint256 magnifiedRewardPerShare;
        uint256 lastProcessedIndex;
        mapping(address user => Checkpoints.Trace160 stakeSnapshot) stakersSnapshots;
        EnumerableMap.AddressToUintMap stakers;
        Checkpoints.Trace160 totalVaultSharesSnapshots;
        VaultState state;
    }

    /////////////////////
    // State Variables //
    /////////////////////

    uint128 private constant MAGNITUDE = type(uint128).max;
    uint128 private constant MAX_SUPPLY = 10_000_000 ether;
    uint128 private constant MAX_TOKEN_REQUIREMENT_FOR_REWARDS = 100_000 ether;
    uint8 private constant MAX_FEES = 10;

    uint256 private s_magnifiedRewardPerShare;
    uint256 private s_nextSnapshotIdToProcess;
    uint256 private s_lastProcessedIndex;
    uint160 private s_minimumTokenBalanceForRewards;
    uint96 private s_snapshotId;

    IUniswapV2Router02 private s_router;

    address private s_rewardToken;
    address private s_swapReceiver;
    address private s_feeReceiver;

    uint8 private s_buyFee;
    uint8 private s_sellFee;

    bool private s_areTradingFeesEnabled = true;

    mapping(address user => bool isExemptFromFees) private s_isFeeExempt;
    mapping(address user => bool isExcludedFromRewards) private s_isExcludedFromRewards;
    mapping(address pair => bool isAMMPair) private s_isAutomatedMarketMakerPairs;
    mapping(address user => uint256 amountStaked) private s_stakedBalances;
    mapping(address user => Checkpoints.Trace160 balanceSnapshot) private s_balancesSnapshots;
    mapping(address token => Vault vault) private s_vaults;

    address[] private s_vaultTokens;

    EnumerableMap.AddressToUintMap private s_shareholders;

    Checkpoints.Trace160 private s_totalRewardSharesSnapshots;
    Checkpoints.Trace160 private s_totalStakedSharesSnapshots;

    DistributionState private s_distributionState;

    ////////////////
    /// Events    //
    ////////////////

    /**
     * @notice Emitted when RayFi is staked
     * @param staker The address of the user that staked the RayFi
     * @param stakedAmount The amount of RayFi that was staked
     * @param totalStakedShares The total amount of RayFi staked in this contract
     */
    event RayFiStaked(address indexed staker, uint256 indexed stakedAmount, uint256 indexed totalStakedShares);

    /**
     * @notice Emitted when RayFi is unstaked
     * @param unstaker The address of the user that unstaked the RayFi
     * @param unstakedAmount The amount of RayFi that was unstaked
     * @param totalStakedShares The total amount of RayFi staked in this contract
     */
    event RayFiUnstaked(address indexed unstaker, uint256 indexed unstakedAmount, uint256 indexed totalStakedShares);

    /**
     * @notice Emitted when rewards are distributed
     * @param totalRewardsWithdrawn The amount of rewards that were airdropped to users
     * @param rewardToken The address of the token that was distributed as rewards
     */
    event RewardsDistributed(uint256 indexed totalRewardsWithdrawn, address indexed rewardToken);

    /**
     * @notice Emitted when rewards are reinvested
     * @param totalRewardsReinvested The amount of rewards that were reinvested in vaults
     * @param vaultToken The address of the vault token the rewards were reinvested into
     */
    event RewardsReinvested(uint256 indexed totalRewardsReinvested, address indexed vaultToken);

    /**
     * @notice Emitted when a snapshot is taken
     * @param snapshotId The id of the snapshot
     */
    event SnapshotTaken(uint96 indexed snapshotId);

    /**
     * @notice Emitted when trading fees are permanently removed using `removeTradingFees`
     */
    event TradingFeesRemoved();

    /**
     * @notice Emitted when the fee amounts for buys and sells are updated
     * @param buyFee The new buy fee
     * @param sellFee The new sell fee
     */
    event FeeAmountsUpdated(uint8 buyFee, uint8 sellFee);

    /**
     * @notice Emitted when a user is marked as exempt from fees
     * @param user The address of the user
     * @param isExempt Whether the user is exempt from fees
     */
    event IsUserExemptFromFeesUpdated(address indexed user, bool indexed isExempt);

    /**
     * @notice Emitted when the fee receiver is updated
     * @param newFeeReceiver The new fee receiver
     * @param oldFeeReceiver The old fee receiver
     */
    event FeeReceiverUpdated(address indexed newFeeReceiver, address indexed oldFeeReceiver);

    /**
     * @notice Emitted when the swap receiver is updated
     * @param newSwapReceiver The new swap receiver
     * @param oldSwapReceiver The old swap receiver
     */
    event SwapReceiverUpdated(address indexed newSwapReceiver, address indexed oldSwapReceiver);

    /**
     * @notice Emitted when the reward token is updated
     * @param newRewardToken The new reward token
     * @param oldRewardToken The old reward token
     */
    event RewardTokenUpdated(address indexed newRewardToken, address indexed oldRewardToken);

    /**
     * @notice Emitted when the router is updated
     * @param newRouter The new router
     * @param oldRouter The old router
     */
    event RouterUpdated(address indexed newRouter, address indexed oldRouter);

    /**
     * @notice Emitted when an automated market maker pair is updated
     * @param pair The address of the pair that was updated
     * @param active Whether the pair is an automated market maker pair
     */
    event AutomatedMarketPairUpdated(address indexed pair, bool indexed active);

    /**
     * @notice Emitted when the minimum token balance for rewards is updated
     * @param newMinimum The new minimum token balance for rewards
     * @param oldMinimum The previous minimum token balance for rewards
     */
    event MinimumTokenBalanceForRewardsUpdated(uint256 indexed newMinimum, uint256 indexed oldMinimum);

    /**
     * @notice Emitted when a user is marked as excluded from rewards
     * @param user The address of the user
     * @param isExcluded Whether the user is excluded from rewards
     */
    event IsUserExcludedFromRewardsUpdated(address indexed user, bool indexed isExcluded);

    //////////////////
    // Errors       //
    //////////////////

    /**
     * @notice Triggered when trying to send RayFi tokens to this contract
     * Users should call the `stake` function to stake their RayFi tokens
     * @dev Sending RayFi tokens to the contract is not allowed to prevent accidental staking
     * This also simplifies reward tracking and distribution logic
     */
    error RayFi__CannotManuallySendRayFiToTheContract();

    /**
     * @notice Indicates a failure in unstaking tokens due to the sender not having enough staked tokens
     * @param stakedAmount The amount of staked tokens the sender has
     * @param unstakeAmount The amount of tokens the sender is trying to unstake
     */
    error RayFi__InsufficientStakedBalance(uint256 stakedAmount, uint256 unstakeAmount);

    /**
     * @notice Indicates a failure in staking tokens due to not having enough tokens
     * @param minimumTokenBalance The minimum amount of tokens required to stake
     */
    error RayFi__InsufficientTokensToStake(uint256 minimumTokenBalance);

    /**
     * @dev Triggered when attempting to set the zero address as a contract parameter
     * Setting a contract parameter to the zero address can lead to unexpected behavior
     */
    error RayFi__CannotSetToZeroAddress();

    /**
     * @dev Triggered when trying to add a vault that already exists
     * @param vaultToken The address that was passed as input
     */
    error RayFi__VaultAlreadyExists(address vaultToken);

    /**
     * @dev Triggered when trying to interact with a vault that does not exist
     * @param vaultToken The address that was passed as input
     */
    error RayFi__VaultDoesNotExist(address vaultToken);

    /**
     * @dev Triggered when trying to retrieve RayFi tokens from the contract
     * This is a security measure to prevent malicious retrieval of RayFi tokens
     */
    error RayFi__CannotRetrieveRayFi();

    /**
     * @dev Indicates a failure in setting the minimum token balance for rewards due to the amount being too high
     * @param newMinimumTokenBalanceForRewards The new minimum token balance that was attempted to be set
     */
    error RayFi__MinimumTokenBalanceForRewardsTooHigh(uint160 newMinimumTokenBalanceForRewards);

    /**
     * @dev Indicates a failure in setting new fees due to the total fees being too high
     * @param totalFees The total fees that were attempted to be set
     */
    error RayFi__FeesTooHigh(uint256 totalFees);

    /**
     * @dev Triggered when trying to distribute rewards using the same snapshot more than once
     */
    error RayFi__DistributionAlreadyProcessed();

    /**
     * @dev Triggered when trying to alter the state of the distribution while it is already in progress
     */
    error RayFi__DistributionInProgress();

    ////////////////////
    // Constructor    //
    ////////////////////

    /**
     * @param router The address of the router that will be used to reinvest rewards
     * @param rewardToken The address of the token that will be distributed as default rewards
     * @param swapReceiver The address of the wallet that will distribute reinvested rewards
     * @param feeReceiver The address of the wallet that will receive trading fees
     */
    constructor(address router, address rewardToken, address swapReceiver, address feeReceiver)
        ERC20("RayFi", "RAYFI")
        Ownable(msg.sender)
    {
        if (
            rewardToken == address(0) || router == address(0) || feeReceiver == address(0) || swapReceiver == address(0)
        ) {
            revert RayFi__CannotSetToZeroAddress();
        }

        s_router = IUniswapV2Router02(router);
        s_rewardToken = rewardToken;
        s_swapReceiver = swapReceiver;
        s_feeReceiver = feeReceiver;

        s_isFeeExempt[swapReceiver] = true;
        s_isFeeExempt[feeReceiver] = true;

        s_isExcludedFromRewards[swapReceiver] = true;
        s_isExcludedFromRewards[feeReceiver] = true;
        s_isExcludedFromRewards[address(this)] = true;
        s_isExcludedFromRewards[address(0)] = true;

        s_vaultTokens.push(address(this));
        s_vaults[address(this)].vaultId = s_vaultTokens.length;

        _mint(msg.sender, MAX_SUPPLY);
    }

    ///////////////////////////
    // External Functions    //
    ///////////////////////////

    /**
     * @notice This function allows users to stake their RayFi tokens in a vault to have their rewards reinvested
     * Staking in the RayFi vault will compound the rewards, whereas rewards from other vaults will be airdropped
     * @param vaultToken The address of the token of the vault to stake in
     * @param value The amount of tokens to stake
     */
    function stake(address vaultToken, uint256 value) external {
        if (!s_shareholders.contains(msg.sender)) {
            revert RayFi__InsufficientTokensToStake(s_minimumTokenBalanceForRewards);
        } else if (s_vaults[vaultToken].vaultId == 0) {
            revert RayFi__VaultDoesNotExist(vaultToken);
        } else if (s_distributionState != DistributionState.Inactive) {
            revert RayFi__DistributionInProgress();
        }

        super._update(msg.sender, address(this), value);
        _stake(vaultToken, msg.sender, uint160(value));
    }

    /**
     * @notice This function allows users to unstake their RayFi tokens from a vault
     * @dev It is enough to check the user balance since it will be zero for inexistent vaults
     * @param vaultToken The address of the token of the vault to unstake from
     * @param value The amount of tokens to unstake
     */
    function unstake(address vaultToken, uint256 value) external {
        uint256 stakedBalance = s_vaults[vaultToken].stakers.get(msg.sender);
        if (stakedBalance < value) {
            revert RayFi__InsufficientStakedBalance(stakedBalance, value);
        } else if (s_distributionState != DistributionState.Inactive) {
            revert RayFi__DistributionInProgress();
        }

        _unstake(vaultToken, msg.sender, uint160(value));
        super._update(address(this), msg.sender, value);
    }

    /**
     * @notice This function allows the owner to take a snapshot of the current state of the RayFi protocol
     * @dev By increasing `s_snapshotId` with the `++` operator on the right,
     * `currentSnapshotId` will be equal to `s_snapshotId - 1` after the function call
     * @return currentSnapshotId The id of the current snapshot
     */
    function snapshot() external onlyOwner returns (uint96 currentSnapshotId) {
        currentSnapshotId = s_snapshotId++;
        emit SnapshotTaken(currentSnapshotId);
    }

    /**
     * @notice High-level function to start the reward distribution process in stateless mode
     * The stateless mode is always the preferred one, as it is drastically more gas-efficient
     * Rewards are either sent to users as stablecoins or reinvested for users who have staked their tokens in vaults
     * @dev This function assumes that a snapshot has been taken before the distribution process
     * @param maxSwapSlippage The maximum acceptable percentage slippage for the reinvestment swaps
     */
    function distributeRewardsStateless(uint8 maxSwapSlippage) external onlyOwner {
        uint96 snapshotId = s_snapshotId - 1;
        if (snapshotId < s_nextSnapshotIdToProcess) {
            revert RayFi__DistributionAlreadyProcessed();
        } else if (s_distributionState != DistributionState.Inactive) {
            revert RayFi__DistributionInProgress();
        }

        address rewardToken = s_rewardToken;
        uint256 totalUnclaimedRewards = ERC20(rewardToken).balanceOf(address(this));
        uint256 totalRewardShares = s_totalRewardSharesSnapshots.upperLookupRecent(snapshotId);
        uint256 totalStakedShares = s_totalStakedSharesSnapshots.upperLookupRecent(snapshotId);
        if (totalStakedShares == 0) {
            uint256 magnifiedRewardPerShare = _calculateRewardPerShare(totalUnclaimedRewards, totalRewardShares);
            _processRewards(magnifiedRewardPerShare, rewardToken, snapshotId, false, 0);
        } else {
            address[] memory vaultTokens = s_vaultTokens;
            uint256 totalRewardsToReinvest = totalUnclaimedRewards * totalStakedShares / totalRewardShares;
            _reinvestRewards(
                rewardToken, snapshotId, maxSwapSlippage, totalRewardsToReinvest, totalStakedShares, vaultTokens
            );
            _processVaults(vaultTokens, snapshotId, 0, false);

            uint256 totalNonStakedAmount = totalRewardShares - totalStakedShares;
            if (totalNonStakedAmount > 0) {
                totalUnclaimedRewards = ERC20(rewardToken).balanceOf(address(this));
                uint256 magnifiedRewardPerShare = _calculateRewardPerShare(totalUnclaimedRewards, totalNonStakedAmount);
                _processRewards(magnifiedRewardPerShare, rewardToken, snapshotId, false, 0);
            }
        }

        s_nextSnapshotIdToProcess = snapshotId + 1;
    }

    /**
     * @notice High-level function to start the reward distribution process in stateful mode
     * The stateful mode is a backup to use only in case the stateless mode is unable to complete the distribution
     * Rewards are either sent to users as stablecoins or reinvested for users who have staked their tokens in vaults
     * @dev This function assumes that a snapshot has been taken before the distribution process
     * @param gasForRewards The amount of gas to use for processing rewards
     * This is a safety mechanism to prevent the contract from running out of gas at an inconvenient time
     * `gasForRewards` should be set to a value that is less than the gas limit of the transaction
     * @param maxSwapSlippage The maximum acceptable percentage slippage for the reinvestment swaps
     * @param vaultTokens The list of vaults to distribute rewards to, can be left empty to distribute to all vaults
     */
    function distributeRewardsStateful(uint32 gasForRewards, uint8 maxSwapSlippage, address[] memory vaultTokens)
        external
        onlyOwner
        returns (bool isComplete)
    {
        uint96 snapshotId = s_snapshotId - 1;
        if (snapshotId < s_nextSnapshotIdToProcess) {
            revert RayFi__DistributionAlreadyProcessed();
        }

        address rewardToken = s_rewardToken;
        uint256 totalRewardShares = s_totalRewardSharesSnapshots.upperLookupRecent(snapshotId);
        uint256 totalStakedShares = s_totalStakedSharesSnapshots.upperLookupRecent(snapshotId);
        if (totalStakedShares == 0) {
            if (s_distributionState == DistributionState.Inactive) {
                uint256 totalUnclaimedRewards = ERC20(rewardToken).balanceOf(address(this));
                s_magnifiedRewardPerShare = _calculateRewardPerShare(totalUnclaimedRewards, totalRewardShares);
                s_distributionState = DistributionState.ProcessingRewards;
            }
            isComplete = _processRewards(s_magnifiedRewardPerShare, rewardToken, snapshotId, true, gasForRewards);
        } else {
            if (vaultTokens.length == 0) {
                vaultTokens = s_vaultTokens;
            }

            uint256 totalRewardsToReinvest;
            if (s_distributionState == DistributionState.Inactive) {
                uint256 totalUnclaimedRewards = ERC20(rewardToken).balanceOf(address(this));
                totalRewardsToReinvest = totalUnclaimedRewards * totalStakedShares / totalRewardShares;
                _reinvestRewards(
                    rewardToken, snapshotId, maxSwapSlippage, totalRewardsToReinvest, totalStakedShares, vaultTokens
                );
                s_distributionState = DistributionState.ProcessingVaults;
            }

            if (s_distributionState == DistributionState.ProcessingVaults) {
                isComplete = _processVaults(vaultTokens, snapshotId, gasForRewards, true);
                if (!isComplete) {
                    return false;
                }
            }

            uint256 totalNonStakedAmount = totalRewardShares - totalStakedShares;
            if (totalNonStakedAmount > 0) {
                if (s_distributionState != DistributionState.ProcessingRewards) {
                    uint256 totalUnclaimedRewards = ERC20(rewardToken).balanceOf(address(this));
                    s_magnifiedRewardPerShare = _calculateRewardPerShare(totalUnclaimedRewards, totalNonStakedAmount);
                    s_distributionState = DistributionState.ProcessingRewards;
                }
                isComplete = _processRewards(s_magnifiedRewardPerShare, rewardToken, snapshotId, true, gasForRewards);
            }
        }

        if (isComplete) {
            s_magnifiedRewardPerShare = 0;
            s_nextSnapshotIdToProcess = snapshotId + 1;
            s_distributionState = DistributionState.Inactive;
        }
    }

    /**
     * @notice This function allows the owner to add a new vault to the RayFi protocol
     * @dev Using the length of the `s_vaultTokens` array as the vault id allows us to easily remove it later
     * or to use the 0 id to check if a vault exists
     * @param vaultToken The key of the new vault, which should be the address of the associated ERC20 reward token
     */
    function addVault(address vaultToken) external onlyOwner {
        Vault storage vault = s_vaults[vaultToken];
        if (vault.vaultId != 0) {
            revert RayFi__VaultAlreadyExists(vaultToken);
        } else if (vaultToken == address(0)) {
            revert RayFi__CannotSetToZeroAddress();
        } else if (s_distributionState != DistributionState.Inactive) {
            revert RayFi__DistributionInProgress();
        } else {
            s_vaultTokens.push(vaultToken);
            vault.vaultId = s_vaultTokens.length;
        }
    }

    /**
     * @notice This function allows the owner to remove a vault from the RayFi protocol
     * @dev We have to ensure the vault is fully reset to prevent any leftover state affecting future distributions
     * @param vaultToken The key of the vault to remove
     */
    function removeVault(address vaultToken) external onlyOwner {
        Vault storage vault = s_vaults[vaultToken];
        uint256 vaultId = vault.vaultId;
        if (vaultId == 0) {
            revert RayFi__VaultDoesNotExist(vaultToken);
        } else if (s_distributionState != DistributionState.Inactive) {
            revert RayFi__DistributionInProgress();
        } else {
            EnumerableMap.AddressToUintMap storage stakersBalancesMap = vault.stakers;
            address[] memory stakers = stakersBalancesMap.keys();
            for (uint256 i; i < stakers.length; ++i) {
                address staker = stakers[i];
                uint256 stakedAmount = stakersBalancesMap.get(staker);
                _unstake(vaultToken, staker, uint160(stakedAmount));
                super._update(address(this), staker, stakedAmount);
            }
            vault.vaultId = 0;
            vault.totalVaultSharesSnapshots.push(s_snapshotId, 0);
            uint256 vaultIndex = vaultId - 1;
            uint256 lastVaultIndex = s_vaultTokens.length - 1;
            if (vaultIndex != lastVaultIndex) {
                s_vaultTokens[vaultIndex] = s_vaultTokens[lastVaultIndex];
            }
            s_vaultTokens.pop();
        }
    }

    /**
     * @notice This function allows the owner to retrieve any ERC20 token other than RayFi stuck in the contract
     * @dev Retrieving RayFi tokens is not allowed both because they cannot be manually transferred to the contract
     * and to prevent malicious retrieval of staked RayFi tokens in case the owner wallet is compromised
     * @param token The address of the token to retrieve
     * @param to The address to send the tokens to
     * @param value The amount of tokens to retrieve
     */
    function retrieveERC20(address token, address to, uint256 value) external onlyOwner {
        if (token == address(this)) {
            revert RayFi__CannotRetrieveRayFi();
        } else if (to == address(0)) {
            revert RayFi__CannotSetToZeroAddress();
        }
        ERC20(token).transfer(to, value);
    }

    /**
     * @notice This function allows the owner to retrieve BNB stuck in the contract
     * @param to The address to send the BNB to
     * @param value The amount of BNB to retrieve
     */
    function retrieveBNB(address to, uint256 value) external onlyOwner {
        if (to == address(0)) {
            revert RayFi__CannotSetToZeroAddress();
        }
        payable(to).transfer(value);
    }

    /**
     * @notice This function allows the owner to permanently disable trading fees on the RayFi token
     * @dev This is a one-way function and cannot be undone
     */
    function removeTradingFees() external onlyOwner {
        s_areTradingFeesEnabled = false;
        emit TradingFeesRemoved();
    }

    /**
     * @notice Updates the fee amounts for buys and sells while ensuring the total fees do not exceed the maximum
     * @param buyFee The new buy fee
     * @param sellFee The new sell fee
     */
    function setFeeAmounts(uint8 buyFee, uint8 sellFee) external onlyOwner {
        uint8 totalFee = buyFee + sellFee;
        if (totalFee > MAX_FEES) {
            revert RayFi__FeesTooHigh(totalFee);
        }

        s_buyFee = buyFee;
        s_sellFee = sellFee;

        emit FeeAmountsUpdated(buyFee, sellFee);
    }

    /**
     * @notice Sets whether a pair is an automated market maker pair for this token
     * @param pair The pair to update
     * @param isActive Whether the pair is an automated market maker pair
     */
    function setIsAutomatedMarketPair(address pair, bool isActive) external onlyOwner {
        if (pair == address(0)) {
            revert RayFi__CannotSetToZeroAddress();
        }
        s_isAutomatedMarketMakerPairs[pair] = isActive;
        emit AutomatedMarketPairUpdated(pair, isActive);
    }

    /**
     * @notice Sets the minimum token balance for rewards
     * @param newMinimum The new minimum token balance for rewards
     */
    function setMinimumTokenBalanceForRewards(uint160 newMinimum) external onlyOwner {
        if (newMinimum > MAX_TOKEN_REQUIREMENT_FOR_REWARDS) {
            revert RayFi__MinimumTokenBalanceForRewardsTooHigh(newMinimum);
        }
        uint160 oldMinimum = s_minimumTokenBalanceForRewards;
        s_minimumTokenBalanceForRewards = newMinimum;
        emit MinimumTokenBalanceForRewardsUpdated(newMinimum, oldMinimum);
    }

    /**
     * @notice Sets whether an address is excluded from rewards
     * @param user The address to update
     * @param isExcluded Whether the address is excluded from rewards
     */
    function setIsExcludedFromRewards(address user, bool isExcluded) external onlyOwner {
        s_isExcludedFromRewards[user] = isExcluded;
        if (isExcluded) {
            _removeShareholder(user, s_snapshotId);
        } else {
            _updateShareholder(user, s_snapshotId);
        }
        emit IsUserExcludedFromRewardsUpdated(user, isExcluded);
    }

    /**
     * @notice Sets whether an address is exempt from fees
     * @param user The address to update
     * @param isExempt Whether the address is exempt from fees
     */
    function setIsFeeExempt(address user, bool isExempt) external onlyOwner {
        s_isFeeExempt[user] = isExempt;
        emit IsUserExemptFromFeesUpdated(user, isExempt);
    }

    /**
     * @notice Sets the address of the token that will be distributed as rewards by default
     * @param newRewardToken The address of the new reward token
     */
    function setRewardToken(address newRewardToken) external onlyOwner {
        if (newRewardToken == address(0)) {
            revert RayFi__CannotSetToZeroAddress();
        }
        address oldRewardToken = s_rewardToken;
        s_rewardToken = newRewardToken;
        emit RewardTokenUpdated(newRewardToken, oldRewardToken);
    }

    /**
     * @notice Sets the address of the router that will be used to reinvest rewards
     * @param newRouter The address of the new router
     */
    function setRouter(address newRouter) external onlyOwner {
        if (newRouter == address(0)) {
            revert RayFi__CannotSetToZeroAddress();
        }
        address oldRouter = address(s_router);
        s_router = IUniswapV2Router02(newRouter);
        emit RouterUpdated(newRouter, oldRouter);
    }

    /**
     * @notice Sets the address that will receive fees charged on trades
     * @param newFeeReceiver The address of the fee receiver
     */
    function setFeeReceiver(address newFeeReceiver) external onlyOwner {
        if (newFeeReceiver == address(0)) {
            revert RayFi__CannotSetToZeroAddress();
        }
        address oldFeeReceiver = s_feeReceiver;
        s_feeReceiver = newFeeReceiver;
        emit FeeReceiverUpdated(newFeeReceiver, oldFeeReceiver);
    }

    /**
     * @notice Sets the address of the wallet that will temporarily receive RayFi tokens from reinvestment swaps
     * @param newSwapReceiver The address of the new swap receiver
     */
    function setSwapReceiver(address newSwapReceiver) external onlyOwner {
        if (newSwapReceiver == address(0)) {
            revert RayFi__CannotSetToZeroAddress();
        }
        address oldSwapReceiver = s_swapReceiver;
        s_swapReceiver = newSwapReceiver;
        emit SwapReceiverUpdated(newSwapReceiver, oldSwapReceiver);
    }

    ////////////////////////////////
    // External View Functions    //
    ////////////////////////////////

    /**
     * @notice Get the current shareholders of the RayFi protocol
     * @return The list of shareholders
     */
    function getShareholders() external view returns (address[] memory) {
        return s_shareholders.keys();
    }

    /**
     * @notice Get the total amount of shares owned by a user
     * @dev This is expected to be 0 if `balanceOf(user)` < `s_minimumTokenBalanceForRewards`
     * @return The total shares amount owned by the user
     */
    function getSharesBalanceOf(address user) external view returns (uint256) {
        (bool isShareholder, uint256 shares) = s_shareholders.tryGet(user);
        return isShareholder ? shares : 0;
    }

    /**
     * @notice Get the staked balance of a specific user
     * @param user The user to check
     * @return The staked balance of the user
     */
    function getStakedBalanceOf(address user) external view returns (uint256) {
        return s_stakedBalances[user];
    }

    /**
     * @notice Get the total amount of tokens eligible for rewards
     * @return The total reward tokens amount
     */
    function getTotalRewardShares() external view returns (uint256) {
        return s_totalRewardSharesSnapshots.latest();
    }

    /**
     * @notice Get the total amount of staked tokens
     * @return The total staked tokens amount
     */
    function getTotalStakedShares() external view returns (uint256) {
        return s_totalStakedSharesSnapshots.latest();
    }

    /**
     * @notice Get the current list of vault tokens
     * @return The list of vault tokens
     */
    function getVaultTokens() external view returns (address[] memory) {
        return s_vaultTokens;
    }

    /**
     * @notice Get the total amount of shares staked in a specific vault by the given user
     * @param vaultToken The address of the vault token
     * @param user The address of the user
     * @return The total staked shares amount of the user in the vault
     */
    function getVaultBalanceOf(address vaultToken, address user) external view returns (uint256) {
        (bool isStakerInVault, uint256 vaultShares) = s_vaults[vaultToken].stakers.tryGet(user);
        return isStakerInVault ? vaultShares : 0;
    }

    /**
     * @notice Get the total amount of shares staked in a specific vault
     * @param vaultToken The address of the vault token
     * @return The total staked shares amount
     */
    function getTotalVaultShares(address vaultToken) external view returns (uint256) {
        return s_vaults[vaultToken].totalVaultSharesSnapshots.latest();
    }

    /**
     * @notice Get the minimum token balance required to start earning rewards
     * @return The minimum token balance for rewards
     */
    function getMinimumTokenBalanceForRewards() external view returns (uint256) {
        return s_minimumTokenBalanceForRewards;
    }

    /**
     * @notice Get the current snapshot id
     * @return The snapshot id
     */
    function getCurrentSnapshotId() external view returns (uint96) {
        return s_snapshotId;
    }

    /**
     * @notice Get the token balance of a user at a specific snapshot
     * @param user The address of the user
     * @param snapshotId The id of the snapshot
     * @return The token balance of the user at the snapshot
     */
    function getBalanceOfAtSnapshot(address user, uint96 snapshotId) external view returns (uint256) {
        return s_balancesSnapshots[user].upperLookupRecent(snapshotId);
    }

    /**
     * @notice Get the vault balance of a user at a specific snapshot
     * @param vaultToken The address of the vault token
     * @param user The address of the user
     * @param snapshotId The id of the snapshot
     * @return The vault balance of the user at the snapshot
     */
    function getVaultBalanceOfAtSnapshot(address vaultToken, address user, uint96 snapshotId)
        external
        view
        returns (uint256)
    {
        return s_vaults[vaultToken].stakersSnapshots[user].upperLookupRecent(snapshotId);
    }

    /**
     * @notice Get the total reward shares at a specific snapshot
     * @param snapshotId The id of the snapshot
     * @return The total reward shares at the snapshot
     */
    function getTotalRewardSharesAtSnapshot(uint96 snapshotId) external view returns (uint256) {
        return s_totalRewardSharesSnapshots.upperLookupRecent(snapshotId);
    }

    /**
     * @notice Get the total staked shares at a specific snapshot
     * @param snapshotId The id of the snapshot
     * @return The total staked shares at the snapshot
     */
    function getTotalStakedSharesAtSnapshot(uint96 snapshotId) external view returns (uint256) {
        return s_totalStakedSharesSnapshots.upperLookupRecent(snapshotId);
    }

    /**
     * @notice Get the total vault shares at a specific snapshot
     * @param vaultToken The address of the vault token
     * @param snapshotId The id of the snapshot
     * @return The total vault shares at the snapshot
     */
    function getTotalVaultSharesAtSnapshot(address vaultToken, uint96 snapshotId) external view returns (uint256) {
        return s_vaults[vaultToken].totalVaultSharesSnapshots.upperLookupRecent(snapshotId);
    }

    /**
     * @notice Get the address of the token that will be distributed as rewards
     * @return The address of the reward token
     */
    function getRewardToken() external view returns (address) {
        return s_rewardToken;
    }

    /**
     * @notice Get the fee receiver
     * @return The address of the fee receiver
     */
    function getFeeReceiver() external view returns (address) {
        return s_feeReceiver;
    }

    /**
     * @notice Get whether trading fees are enabled
     * @return Whether trading fees are enabled
     */
    function getAreTradingFeesEnabled() external view returns (bool) {
        return s_areTradingFeesEnabled;
    }

    /**
     * @notice Returns the buy fee
     * @return The buy fee
     */
    function getBuyFee() external view returns (uint256) {
        return s_buyFee;
    }

    /**
     * @notice Returns the sell fee
     * @return The sell fee
     */
    function getSellFee() external view returns (uint256) {
        return s_sellFee;
    }

    //////////////////////////
    // Private Functions    //
    //////////////////////////

    /**
     * @dev Overrides the internal `_update` function to include fee logic and shareholder tracking for rewards
     * @param from The address of the sender
     * @param to The address of the recipient
     * @param value The amount of tokens to transfer
     */
    function _update(address from, address to, uint256 value) internal override {
        if (to == address(this)) {
            revert RayFi__CannotManuallySendRayFiToTheContract();
        }

        if (s_areTradingFeesEnabled) {
            if (s_isAutomatedMarketMakerPairs[from] && !s_isFeeExempt[to]) {
                // Buy order
                uint8 buyFee = s_buyFee;
                if (buyFee > 0) {
                    value -= _takeFee(from, value, buyFee);
                }
            } else if (s_isAutomatedMarketMakerPairs[to] && !s_isFeeExempt[from]) {
                // Sell order
                uint8 sellFee = s_sellFee;
                if (sellFee > 0) {
                    value -= _takeFee(from, value, sellFee);
                }
            } else if (!s_isFeeExempt[from] && !s_isFeeExempt[to]) {
                // Transfer
                uint8 transferFee = s_buyFee + s_sellFee;
                if (transferFee > 0) {
                    value -= _takeFee(from, value, transferFee);
                }
            }
        }

        super._update(from, to, value);

        uint96 snapshotId = s_snapshotId;
        _updateShareholder(from, snapshotId);
        _updateShareholder(to, snapshotId);
    }

    /**
     * @dev Takes a fee from a transaction value and sends it to the fee receiver
     * @param from The address of the sender
     * @param value The amount of tokens to take the fee from
     * @param fee The fee percentage to take
     * @return feeAmount The amount of the fee
     */
    function _takeFee(address from, uint256 value, uint8 fee) private returns (uint256 feeAmount) {
        feeAmount = value * fee / 100;
        address feeReceiver = s_feeReceiver;
        super._update(from, feeReceiver, feeAmount);
    }

    /**
     * @dev Updates the given shareholder map and snapshot
     * @param shareholder The address of the shareholder
     * @param snapshotId The id of the snapshot
     */
    function _updateShareholder(address shareholder, uint96 snapshotId) private {
        uint256 newBalance = balanceOf(shareholder);
        uint256 totalBalance = newBalance + s_stakedBalances[shareholder];
        if (totalBalance >= s_minimumTokenBalanceForRewards && !s_isExcludedFromRewards[shareholder]) {
            (bool success, uint256 oldBalance) = s_shareholders.tryGet(shareholder);
            if (!success) {
                s_totalRewardSharesSnapshots.push(
                    snapshotId, s_totalRewardSharesSnapshots.latest() + uint160(totalBalance)
                );
            } else if (totalBalance >= oldBalance) {
                s_totalRewardSharesSnapshots.push(
                    snapshotId, s_totalRewardSharesSnapshots.latest() + uint160(totalBalance - oldBalance)
                );
            } else {
                s_totalRewardSharesSnapshots.push(
                    snapshotId, s_totalRewardSharesSnapshots.latest() - uint160(oldBalance - totalBalance)
                );
            }
            s_shareholders.set(shareholder, totalBalance);
            s_balancesSnapshots[shareholder].push(snapshotId, uint160(newBalance));
        } else {
            _removeShareholder(shareholder, snapshotId);
        }
    }

    /**
     * @dev Removes a shareholder from the map, retrieves their staked tokens and updates the given snapshot
     * @param shareholder The address of the shareholder
     * @param snapshotId The id of the snapshot
     */
    function _removeShareholder(address shareholder, uint96 snapshotId) private {
        if (s_shareholders.contains(shareholder)) {
            s_totalRewardSharesSnapshots.push(
                snapshotId, s_totalRewardSharesSnapshots.latest() - uint160(s_shareholders.get(shareholder))
            );
            s_shareholders.remove(shareholder);
            uint256 stakedBalance = s_stakedBalances[shareholder];
            if (stakedBalance > 0) {
                for (uint256 i; i < s_vaultTokens.length; ++i) {
                    address vaultToken = s_vaultTokens[i];
                    _unstake(vaultToken, shareholder, uint160(s_vaults[vaultToken].stakers.get(shareholder)));
                }
                super._update(address(this), shareholder, stakedBalance);
            }
            s_balancesSnapshots[shareholder].push(snapshotId, 0);
        }
    }

    /**
     * @dev Low-level function to stake RayFi tokens in a given vault
     * Assumes that `_balances` have already been updated and that the vault exists
     * @param vaultToken The address of the token of the vault to stake in
     * @param user The address of the user to stake the RayFi tokens for
     * @param value The amount of RayFi tokens to stake
     */
    function _stake(address vaultToken, address user, uint160 value) private {
        Vault storage vault = s_vaults[vaultToken];
        (, uint256 userBalance) = vault.stakers.tryGet(user);
        uint96 snapshotId = s_snapshotId;
        vault.stakers.set(user, userBalance + value);
        vault.stakersSnapshots[user].push(snapshotId, uint160(userBalance) + value);
        vault.totalVaultSharesSnapshots.push(snapshotId, vault.totalVaultSharesSnapshots.latest() + value);

        s_stakedBalances[user] += value;
        s_totalStakedSharesSnapshots.push(snapshotId, s_totalStakedSharesSnapshots.latest() + value);

        Checkpoints.Trace160 storage balanceSnapshot = s_balancesSnapshots[user];
        balanceSnapshot.push(snapshotId, balanceSnapshot.latest() - value);

        emit RayFiStaked(user, value, s_totalStakedSharesSnapshots.latest());
    }

    /**
     * @dev Low-level function to unstake RayFi tokens from a given vault
     * Assumes that the vault exists and that the user has enough staked tokens
     * @param vaultToken The address of the token of the vault to unstake from
     * @param user The address of the user to unstake the RayFi tokens for
     * @param value The amount of RayFi tokens to unstake
     */
    function _unstake(address vaultToken, address user, uint160 value) private {
        Vault storage vault = s_vaults[vaultToken];
        uint256 userBalance = vault.stakers.get(user);
        uint256 remainingBalance = userBalance - value;
        uint96 snapshotId = s_snapshotId;
        if (remainingBalance == 0) {
            vault.stakers.remove(user);
            vault.stakersSnapshots[user].push(snapshotId, 0);
        } else {
            vault.stakers.set(user, remainingBalance);
            vault.stakersSnapshots[user].push(snapshotId, uint160(remainingBalance));
        }
        vault.totalVaultSharesSnapshots.push(snapshotId, vault.totalVaultSharesSnapshots.latest() - value);

        s_stakedBalances[user] -= value;
        s_totalStakedSharesSnapshots.push(snapshotId, s_totalStakedSharesSnapshots.latest() - value);

        Checkpoints.Trace160 storage balanceSnapshot = s_balancesSnapshots[user];
        balanceSnapshot.push(snapshotId, balanceSnapshot.latest() + value);

        emit RayFiUnstaked(user, value, s_totalStakedSharesSnapshots.latest());
    }

    /**
     * @dev Low-level function to reinvest the given amount of rewards into the vault tokens
     * @param rewardToken The address of the reward token
     * @param snapshotId The id of the snapshot to use
     * @param slippage The maximum acceptable percentage slippage for the reinvestment swaps
     * @param totalRewardsToReinvest The total amount of rewards to reinvest
     * @param totalStakedShares The total amount of staked shares
     * @param vaultTokens The list of vaults to distribute rewards to
     */
    function _reinvestRewards(
        address rewardToken,
        uint96 snapshotId,
        uint8 slippage,
        uint256 totalRewardsToReinvest,
        uint256 totalStakedShares,
        address[] memory vaultTokens
    ) private {
        IUniswapV2Router02 router = s_router;
        ERC20(rewardToken).approve(address(s_router), totalRewardsToReinvest);
        address swapReceiver = s_swapReceiver;
        for (uint256 i; i < vaultTokens.length; ++i) {
            address vaultToken = vaultTokens[i];
            uint256 totalStakedAmountInVault =
                s_vaults[vaultToken].totalVaultSharesSnapshots.upperLookupRecent(snapshotId);
            if (totalStakedAmountInVault == 0) {
                continue;
            }

            uint256 rewardsToReinvest = totalRewardsToReinvest * totalStakedAmountInVault / totalStakedShares;
            if (vaultToken != address(this)) {
                _swapRewards(router, rewardToken, vaultToken, address(this), rewardsToReinvest, slippage);
            } else {
                _swapRewards(router, rewardToken, vaultToken, swapReceiver, rewardsToReinvest, slippage);
            }
        }
    }

    /**
     * @dev Low-level function to execute a swap with the given slippage using a UniswapV2-compatible router
     * Assumes that the tokens have already been approved for spending
     * @param router The address of the UniswapV2-compatible router
     * @param tokenIn The address of the token to swap from
     * @param tokenOut The address of the token to swap to
     * @param to The address to send the swapped tokens to
     * @param amountIn The amount of tokens to swap from
     * @param slippage The maximum acceptable percentage slippage for the swap
     */
    function _swapRewards(
        IUniswapV2Router02 router,
        address tokenIn,
        address tokenOut,
        address to,
        uint256 amountIn,
        uint8 slippage
    ) private {
        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;
        uint256 amountOutMin = router.getAmountsOut(amountIn, path)[1];
        if (slippage > 0) {
            amountOutMin = amountOutMin * (100 - slippage) / 100;
        }
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn, amountOutMin, path, to, block.timestamp);
    }

    /**
     * @dev Low-level function to process rewards for all token holders in either stateful or stateless mode
     * @param magnifiedRewardPerShare The magnified reward amount per share
     * @param rewardToken The address of the reward token
     * @param snapshotId The id of the snapshot to use
     * @param isStateful Whether to save the state of the distribution
     * @param gasForRewards The amount of gas to use for processing rewards
     */
    function _processRewards(
        uint256 magnifiedRewardPerShare,
        address rewardToken,
        uint96 snapshotId,
        bool isStateful,
        uint32 gasForRewards
    ) private returns (bool isComplete) {
        address[] memory shareholders = s_shareholders.keys();
        uint256 earnedRewards;
        if (isStateful) {
            uint256 startingGas = gasleft();
            uint256 lastProcessedIndex = s_lastProcessedIndex;
            uint256 gasUsed;
            while (gasUsed < gasForRewards) {
                address user = shareholders[lastProcessedIndex];
                earnedRewards += _processRewardOfUser(user, snapshotId, magnifiedRewardPerShare, rewardToken);

                ++lastProcessedIndex;
                if (lastProcessedIndex >= shareholders.length) {
                    lastProcessedIndex = 0;
                    isComplete = true;
                    break;
                }

                gasUsed += startingGas - gasleft();
            }
            s_lastProcessedIndex = lastProcessedIndex;
        } else {
            for (uint256 i; i < shareholders.length; ++i) {
                address user = shareholders[i];
                earnedRewards += _processRewardOfUser(user, snapshotId, magnifiedRewardPerShare, rewardToken);
            }
            isComplete = true;
        }

        emit RewardsDistributed(earnedRewards, rewardToken);
    }

    /**
     * @dev Low-level function to process the given vaults
     * Mainly exists to clean up the high-level `distributeRewards` function and avoid "stack too deep" errors
     * @param vaultTokens The list of vaults to distribute rewards to
     * @param snapshotId The id of the snapshot to use
     * @param gasForRewards The amount of gas to use for processing rewards, ignored in stateless mode
     * @param isStateful Whether to save the state of the distribution
     * @return isComplete Whether the distribution is complete
     */
    function _processVaults(address[] memory vaultTokens, uint96 snapshotId, uint32 gasForRewards, bool isStateful)
        private
        returns (bool isComplete)
    {
        for (uint256 i; i < vaultTokens.length; ++i) {
            address vaultToken = vaultTokens[i];
            Vault storage vault = s_vaults[vaultToken];
            uint256 totalStakedAmountInVault = vault.totalVaultSharesSnapshots.upperLookupRecent(snapshotId);
            VaultState startingVaultState = vault.state;
            if (totalStakedAmountInVault == 0 || startingVaultState == VaultState.ResetPending) {
                continue;
            }

            uint256 vaultTokensToDistribute;
            bool isVaultTokenRayFi = vaultToken == address(this);
            if (isVaultTokenRayFi) {
                vaultTokensToDistribute = balanceOf(s_swapReceiver);
            } else {
                vaultTokensToDistribute = ERC20(vaultToken).balanceOf(address(this));
            }

            uint256 magnifiedVaultRewardsPerShare;
            if (isStateful) {
                if (startingVaultState != VaultState.Processing) {
                    vault.magnifiedRewardPerShare =
                        _calculateRewardPerShare(vaultTokensToDistribute, totalStakedAmountInVault);
                    vault.state = VaultState.Processing;
                }
                magnifiedVaultRewardsPerShare = vault.magnifiedRewardPerShare;
            } else {
                magnifiedVaultRewardsPerShare =
                    _calculateRewardPerShare(vaultTokensToDistribute, totalStakedAmountInVault);
            }

            if (
                _processVault(
                    magnifiedVaultRewardsPerShare, vaultToken, snapshotId, gasForRewards, isVaultTokenRayFi, isStateful
                )
            ) {
                continue;
            } else {
                return false;
            }
        }

        if (isStateful) {
            for (uint256 i; i < vaultTokens.length; ++i) {
                s_vaults[vaultTokens[i]].state = VaultState.Ready;
            }
        }
        return true;
    }

    /**
     * @dev Low-level function to process rewards for a specific vault in either stateful or stateless mode
     * @param magnifiedVaultRewardsPerShare The magnified reward amount per share
     * @param vaultToken The address of the vault token
     * @param snapshotId The id of the snapshot to use
     * @param gasForRewards The amount of gas to use for processing rewards
     * @param isVaultTokenRayFi Whether the vault token is RayFi
     * @param isStateful Whether to save the state of the distribution
     */
    function _processVault(
        uint256 magnifiedVaultRewardsPerShare,
        address vaultToken,
        uint96 snapshotId,
        uint32 gasForRewards,
        bool isVaultTokenRayFi,
        bool isStateful
    ) private returns (bool isComplete) {
        Vault storage vault = s_vaults[vaultToken];
        address[] memory shareholders = vault.stakers.keys();
        uint256 vaultRewards;
        if (isStateful) {
            uint256 startingGas = gasleft();
            uint256 lastProcessedIndex = vault.lastProcessedIndex;
            uint256 gasUsed;
            while (gasUsed < gasForRewards) {
                vaultRewards += _processVaultOfUser(
                    shareholders[lastProcessedIndex],
                    snapshotId,
                    magnifiedVaultRewardsPerShare,
                    vaultToken,
                    isVaultTokenRayFi,
                    vault
                );

                ++lastProcessedIndex;
                if (lastProcessedIndex >= shareholders.length) {
                    vault.magnifiedRewardPerShare = 0;
                    vault.state = VaultState.ResetPending;
                    lastProcessedIndex = 0;
                    isComplete = true;
                    break;
                }

                gasUsed += startingGas - gasleft();
            }
            vault.lastProcessedIndex = lastProcessedIndex;
        } else {
            for (uint256 i; i < shareholders.length; ++i) {
                vaultRewards += _processVaultOfUser(
                    shareholders[i], snapshotId, magnifiedVaultRewardsPerShare, vaultToken, isVaultTokenRayFi, vault
                );
            }
            isComplete = true;
        }

        if (isVaultTokenRayFi) {
            super._update(s_swapReceiver, address(this), vaultRewards);

            snapshotId = ++snapshotId;
            uint160 delta = uint160(vaultRewards);
            vault.totalVaultSharesSnapshots.push(snapshotId, vault.totalVaultSharesSnapshots.latest() + delta);
            s_totalRewardSharesSnapshots.push(snapshotId, s_totalRewardSharesSnapshots.latest() + delta);
            s_totalStakedSharesSnapshots.push(snapshotId, s_totalStakedSharesSnapshots.latest() + delta);
        }

        emit RewardsReinvested(vaultRewards, vaultToken);
    }

    /**
     * @notice Processes rewards for a specific token holder
     * @param user The address of the token holder
     * @param snapshotId The id of the snapshot to use
     * @param magnifiedRewardPerShare The magnified reward amount per share
     * @param rewardToken The address of the reward token
     * @return earnedReward The amount of rewards withdrawn
     */
    function _processRewardOfUser(address user, uint96 snapshotId, uint256 magnifiedRewardPerShare, address rewardToken)
        private
        returns (uint256 earnedReward)
    {
        earnedReward =
            _calculateReward(magnifiedRewardPerShare, s_balancesSnapshots[user].upperLookupRecent(snapshotId));
        if (earnedReward > 0) {
            ERC20(rewardToken).transfer(user, earnedReward);
        }
    }

    /**
     * @notice Processes rewards for a specific token holder for a specific vault
     * @param user The address of the token holder
     * @param snapshotId The id of the snapshot to use
     * @param magnifiedVaultRewardsPerShare The magnified reward amount per share
     * @param vaultToken The address of the vault token
     * @param isVaultTokenRayFi Whether the vault token is RayFi
     * @param vault The storage pointer to the vault
     * @return vaultReward The amount of rewards withdrawn
     */
    function _processVaultOfUser(
        address user,
        uint96 snapshotId,
        uint256 magnifiedVaultRewardsPerShare,
        address vaultToken,
        bool isVaultTokenRayFi,
        Vault storage vault
    ) private returns (uint256 vaultReward) {
        uint160 vaultBalanceOfUser = vault.stakersSnapshots[user].upperLookupRecent(snapshotId);
        vaultReward = _calculateReward(magnifiedVaultRewardsPerShare, vaultBalanceOfUser);
        if (vaultReward > 0) {
            if (isVaultTokenRayFi) {
                unchecked {
                    s_shareholders.set(user, s_shareholders.get(user) + vaultReward);
                    vault.stakers.set(user, vaultBalanceOfUser + vaultReward);
                    vault.stakersSnapshots[user].push(snapshotId + 1, vaultBalanceOfUser + uint160(vaultReward));
                    s_stakedBalances[user] += vaultReward;
                }
            } else {
                ERC20(vaultToken).transfer(user, vaultReward);
            }
        }
    }

    ///////////////////////////////
    // Private Pure Functions    //
    ///////////////////////////////

    /**
     * @dev Low-level function to de-magnify the reward amount per share for a given balance
     * @param magnifiedRewardPerShare The magnified reward amount per share
     * @param balance The balance to use as reference
     * @return The de-magnified reward amount
     */
    function _calculateReward(uint256 magnifiedRewardPerShare, uint160 balance) private pure returns (uint256) {
        return magnifiedRewardPerShare * balance / MAGNITUDE;
    }

    /**
     * @dev Low-level function to calculate the magnified amount of reward per share
     * @dev In each distribution, there is a small amount of stablecoins not distributed,
     * the magnified amount of which is `(amount * MAGNITUDE) % totalShares`
     * With a well-chosen `MAGNITUDE`, this amount (de-magnified) can be less than 1 wei
     * We could actually keep track of the undistributed stablecoins for the next distribution,
     * but keeping track of such data on-chain costs much more than the saved stablecoins, so we do not do that
     * @param totalRewards The total amount of rewards
     * @param totalShares The total amount of shares
     * @return The magnified amount of reward per share
     */
    function _calculateRewardPerShare(uint256 totalRewards, uint256 totalShares) private pure returns (uint256) {
        return totalRewards * MAGNITUDE / totalShares;
    }
}