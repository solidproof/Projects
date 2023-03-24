// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

// interfaces
import "@openzeppelin/contracts/interfaces/IERC20.sol";

interface IFarmingRange {
    /**
     * @notice Info of each user.
     * @param amount How many Staking tokens the user has provided.
     * @param rewardDebt We do some fancy math here. Basically, any point in time, the amount of reward
     *  entitled to a user but is pending to be distributed is:
     *
     *    pending reward = (user.amount * pool.accRewardPerShare) - user.rewardDebt
     *
     *  Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
     *    1. The pool's `accRewardPerShare` (and `lastRewardBlock`) gets updated.
     *    2. User receives the pending reward sent to his/her address.
     *    3. User's `amount` gets updated.
     *    4. User's `rewardDebt` gets updated.
     *
     * from: https://github.com/jazz-defi/contracts/blob/master/MasterChefV2.sol
     */
    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    /**
     * @notice Info of each reward distribution campaign.
     * @param stakingToken address of Staking token contract.
     * @param rewardToken address of Reward token contract
     * @param startBlock start block of the campaign
     * @param lastRewardBlock last block number that Reward Token distribution occurs.
     * @param accRewardPerShare accumulated Reward Token per share, times 1e20.
     * @param totalStaked total staked amount each campaign's stake token, typically,
     * @param totalRewards total amount of reward to be distributed until the end of the last phase
     *
     * @dev each campaign has the same stake token, so no need to track it separetely
     */
    struct CampaignInfo {
        IERC20 stakingToken;
        IERC20 rewardToken;
        uint256 startBlock;
        uint256 lastRewardBlock;
        uint256 accRewardPerShare;
        uint256 totalStaked;
        uint256 totalRewards;
    }

    /**
     * @notice Info about a reward-phase
     * @param endBlock block number of the end of the phase
     * @param rewardPerBlock amount of reward to be distributed per block in this phase
     */
    struct RewardInfo {
        uint256 endBlock;
        uint256 rewardPerBlock;
    }

    /**
     * @notice emitted at each deposit
     * @param user address that deposit its funds
     * @param amount amount deposited
     * @param campaign campaingId on which the user has deposited funds
     */
    event Deposit(address indexed user, uint256 amount, uint256 campaign);

    /**
     * @notice emitted at each withdraw
     * @param user address that withdrawn its funds
     * @param amount amount withdrawn
     * @param campaign campaingId on which the user has withdrawn funds
     */
    event Withdraw(address indexed user, uint256 amount, uint256 campaign);

    /**
     * @notice emitted at each emergency withdraw
     * @param user address that emergency-withdrawn its funds
     * @param amount amount emergency-withdrawn
     * @param campaign campaingId on which the user has emergency-withdrawn funds
     */
    event EmergencyWithdraw(address indexed user, uint256 amount, uint256 campaign);

    /**
     * @notice emitted at each campaign added
     * @param campaignID new campaign id
     * @param stakingToken token address to be staked in this campaign
     * @param rewardToken token address of the rewards in this campaign
     * @param startBlock starting block of this campaign
     */
    event AddCampaignInfo(uint256 indexed campaignID, IERC20 stakingToken, IERC20 rewardToken, uint256 startBlock);

    /**
     * @notice emitted at each phase of reward added
     * @param campaignID campaign id on which rewards were added
     * @param phase number of the new phase added (latest at the moment of add)
     * @param endBlock number of the block that the phase stops (phase starts at the endblock of the previous phase's
     * endblock, and if it's the phase 0, it start at the startBlock of the campaign struct)
     * @param rewardPerBlock amount of reward distributed per block in this phase
     */
    event AddRewardInfo(uint256 indexed campaignID, uint256 indexed phase, uint256 endBlock, uint256 rewardPerBlock);

    /**
     * @notice emitted when a reward phase is updated
     * @param campaignID campaign id on which the rewards-phase is updated
     * @param phase id of phase updated
     * @param endBlock new endblock of the phase
     * @param rewardPerBlock new rewardPerBlock of the phase
     */
    event UpdateRewardInfo(uint256 indexed campaignID, uint256 indexed phase, uint256 endBlock, uint256 rewardPerBlock);

