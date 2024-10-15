// SPDX-License-Identifier: MIT


/**

    ░██████╗███████╗░█████╗░████████╗░░██████╗░░█████╗░████████╗
    ██╔════╝██╔════╝██╔══██╗╚══██╔══╝░░██╔══██╗██╔══██╗╚══██╔══╝
    ╚█████╗░█████╗░░██║░░╚═╝░░░██║░░░░░██████╦╝██║░░██║░░░██║░░░
    ░╚═══██╗██╔══╝░░██║░░██╗░░░██║░░░░░██╔══██╗██║░░██║░░░██║░░░
    ██████╔╝███████╗╚█████╔╝░░░██║░░░░░██████╦╝╚█████╔╝░░░██║░░░
    ╚═════╝░╚══════╝░╚════╝░░░░╚═╝░░░░░╚═════╝░░╚════╝░░░░╚═╝░░░
    ░░░███████╗████████╗░█████╗░██╗░░██╗██╗███╗░░░██╗░██████╗░░░  
    ░░░██╔════╝╚══██╔══╝██╔══██╗██║░██╔╝██║████╗░░██║██╔════╝░░░  
    ░░░███████╗░░░██║░░░███████║█████╔╝░██║██╔██╗░██║██║░░███╗░░ 
    ░░░╚════██║░░░██║░░░██╔══██║██╔═██╗░██║██║╚██╗██║██║░░░██║░░
    ░░░███████║░░░██║░░░██║░░██║██║░░██╗██║██║░╚████║╚██████╔╝░░    
    ░░░╚══════╝░░░╚═╝░░░╚═╝░░╚═╝╚═╝░░╚═╝╚═╝╚═╝░░╚═══╝░╚═════╝░░░

    Official Telegram: https://t.me/SectTokenPortal
    Official Twitter: https://twitter.com/thesectbot
    Official Website: https://sectbot.com
    Official Whitepaper: https://sectbot.gitbook.io/sect-bot-whitepaper/
    
    Add SectBot to your group now: https://t.me/sectleaderboardbot
**/

pragma solidity 0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";


