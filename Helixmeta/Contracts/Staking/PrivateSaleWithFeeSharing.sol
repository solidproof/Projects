// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import {IERC20, SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/**
 * @title PrivateSaleWithFeeSharing
 * @notice It handles the private sale for HLM tokens (against ETH) and the fee-sharing
 * mechanism for sale participants. It uses a 3-tier system with different
 * costs (in ETH) to participate. The exchange rate is expressed as the price of 1 ETH in HLM token.
 * It is the same for all three tiers.
 */
contract PrivateSaleWithFeeSharing is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    enum SalePhase {
        Pending, // Pending (owner sets up parameters)
        Deposit, // Deposit (sale is in progress)
        Over, // Sale is over, prior to staking
        Staking, // Staking starts
        Withdraw // Withdraw opens
    }

    struct UserInfo {
        uint256 rewardsDistributedToAccount; // reward claimed by the sale participant
        uint8 tier; // sale tier (e.g., 1/2/3)
        bool hasDeposited; // whether the user has participated
        bool hasWithdrawn; // whether the user has withdrawn (after the end of the fee-sharing period)
    }

    // Number of eligible tiers in the private sale
    uint8 public constant NUMBER_TIERS = 3;

    IERC20 public immutable helixmetaToken;

    IERC20 public immutable rewardToken;

    // Maximum blocks for withdrawal
    uint256 public immutable MAX_BLOCK_FOR_WITHDRAWAL;

    // Total HLM expected to be distributed
    uint256 public immutable TOTAL_HLM_DISTRIBUTED;

    // Current sale phase (uint8)
    SalePhase public currentPhase;

    // Block where participants can withdraw the HLM tokens
    uint256 public blockForWithdrawal;

    // Price of WETH in HLM for the sale
    uint256 public priceOfETHInHLM;

    // Total amount committed in the sale (in ETH)
    uint256 public totalAmountCommitted;

    // Total reward tokens (i.e., WETH) distributed across stakers
    uint256 public totalRewardTokensDistributedToStakers;

    // Keeps track of the cost to join the sale for a given tier
    mapping(uint8 => uint256) public allocationCostPerTier;

    // Keeps track of the number of whitelisted participants for each tier
    mapping(uint8 => uint256) public numberOfParticipantsForATier;

    // Keeps track of user information (e.g., tier, amount collected, participation)
    mapping(address => UserInfo) public userInfo;

    event Deposit(address indexed user, uint8 tier);
    event Harvest(address indexed user, uint256 amount);
    event NewSalePhase(SalePhase newSalePhase);
    event NewAllocationCostPerTier(uint8 tier, uint256 allocationCostInETH);
    event NewBlockForWithdrawal(uint256 blockForWithdrawal);
    event NewPriceOfETHInHLM(uint256 price);
    event UsersWhitelisted(address[] users, uint8 tier);
    event UserRemoved(address user);
    event Withdraw(address indexed user, uint8 tier, uint256 amount);

    /**
     * @notice Constructor
     * @param _helixmetaToken address of the HLM token
     * @param _rewardToken address of the reward token
     * @param _maxBlockForWithdrawal maximum block for withdrawal
     * @param _totalHlmDistributed total number of HLM tokens to distribute
     */
    constructor(
        address _helixmetaToken,
        address _rewardToken,
        uint256 _maxBlockForWithdrawal,
        uint256 _totalHlmDistributed
    ) {
        require(_maxBlockForWithdrawal > block.number, "Owner: MaxBlockForWithdrawal must be after block number");

        helixmetaToken = IERC20(_helixmetaToken);
        rewardToken = IERC20(_rewardToken);
        blockForWithdrawal = _maxBlockForWithdrawal;

        MAX_BLOCK_FOR_WITHDRAWAL = _maxBlockForWithdrawal;
        TOTAL_HLM_DISTRIBUTED = _totalHlmDistributed;
    }

    /**
     * @notice Deposit ETH to this contract
     */
    function deposit() external payable nonReentrant {
        require(currentPhase == SalePhase.Deposit, "Deposit: Phase must be Deposit");
        require(userInfo[msg.sender].tier != 0, "Deposit: Not whitelisted");
        require(!userInfo[msg.sender].hasDeposited, "Deposit: Has deposited");
        require(msg.value == allocationCostPerTier[userInfo[msg.sender].tier], "Deposit: Wrong amount");

        userInfo[msg.sender].hasDeposited = true;
        totalAmountCommitted += msg.value;

        emit Deposit(msg.sender, userInfo[msg.sender].tier);
    }

    /**
     * @notice Harvest WETH
     */
    function harvest() external nonReentrant {
        require(currentPhase == SalePhase.Staking, "Harvest: Phase must be Staking");
        require(userInfo[msg.sender].hasDeposited, "Harvest: User not eligible");

        uint256 totalTokensReceived = rewardToken.balanceOf(address(this)) + totalRewardTokensDistributedToStakers;

        uint256 pendingRewardsInWETH = ((totalTokensReceived * allocationCostPerTier[userInfo[msg.sender].tier]) /
            totalAmountCommitted) - userInfo[msg.sender].rewardsDistributedToAccount;

        // Revert if amount to transfer is equal to 0
        require(pendingRewardsInWETH != 0, "Harvest: Nothing to transfer");

        userInfo[msg.sender].rewardsDistributedToAccount += pendingRewardsInWETH;
        totalRewardTokensDistributedToStakers += pendingRewardsInWETH;

        // Transfer funds to account
        rewardToken.safeTransfer(msg.sender, pendingRewardsInWETH);

        emit Harvest(msg.sender, pendingRewardsInWETH);
    }

    /**
     * @notice Withdraw HLM + pending WETH
     */
    function withdraw() external nonReentrant {
        require(currentPhase == SalePhase.Withdraw, "Withdraw: Phase must be Withdraw");
        require(userInfo[msg.sender].hasDeposited, "Withdraw: User not eligible");
        require(!userInfo[msg.sender].hasWithdrawn, "Withdraw: Has already withdrawn");

        // Final harvest logic
        {
            uint256 totalTokensReceived = rewardToken.balanceOf(address(this)) + totalRewardTokensDistributedToStakers;
            uint256 pendingRewardsInWETH = ((totalTokensReceived * allocationCostPerTier[userInfo[msg.sender].tier]) /
                totalAmountCommitted) - userInfo[msg.sender].rewardsDistributedToAccount;

            // Skip if equal to 0
            if (pendingRewardsInWETH > 0) {
                userInfo[msg.sender].rewardsDistributedToAccount += pendingRewardsInWETH;
                totalRewardTokensDistributedToStakers += pendingRewardsInWETH;

                // Transfer funds to sender
                rewardToken.safeTransfer(msg.sender, pendingRewardsInWETH);

                emit Harvest(msg.sender, pendingRewardsInWETH);
            }
        }

        // Update status to withdrawn
        userInfo[msg.sender].hasWithdrawn = true;

        // Calculate amount of HLM to transfer based on the tier
        uint256 hlmAmountToTransfer = allocationCostPerTier[userInfo[msg.sender].tier] * priceOfETHInHLM;

        // Transfer HLM token to sender
        helixmetaToken.safeTransfer(msg.sender, hlmAmountToTransfer);

        emit Withdraw(msg.sender, userInfo[msg.sender].tier, hlmAmountToTransfer);
    }

    /**
     * @notice Update sale phase to withdraw after the sale lock has passed.
     * It can called by anyone.
     */
    function updateSalePhaseToWithdraw() external {
        require(currentPhase == SalePhase.Staking, "Phase: Must be Staking");
        require(block.number >= blockForWithdrawal, "Phase: Too early to update sale status");

        // Update phase to Withdraw
        currentPhase = SalePhase.Withdraw;

        emit NewSalePhase(SalePhase.Withdraw);
    }

    /**
     * @notice Remove a user from the whitelist
     * @param _user address of the user
     */
    function removeUserFromWhitelist(address _user) external onlyOwner {
        require(currentPhase == SalePhase.Pending, "Owner: Phase must be Pending");
        require(userInfo[_user].tier != 0, "Owner: Tier not set for user");

        numberOfParticipantsForATier[userInfo[_user].tier]--;
        userInfo[_user].tier = 0;

        emit UserRemoved(_user);
    }

    /**
     * @notice Set allocation per tier
     * @param _tier tier of sale
     * @param _allocationCostInETH allocation in ETH for the tier
     */
    function setAllocationCostPerTier(uint8 _tier, uint256 _allocationCostInETH) external onlyOwner {
        require(currentPhase == SalePhase.Pending, "Owner: Phase must be Pending");
        require(_tier > 0 && _tier <= NUMBER_TIERS, "Owner: Tier outside of range");

        allocationCostPerTier[_tier] = _allocationCostInETH;

        emit NewAllocationCostPerTier(_tier, _allocationCostInETH);
    }

    /**
     * @notice Update block deadline for withdrawal of HLM
     * @param _blockForWithdrawal block for withdrawing HLM for sale participants
     */
    function setBlockForWithdrawal(uint256 _blockForWithdrawal) external onlyOwner {
        require(
            _blockForWithdrawal <= MAX_BLOCK_FOR_WITHDRAWAL,
            "Owner: Block for withdrawal must be lower than max block for withdrawal"
        );

        blockForWithdrawal = _blockForWithdrawal;

        emit NewBlockForWithdrawal(_blockForWithdrawal);
    }

    /**
     * @notice Set price of 1 ETH in HLM
     * @param _priceOfETHinHLM price of 1 ETH in HLM
     */
    function setPriceOfETHInHLM(uint256 _priceOfETHinHLM) external onlyOwner {
        require(currentPhase == SalePhase.Pending, "Owner: Phase must be Pending");
        priceOfETHInHLM = _priceOfETHinHLM;

        emit NewPriceOfETHInHLM(_priceOfETHinHLM);
    }

    /**
     * @notice Update sale phase for the first two phases
     * @param _newSalePhase SalePhase (uint8)
     */
    function updateSalePhase(SalePhase _newSalePhase) external onlyOwner {
        if (_newSalePhase == SalePhase.Deposit) {
            require(currentPhase == SalePhase.Pending, "Owner: Phase must be Pending");

            // Risk checks
            require(priceOfETHInHLM > 0, "Owner: Exchange rate must be > 0");
            require(getMaxAmountHLMToDistribute() == TOTAL_HLM_DISTRIBUTED, "Owner: Wrong amount of HLM");
            require(
                helixmetaToken.balanceOf(address(this)) >= TOTAL_HLM_DISTRIBUTED,
                "Owner: Not enough HLM in the contract"
            );
            require(blockForWithdrawal > block.number, "Owner: Block for withdrawal wrongly set");
        } else if (_newSalePhase == SalePhase.Over) {
            require(currentPhase == SalePhase.Deposit, "Owner: Phase must be Deposit");
        } else {
            revert("Owner: Cannot update to this phase");
        }

        // Update phase to the new sale phase
        currentPhase = _newSalePhase;

        emit NewSalePhase(_newSalePhase);
    }

    /**
     * @notice Withdraw the total commited amount (in ETH) and any HLM surplus.
     * It also updates the sale phase to Staking phase.
     */
    function withdrawCommittedAmount() external onlyOwner nonReentrant {
        require(currentPhase == SalePhase.Over, "Owner: Phase must be Over");

        // Transfer ETH to the owner
        (bool success, ) = msg.sender.call{value: totalAmountCommitted}("");
        require(success, "Owner: Transfer fail");

        // If some tiered users did not participate, transfer the HLM surplus to contract owner
        if (totalAmountCommitted * priceOfETHInHLM < (TOTAL_HLM_DISTRIBUTED)) {
            uint256 tokenAmountToReturnInHLM = TOTAL_HLM_DISTRIBUTED - (totalAmountCommitted * priceOfETHInHLM);
            helixmetaToken.safeTransfer(msg.sender, tokenAmountToReturnInHLM);
        }

        // Update phase status to Staking
        currentPhase = SalePhase.Staking;

        emit NewSalePhase(SalePhase.Staking);
    }

    /**
     * @notice Whitelist a list of user addresses for a given tier
     * It updates the sale phase to staking phase.
     * @param _users array of user addresses
     * @param _tier tier for the array of users
     */
    function whitelistUsers(address[] calldata _users, uint8 _tier) external onlyOwner {
        require(currentPhase == SalePhase.Pending, "Owner: Phase must be Pending");
        require(_tier > 0 && _tier <= NUMBER_TIERS, "Owner: Tier outside of range");

        for (uint256 i = 0; i < _users.length; i++) {
            require(userInfo[_users[i]].tier == 0, "Owner: Tier already set");
            userInfo[_users[i]].tier = _tier;
        }

        // Adjust count of participants for the given tier
        numberOfParticipantsForATier[_tier] += _users.length;

        emit UsersWhitelisted(_users, _tier);
    }

    /**
     * @notice Retrieve amount of reward token (WETH) a user can collect
     * @param user address of the user who participated in the private sale
     */
    function calculatePendingRewards(address user) external view returns (uint256) {
        if (userInfo[user].hasDeposited == false || userInfo[user].hasWithdrawn) {
            return 0;
        }

        uint256 totalTokensReceived = rewardToken.balanceOf(address(this)) + totalRewardTokensDistributedToStakers;
        uint256 pendingRewardsInWETH = ((totalTokensReceived * allocationCostPerTier[userInfo[user].tier]) /
            totalAmountCommitted) - userInfo[user].rewardsDistributedToAccount;

        return pendingRewardsInWETH;
    }

    /**
     * @notice Retrieve max amount to distribute (in HLM) for sale
     */
    function getMaxAmountHLMToDistribute() public view returns (uint256 maxAmountCollected) {
        for (uint8 i = 1; i <= NUMBER_TIERS; i++) {
            maxAmountCollected += (allocationCostPerTier[i] * numberOfParticipantsForATier[i]);
        }

        return maxAmountCollected * priceOfETHInHLM;
    }
}