    /**
     * @notice emitted when a reward phase is removed
     * @param campaignID campaign id on which the rewards-phase is removed
     * @param phase id of phase removed (only the latest phase can be removed)
     */
    event RemoveRewardInfo(uint256 indexed campaignID, uint256 indexed phase);

    /**
     * @notice emitted when the rewardInfoLimit is updated
     * @param rewardInfoLimit new max phase amount per campaign
     */
    event SetRewardInfoLimit(uint256 rewardInfoLimit);

    /**
     * @notice emitted when the rewardManager is changed
     * @param rewardManager address of the new rewardManager
     */
    event SetRewardManager(address rewardManager);

    /**
     * @notice increase precision of accRewardPerShare in all campaign
     */
    function upgradePrecision() external;

    /**
     * @notice set the reward manager, responsible for adding rewards
     * @param _rewardManager address of the reward manager
     */
    function setRewardManager(address _rewardManager) external;

    /**
     * @notice set new reward info limit, defining how many phases are allowed
     * @param _updatedRewardInfoLimit new reward info limit
     */
    function setRewardInfoLimit(uint256 _updatedRewardInfoLimit) external;

    /**
     * @notice reward campaign, one campaign represent a pair of staking and reward token,
     * last reward Block and acc reward Per Share
     * @param _stakingToken staking token address
     * @param _rewardToken reward token address
     * @param _startBlock block number when the campaign will start
     */
    function addCampaignInfo(IERC20 _stakingToken, IERC20 _rewardToken, uint256 _startBlock) external;

    /**
     * @notice add a nex reward info, when a new reward info is added, the reward
     * & its end block will be extended by the newly pushed reward info.
     * @param _campaignID id of the campaign
     * @param _endBlock end block of this reward info
     * @param _rewardPerBlock reward per block to distribute until the end
     */
    function addRewardInfo(uint256 _campaignID, uint256 _endBlock, uint256 _rewardPerBlock) external;

    /**
     * @notice add multiple reward Info into a campaign in one tx.
     * @param _campaignID id of the campaign
     * @param _endBlock array of end blocks
     * @param _rewardPerBlock array of reward per block
     */
    function addRewardInfoMultiple(
        uint256 _campaignID,
        uint256[] calldata _endBlock,
        uint256[] calldata _rewardPerBlock
    ) external;

    /**
     * @notice update one campaign reward info for a specified range index.
     * @param _campaignID id of the campaign
     * @param _rewardIndex index of the reward info
     * @param _endBlock end block of this reward info
     * @param _rewardPerBlock reward per block to distribute until the end
     */
    function updateRewardInfo(
        uint256 _campaignID,
        uint256 _rewardIndex,
        uint256 _endBlock,
        uint256 _rewardPerBlock
    ) external;

    /**
     * @notice update multiple campaign rewards info for all range index.
     * @param _campaignID id of the campaign
     * @param _rewardIndex array of reward info index
     * @param _endBlock array of end block
     * @param _rewardPerBlock array of rewardPerBlock
     */
    function updateRewardMultiple(
        uint256 _campaignID,
        uint256[] memory _rewardIndex,
        uint256[] memory _endBlock,
        uint256[] memory _rewardPerBlock
    ) external;

    /**
     * @notice update multiple campaigns and rewards info for all range index.
     * @param _campaignID array of campaign id
     * @param _rewardIndex multi dimensional array of reward info index
     * @param _endBlock multi dimensional array of end block
     * @param _rewardPerBlock multi dimensional array of rewardPerBlock
     */
    function updateCampaignsRewards(
        uint256[] calldata _campaignID,
        uint256[][] calldata _rewardIndex,
        uint256[][] calldata _endBlock,
        uint256[][] calldata _rewardPerBlock
    ) external;

    /**
     * @notice remove last reward info for specified campaign.
     * @param _campaignID campaign id
     */
    function removeLastRewardInfo(uint256 _campaignID) external;

    /**
     * @notice return the entries amount of reward info for one campaign.
     * @param _campaignID campaign id
     * @return reward info quantity
     */
    function rewardInfoLen(uint256 _campaignID) external view returns (uint256);

    /**
     * @notice return the number of campaigns.
     * @return campaign quantity
     */
    function campaignInfoLen() external view returns (uint256);