contract SectStaking is Ownable, ReentrancyGuard {
    //Fit vars into 2 slots
    struct UserInfo {
        uint128 shares; // shares of token staked
        uint128 userRewardPerTokenPaid; // user reward per token paid
        uint128 rewards; // pending rewards
        uint64 lastLockBlock; // last block when user locked
        uint64 lastLockTimestamp; // last timestamp when user locked. For easier readability
    }
    
    //Fit vars into 1 slot
    struct PackageInfo {
        uint128 totalLockedShares;
        uint64 minLockPeriodInBlocks;
        uint8 id;
        uint8 isActive;
        uint8 multiplier; //
    }

    // Precision factor for calculating rewards and exchange rate
    uint256 public constant PRECISION_FACTOR = 10**18;

    // The staking and reward tokens. Intended to be the same
    IERC20 public immutable sectToken;
    IERC20 public immutable rewardToken;

    //Fit into 3 slots

    // Total rewards deposited. For tracking purposes
    uint256 public totalRewardsForDistribution;

    // Reward rate (block)
    uint128 public currentRewardPerBlock;

    // Last update block for rewards
    uint64 public lastUpdateBlock;
    
    // Current end block for the current reward period
    uint64 public periodEndBlock;

    // Reward per token stored
    uint128 public rewardPerTokenStored;

    // Total existing shares
    uint256 public totalShares;

    // Minimum claim amount
    uint256 public minClaimAmount = 1 ether;

    // Owner
    address internal _owner;

    // Users info mapped for each package
    mapping(address => mapping(uint8 => UserInfo)) internal userInfo;
    // Packages info mapping
    mapping(uint8 => PackageInfo) public packageInfo;
    // Packages ids array
    uint8[] public packageIds;

    event Deposit(address indexed user, uint256 amount);
    event Claim(address indexed user, uint256 claimedAmount);
    event Withdraw(address indexed user, uint256 amount, uint256 claimedAmount);
    event NewRewardPeriod(uint256 numberBlocks, uint256 rewardPerBlock, uint256 reward);
    event AddMoreRewards(uint256 reward);
    event CreatePackage(uint8 id, bool _isActive, uint8 multiplier, uint64 minLockPeriodInBlocks);
    event SetPackageIsActive(uint8 packageId, bool isActive);
    event SetMinClaimAmount(uint256 minClaimAmount);

    /**
     * @notice Constructor
     * @param _sectToken address of the token staked (SECT)
     * @param _rewardToken address of the reward token
     */
    constructor(
        address _sectToken,
        address _rewardToken
    ) Ownable(msg.sender) {
        _owner = msg.sender;
        rewardToken = IERC20(_rewardToken);
        sectToken = IERC20(_sectToken);

        uint64 thirtyDaysInBlocks = 30 * 7170; 

        createPackage(10, true, 1, thirtyDaysInBlocks);
        createPackage(20, true, 2, thirtyDaysInBlocks * 2);
        createPackage(30, true, 4, thirtyDaysInBlocks * 4);
    }

    /**
     * @notice modifier
     * @notice Only the SECT token contract can call functions with this modifier
     */
    modifier onlyTokenContract() {
        require(address(sectToken) == msg.sender, "Caller is not SECT Token");
        _;
    }

    /**
     * @notice Create a new package
     * @param _id package id
     * @param _isActive whether the package is active
     * @param _multiplier multiplier for the package
     * @param _minLockPeriodInBlocks minimum lock period in blocks
     */
    function createPackage(uint8 _id, bool _isActive, uint8 _multiplier, uint64 _minLockPeriodInBlocks) public onlyOwner {
        packageInfo[_id] = PackageInfo({
            id: _id,
            isActive: _isActive ? 1 : 0,
            totalLockedShares: 0,
            multiplier: _multiplier,
            minLockPeriodInBlocks: _minLockPeriodInBlocks
        });
        packageIds.push(_id);

        emit CreatePackage(_id, _isActive, _multiplier, _minLockPeriodInBlocks);
    }

    /**
     * @notice Set package as active or inactive
     * @param packageId package id
     * @param isActive whether the package is active
     */
    function setPackageIsActive(uint8 packageId, bool isActive) external onlyOwner {
        packageInfo[packageId].isActive = isActive ? 1 : 0;

        emit SetPackageIsActive(packageId, isActive);
    }

    /**
     * @notice Get user stakes for all packages
     * @param user address of the user
     */
    function getUsersStakes(address user) external view returns (UserInfo[] memory) {
        return _getUsersStakes(user);
    }

    /**
     * @notice Get user stakes for all packages
     * @param user address of the user
     */
    function _getUsersStakes(address user) internal view returns (UserInfo[] memory) {
        UserInfo[] memory userStakes = new UserInfo[](packageIds.length);

        for (uint8 i = 0; i < packageIds.length; i++) {
            userStakes[i] = userInfo[user][packageIds[i]];
            userStakes[i].rewards = uint128(_calculatePendingRewards(user, packageIds[i]));
        }

        return userStakes;
    }

    /**
     * @notice Get user stakes for a specific package
     * @param user address of the user
     * @param packageKey package id
     */
    function getUserStakesForPackage(address user, uint8 packageKey) external view returns (UserInfo memory) {
        UserInfo memory userStake = userInfo[user][packageKey];
        userStake.rewards = uint128(_calculatePendingRewards(user, packageKey));

        return userStake;
    }

    /**
     * @notice Get all packages
     */
    function getPackages() external view returns (PackageInfo[] memory) {
        return _getPackages();
    }

    /**
     * @notice Get all packages
     */
    function _getPackages() internal view returns (PackageInfo[] memory) {
        PackageInfo[] memory packages = new PackageInfo[](packageIds.length);

        for (uint8 i = 0; i < packageIds.length; i++) {
            packages[i] = packageInfo[packageIds[i]];
        }

        return packages;
    }

    /**
     * @notice Get a specific package
     * @param packageKey package id
     */
    function getPackage(uint8 packageKey) external view returns (PackageInfo memory) {
        return packageInfo[packageKey];
    }

    /**
     * @notice make a staking deposit
     * @param amount amount to deposit
     * @param packageId package id
     * @dev Non-reentrant
     */
    function deposit(uint256 amount, uint8 packageId) external nonReentrant() {
        require(amount >= PRECISION_FACTOR, "Deposit: Amount must be >= 1 SECT");
        require(packageInfo[packageId].id != 0, "Deposit: Package does not exist");
        require(userInfo[msg.sender][packageId].shares == 0, "Deposit: User already has locked in this package");
        require(packageInfo[packageId].isActive == 1, "Deposit: Package is not active");

        // Update reward for user
        _updateReward(msg.sender);

        // Transfer SECT tokens to this address
        sectToken.transferFrom(msg.sender, address(this), amount);

        uint256 currentShares;

        // Calculate the number of shares to issue for the user
        if (totalShares != 0) {
            currentShares = (amount * totalShares) / totalShares;
            // This is a sanity check to prevent deposit for 0 shares
            require(currentShares != 0, "Deposit: Fail");
        } else {
            currentShares = amount;
        }

        currentShares *= packageInfo[packageId].multiplier;

        // Adjust internal shares
        userInfo[msg.sender][packageId].shares += uint128(currentShares);
        userInfo[msg.sender][packageId].lastLockBlock = uint64(block.number);
        userInfo[msg.sender][packageId].lastLockTimestamp = uint64(block.timestamp);
        packageInfo[packageId].totalLockedShares += uint128(currentShares);
        totalShares += currentShares;

        emit Deposit(msg.sender, amount);
    }

    /**
     * @notice Withdraw staked tokens (and collect reward tokens if requested)
     * @param shares shares to withdraw
     * @param claimRewardToken whether to claim reward tokens
     */
    function withdraw(uint256 shares, uint8 packageId, bool claimRewardToken) external {
        require(
            (shares > 0) && (shares <= userInfo[msg.sender][packageId].shares),
            "Withdraw: Shares equal to 0 or larger than user shares"
        );

        _withdraw(shares, packageId, claimRewardToken);
    }

    /**
     * @notice Withdraw all staked tokens (and collect reward tokens if requested)
     * @param claimRewardToken whether to claim reward tokens
     */
    function withdrawAll(uint8 packageId, bool claimRewardToken) external {
        _withdraw(userInfo[msg.sender][packageId].shares, packageId, claimRewardToken);
    }

    /**
     * @notice Update reward for a user account
     * @param _user address of the user
     */
    function _updateReward(address _user) internal {
        if (block.number != lastUpdateBlock) {
            rewardPerTokenStored = uint128(_rewardPerToken());
            lastUpdateBlock = uint64(_lastRewardBlock());
        }

        for (uint8 i = 0; i < packageIds.length; i++) {
            userInfo[_user][packageIds[i]].rewards = uint128(_calculatePendingRewards(_user, packageIds[i]));
            userInfo[_user][packageIds[i]].userRewardPerTokenPaid = uint128(rewardPerTokenStored);
        }
    }
     /**
     * @notice Calculate pending rewards (WETH) for a user
     * @param user address of the user
     */
    function calculatePendingRewards(address user, uint8 packageId) external view returns (uint256) {
        return _calculatePendingRewards(user, packageId);
    }

    /**
     * @notice Calculate pending rewards for a user
     * @param user address of the user
     */
    function _calculatePendingRewards(address user, uint8 packageId) internal view returns (uint256) {
        return
            ((userInfo[user][packageId].shares * (_rewardPerToken() - (userInfo[user][packageId].userRewardPerTokenPaid))) /
                PRECISION_FACTOR) + userInfo[user][packageId].rewards;
    }

    /**
     * @notice Return last block where rewards must be distributed
     */
    function _lastRewardBlock() internal view returns (uint256) {
        return block.number < periodEndBlock ? block.number : periodEndBlock;
    }

    /**
     * @notice Return reward per token extrenal
     */
    function rewardPerToken() external view returns (uint256) {
        return _rewardPerToken();
    }

    /**
     * @notice Return reward per token
     */
    function _rewardPerToken() internal view returns (uint256) {
        if (totalShares == 0) {
            return rewardPerTokenStored;
        }

        return
            rewardPerTokenStored +
            ((_lastRewardBlock() - lastUpdateBlock) * (currentRewardPerBlock * PRECISION_FACTOR)) /
            totalShares;
    }

    /**
     * @notice Withdraw staked tokens (and collect reward tokens if requested)
     * @param shares shares to withdraw
     * @param claimRewardToken whether to claim reward tokens
     */
    function _withdraw(uint256 shares, uint8 packageId, bool claimRewardToken) internal nonReentrant() {
        require(
            (block.number - userInfo[msg.sender][packageId].lastLockBlock) >= packageInfo[packageId].minLockPeriodInBlocks,
            "Withdraw: Minimum lock period not reached"
        );
        // Update reward for user
        _updateReward(msg.sender);

        userInfo[msg.sender][packageId].shares -= uint128(shares);
        packageInfo[packageId].totalLockedShares -= uint128(shares);
        totalShares -= shares;

        uint256 pendingRewards;

        if (claimRewardToken) {
            // Fetch pending rewards
            pendingRewards = userInfo[msg.sender][packageId].rewards;

            if (pendingRewards > 0) {
                userInfo[msg.sender][packageId].rewards = 0;
                rewardToken.transfer(msg.sender, pendingRewards);
            }
        }

        uint256 sharesToAmount = shares / packageInfo[packageId].multiplier;

        // Transfer SECT tokens to sender
        sectToken.transfer(msg.sender, sharesToAmount);

        emit Withdraw(msg.sender, sharesToAmount, pendingRewards);
    }

    /**
     * @notice Claim rewards
     * @param packageId package id
     * @dev Non-reentrant
     */
    function claim(uint8 packageId) external nonReentrant() returns(uint claimed){
        // Update reward for user
        _updateReward(msg.sender);
        require(userInfo[msg.sender][packageId].rewards >= minClaimAmount, "Claim: Insufficient rewards");

        uint256 pendingRewards = userInfo[msg.sender][packageId].rewards;

        if (pendingRewards > 0) {
            userInfo[msg.sender][packageId].rewards = 0;
            rewardToken.transfer(msg.sender, pendingRewards);
            claimed = pendingRewards;
        }

        emit Claim(msg.sender, pendingRewards);
    }

    /**
     * @notice Update the reward per block (in rewardToken)
     * @dev Only callable by owner.
     */
    function updateRewards(uint256 reward, uint256 rewardDurationInBlocks) external onlyOwner {
        require(rewardDurationInBlocks > 0, "Deposit: Reward duration must be > 0");

        // Adjust the current reward per block
        if (block.number >= periodEndBlock) {            
            currentRewardPerBlock = uint128(reward / rewardDurationInBlocks);
        } else {
            currentRewardPerBlock = uint128(
                (reward + ((periodEndBlock - block.number) * currentRewardPerBlock)) /
                rewardDurationInBlocks);
        }

        require(currentRewardPerBlock > 0, "Deposit: Reward per block must be > 0");

        lastUpdateBlock = uint64(block.number);
        periodEndBlock = uint64(block.number + rewardDurationInBlocks);
        totalRewardsForDistribution = reward;

        emit NewRewardPeriod(rewardDurationInBlocks, currentRewardPerBlock, reward);
    }

    /**
     * @notice Add more rewards to the pool
     * @param reward amount of reward tokens to add
     * @dev Only callable by owner.
     */
    function addRewards(uint256 reward) external onlyOwner nonReentrant(){
        require(periodEndBlock > block.number, "Deposit: Reward period ended");
        require(reward > (periodEndBlock - block.number), "Deposit: Reward must be > 0");
        rewardToken.transferFrom(msg.sender, address(this), reward);

        if (block.number != lastUpdateBlock) {
            rewardPerTokenStored = uint128(_rewardPerToken());
            lastUpdateBlock = uint64(_lastRewardBlock());
        }

        unchecked {
            totalRewardsForDistribution += reward;
            currentRewardPerBlock += uint128(reward / (periodEndBlock - block.number));
        }
        emit AddMoreRewards(reward);
    }

    /**
     * @notice Deposit rewards
     * @param reward amount of reward tokens to deposit
     * @dev Only callable by the SECT token contract.
     */
    function depositRewards(uint256 reward) external onlyTokenContract {
        require(periodEndBlock > block.number, "Deposit: Reward period ended");
        require(reward > (periodEndBlock - block.number), "Deposit: Reward must be > 0");

        if (block.number != lastUpdateBlock) {
            rewardPerTokenStored = uint128(_rewardPerToken());
            lastUpdateBlock = uint64(_lastRewardBlock());
        }

        unchecked {
            totalRewardsForDistribution += reward;
            currentRewardPerBlock += uint128(reward / (periodEndBlock - block.number));
        }
        emit AddMoreRewards(reward);
    }

    /**
     * @notice Set the minimum claim amount
     * @param _minClaimAmount minimum claim amount
     * @dev Only callable by owner.
     */
    function setMinClaimAmount(uint256 _minClaimAmount) external onlyOwner {
        require(_minClaimAmount < 100 ether, "setMinClaimAmount: Min claim amount must be < 100 SECT");
        minClaimAmount = _minClaimAmount;

        emit SetMinClaimAmount(_minClaimAmount);
    }

    /**
     * @notice Get total rewards for distribution to this block
     */
    function getTotalRewardsForDistributionToThisBlock() external view returns(uint256){
        return _getTotalRewardsForDistributionToThisBlock();
    }

    /**
     * @notice Get total rewards for distribution to this block
     */
    function _getTotalRewardsForDistributionToThisBlock() internal view returns(uint256){
        return totalRewardsForDistribution - (currentRewardPerBlock * (periodEndBlock - block.number));
    }

    /**
     * @notice Get full info for a user and packages. Useful for frontend visualization
     * @param user address of the user
     */
    function getFullInfoForUser(address user) external view returns (UserInfo[] memory, PackageInfo[] memory, uint256, uint256) {
        return (_getUsersStakes(user), _getPackages(), _getTotalRewardsForDistributionToThisBlock(), _rewardPerToken());
    }

    /**
     * @notice Get full contract info. Useful for frontend visualization
     */
    function getFullContractInfo() external view returns (PackageInfo[] memory, uint256, uint256) {
        return (_getPackages(), _getTotalRewardsForDistributionToThisBlock(), _rewardPerToken());
    }
}