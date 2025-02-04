// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

/**
 * @title LaunchPadData
 * @dev This contract contains all the data structures, enums, and events used by the LaunchPad contracts.
 */
contract LaunchPadData {
    address public signer;

    struct Project {
        address projectOwner; // Owner of the project
        address saleToken; // Token being sold
        address paymentToken; // Token used for payment
        uint256 minCap; // Minimum cap in saleToken units
        uint256 totalSaleTokens; // Total tokens available for sale
    }

    struct ProjectInfo {
        address projectOwner; // Owner of the project
        address saleToken; // Token being sold
        address paymentToken; // Token used for payment
        uint256 minCap; // Minimum cap in saleToken units
        uint256 totalSaleTokens; // Total tokens available for sale
        uint256 totalTokensSold; // Total tokens sold
        uint256 totalAmountMade; // Total amount made in payment tokens
        uint256 claimStartTime; // Claim start time
        bool isReachedMinCap; // Indicates if the minimum cap has been reached
        bool isSaleEnded; // Indicates if the sale has ended
        bool isClaimStarted; // Indicates if the claim process has started
    }

    /// @notice Mapping of project ID to Project Infos
    mapping(uint256 => ProjectInfo) public projectInfos;

    /// @notice Represents a tiered sale for a project
    struct TiersInfo {
        uint256 startTime; // Tiered sale start time
        uint256 endTime; // Tiered sale end time
        uint256 tokenPrice; // Token prices for 4 tiers, diamond, gold, silver, bronze
        uint256[4] maxAllowed; // Max tokens allowed per tier, diamond, gold, silver, bronze
    }

    /// @notice Mapping of project ID to Project Tier Infos
    mapping(uint256 => TiersInfo) public tiersInfos;

    /// @notice Represents a public sale for a project
    struct PublicSaleInfo {
        uint256 tokenPrice; // Public sale token price
        uint256 startTime; // Public sale start time
        uint256 endTime; // Public sale end time
    }

    /// @notice Mapping of project ID to Project Public Sale Infos
    mapping(uint256 => PublicSaleInfo) public publicSalesInfo;

    /// @notice Represents a vesting schedule for a project
    struct VestingInfo {
        bool isSet; // Indicates if the vesting schedule is set
        uint256[] percentages; // Percentages vested at each interval
        uint256[] intervals; // Time intervals in seconds
    }

    /// @notice Mapping of project ID to vesting schedule
    mapping(uint256 => VestingInfo) public vestingsInfo;

    /// @notice First Come, First Serve
    struct GTDInfo {
        uint256 startTime; // FCFS start time
        uint256 endTime; // FCFS end time
    }

    /// @notice Mapping of project ID to Project FCFS Infos
    mapping(uint256 => GTDInfo) public gtdsInfos;

    /// @notice Mapping of tier index to required staking amount
    mapping(uint256 => uint256) internal requiredStakingPerTier;

    /// @notice Mapping of project ID to user address to contribution amount in payment tokens
    mapping(uint256 => mapping(address => uint256)) public contributions;

    /// @notice Mapping of project ID to user address to eligible claim amount in sale tokens
    mapping(uint256 => mapping(address => uint256)) public shares;

    /// @notice Mapping of project ID to user address to amount of tokens claimed during vesting
    mapping(uint256 => mapping(address => uint256)) public tokensClaimed;

    /// @notice Mapping of projectId, user address, and claimable timestamps
    mapping(uint256 => mapping(address => uint256[])) public vestingSchedule;

    /// @notice Mapping of projectId, user address, and claimable amounts
    mapping(uint256 => mapping(address => uint256[])) public vestingAmounts;

    /// @notice Mapping of projectId, user address, and claim statuses
    mapping(uint256 => mapping(address => bool[])) public vestingClaimed;

    /// @notice Mapping of projectId, user address, whitelist amount
    mapping(uint256 => mapping(address => uint256)) public whitelistAmount;

    /// @notice The total number of projects created
    uint256 public projectCount;

    /// @notice Platform fee percentage
    uint256 public fee;

    /// @notice The chain ID where the contract is deployed
    uint256 public chainId;

    /// @notice Address of the staking contract
    address public stakingContract;

    /// @notice Emitted when a new project is created
    event ProjectCreated(
        uint256 indexed projectId,
        address indexed projectOwner,
        address saleToken,
        address paymentToken,
        uint256 minCap,
        uint256 totalSaleTokens,
        uint256 publicSaleTokenPrice,
        uint256 publicSaleStartTime,
        uint256 publicSaleEndTime,
        uint256 chainId,
        uint256 tierSaleStartTime,
        uint256 tierSaleEndTime
    );

    /// @notice Emitted when tokens are purchased
    event TokensPurchased(
        uint256 indexed projectId,
        address indexed buyer,
        uint256 amount0,
        uint256 amount1,
        bool reachedMinCap,
        uint256 tokenSold,
        uint256 amountMade,
        uint256 chainId
    );

    /// @notice Emitted when tokens are claimed
    event TokensClaimed(
        uint256 indexed projectId,
        address indexed buyer,
        uint256 amount,
        uint256 chainId
    );

    /// @notice Emitted when a sale ends
    event SaleEnded(uint256 indexed projectId, uint256 chainId);

    /// @notice Emitted when an emergency withdrawal is performed
    event EmergencyWithdraw(
        uint256 indexed projectId,
        address indexed user,
        uint256 chainId
    );

    /// @notice Emitted when a refund is claimed
    event RefundClaimed(
        uint256 indexed projectId,
        address indexed user,
        uint256 amount,
        uint256 chainId
    );

    /// @notice Emitted when the public sale end time is updated
    event PublicSaleEndTimeUpdated(
        uint256 indexed projectId,
        uint256 newEndTime,
        uint256 chainId
    );

    /// @notice Emitted when the claim process starts
    event ClaimStarted(
        uint256 indexed projectId,
        uint256 claimTime,
        uint256 chainId
    );

    /// @notice Emitted when the vesting schedule is updated
    event VestingScheduleUpdated(
        uint256 indexed projectId,
        uint256 chainId,
        uint256[] percentages,
        uint256[] intervals
    );

    /// @notice Saletype opted by user when buying tokens
    enum SaleType {
        GTD,
        TIER,
        WHITELIST,
        PUBLIC
    }

    /// @notice Emitted when signer changed
    event SignerUpdated(address signer, uint256 chainId);

    /// @notice Emitted when updated Fee
    event FeeUpdated(uint256 fee, uint256 chainId);

    /// @notice Emitted when staking contract updated
    event StakingContractUpdated(address stakingContract, uint256 chainId);

    /// @notice Emitted when staking tier requirements updated
    event StakingTierRequirementsUpdated(
        uint256 tier,
        uint256 requiredStake,
        uint256 chainId
    );
}