    /**
     * @notice return the end block of the current reward info for a given campaign.
     * @param _campaignID campaign id
     * @return reward info end block number
     */
    function currentEndBlock(uint256 _campaignID) external view returns (uint256);

    /**
     * @notice return the reward per block of the current reward info for a given campaign.
     * @param _campaignID campaign id
     * @return current reward per block
     */
    function currentRewardPerBlock(uint256 _campaignID) external view returns (uint256);

    /**
     * @notice Return reward multiplier over the given _from to _to block.
     * Reward multiplier is the amount of blocks between from and to
     * @param _from start block number
     * @param _to end block number
     * @param _endBlock end block number of the reward info
     * @return block distance
     */
    function getMultiplier(uint256 _from, uint256 _to, uint256 _endBlock) external returns (uint256);

    /**
     * @notice View function to retrieve pending Reward.
     * @param _campaignID pending reward of campaign id
     * @param _user address to retrieve pending reward
     * @return current pending reward
     */
    function pendingReward(uint256 _campaignID, address _user) external view returns (uint256);

    /**
     * @notice Update reward variables of the given campaign to be up-to-date.
     * @param _campaignID campaign id
     */
    function updateCampaign(uint256 _campaignID) external;

    /**
     * @notice Update reward variables for all campaigns. gas spending is HIGH in this method call, BE CAREFUL.
     */
    function massUpdateCampaigns() external;

    /**
     * @notice Deposit staking token in a campaign.
     * @param _campaignID campaign id
     * @param _amount amount to deposit
     */
    function deposit(uint256 _campaignID, uint256 _amount) external;

    /**
     * @notice Deposit staking token in a campaign with the EIP-2612 signature off chain
     * @param _campaignID campaign id
     * @param _amount amount to deposit
     * @param _approveMax Whether or not the approval amount in the signature is for liquidity or uint(-1).
     * @param _deadline Unix timestamp after which the transaction will revert.
     * @param _v The v component of the permit signature.
     * @param _r The r component of the permit signature.
     * @param _s The s component of the permit signature.
     */
    function depositWithPermit(
        uint256 _campaignID,
        uint256 _amount,
        bool _approveMax,
        uint256 _deadline,
        uint8 _v,
        bytes32 _r,
        bytes32 _s
    ) external;

    /**
     * @notice Withdraw staking token in a campaign. Also withdraw the current pending reward
     * @param _campaignID campaign id
     * @param _amount amount to withdraw
     */
    function withdraw(uint256 _campaignID, uint256 _amount) external;

    /**
     * @notice Harvest campaigns, will claim rewards token of every campaign ids in the array
     * @param _campaignIDs array of campaign id
     */
    function harvest(uint256[] calldata _campaignIDs) external;

    /**
     * @notice Withdraw without caring about rewards. EMERGENCY ONLY.
     * @param _campaignID campaign id
     */
    function emergencyWithdraw(uint256 _campaignID) external;

    /**
     * @notice get Reward info for a campaign ID and index, that is a set of {endBlock, rewardPerBlock}
     *  indexed by campaign ID
     * @param _campaignID campaign id
     * @param _rewardIndex index of the reward info
     * @return endBlock_ end block of this reward info
     * @return rewardPerBlock_ reward per block to distribute
     */
    function campaignRewardInfo(
        uint256 _campaignID,
        uint256 _rewardIndex
    ) external view returns (uint256 endBlock_, uint256 rewardPerBlock_);

    /**
     * @notice get a Campaign Reward info for a campaign ID
     * @param _campaignID campaign id
     * @return all params from CampaignInfo struct
     */
    function campaignInfo(
        uint256 _campaignID
    ) external view returns (IERC20, IERC20, uint256, uint256, uint256, uint256, uint256);

    /**
     * @notice get a User Reward info for a campaign ID and user address
     * @param _campaignID campaign id
     * @param _user user address
     * @return all params from UserInfo struct
     */
    function userInfo(uint256 _campaignID, address _user) external view returns (uint256, uint256);

    /**
     * @notice how many reward phases can be set for a campaign
     * @return rewards phases size limit
     */
    function rewardInfoLimit() external view returns (uint256);

    /**
     * @notice get reward Manager address holding rewards to distribute
     * @return address of reward manager
     */
    function rewardManager() external view returns (address);
}
