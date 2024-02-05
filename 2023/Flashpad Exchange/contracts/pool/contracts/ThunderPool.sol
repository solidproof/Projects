// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;
pragma abicoder v2;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./interfaces/INFTHandler.sol";
import "./interfaces/INFTPool.sol";
import "./interfaces/IThunderPoolFactory.sol";
import "./interfaces/tokens/IFlashToken.sol";
import "./interfaces/tokens/IXFlashToken.sol";
import "./interfaces/IThunderCustomReq.sol";


contract ThunderPool is ReentrancyGuard, Ownable, INFTHandler {
    using EnumerableSet for EnumerableSet.UintSet;
    using EnumerableSet for EnumerableSet.AddressSet;
    using SafeERC20 for IERC20;
    using SafeERC20 for IXFlashToken;
    using SafeERC20 for IFlashToken;
    using SafeMath for uint256;

    struct UserInfo {
        uint256 totalDepositAmount; // Save total deposit amount
        uint256 rewardDebtToken1;
        uint256 rewardDebtToken2;
        uint256 pendingRewardsToken1; // can't be harvested before harvestStartTime
        uint256 pendingRewardsToken2; // can't be harvested before harvestStartTime
    }

    struct Settings {
        uint256 startTime; // Start of rewards distribution
        uint256 endTime; // End of rewards distribution
        uint256 harvestStartTime; // (optional) Time at which stakers will be allowed to harvest their rewards
        uint256 depositEndTime; // (optional) Time at which deposits won't be allowed anymore
        uint256 lockDurationReq; // (optional) required lock duration for positions
        uint256 lockEndReq; // (optional) required lock end time for positions
        uint256 depositAmountReq; // (optional) required deposit amount for positions
        bool whitelist; // (optional) to only allow whitelisted users to deposit
        string description; // Project's description for this ThunderPool
    }

    struct RewardsToken {
        IERC20 token;
        uint256 amount; // Total rewards to distribute
        uint256 remainingAmount; // Remaining rewards to distribute
        uint256 accRewardsPerShare;
    }

    struct WhitelistStatus {
        address account;
        bool status;
    }

    bytes4 private constant _ERC721_RECEIVED = 0x150b7a02;

    IThunderPoolFactory public factory; // ThunderPoolFactory address
    IFlashToken public flashToken; // FLASHToken contract
    IXFlashToken public xFlashToken; // xFLASHToken contract
    INFTPool public nftPool; // NFTPool contract
    IThunderCustomReq public customReqContract; // (optional) external contracts allow to handle custom requirements

    uint256 public creationTime; // Creation time of this ThunderPool

    bool public published; // Is ThunderPool published
    uint256 public publishTime; // Time at which the ThunderPool was published

    bool public emergencyClose; // When activated, can't distribute rewards anymore

    RewardsToken public rewardsToken1; // rewardsToken1 data
    RewardsToken public rewardsToken2; // (optional) rewardsToken2 data

    // pool info
    uint256 public totalDepositAmount;
    uint256 public lastRewardTime;

    mapping(address => UserInfo) public userInfo;
    mapping(uint256 => address) public tokenIdOwner; // save tokenId previous owner
    mapping(address => EnumerableSet.UintSet) private _userTokenIds; // save previous owner tokenIds

    EnumerableSet.AddressSet private _whitelistedUsers; // whitelisted users
    Settings public settings; // global and requirements settings

    constructor(
        IFlashToken flashToken_, IXFlashToken xFlashToken_, address owner_, INFTPool nftPool_,
        IERC20 rewardsToken1_, IERC20 rewardsToken2_, Settings memory settings_
    ) {
        require(address(flashToken_) != address(0) && address(xFlashToken_) != address(0) && owner_ != address(0)
            && address(nftPool_) != address(0) && address(rewardsToken1_) != address(0), "zero address");
        require(_currentBlockTimestamp() < settings_.startTime, "invalid startTime");
        require(settings_.startTime < settings_.endTime, "invalid endTime");
        require(settings_.depositEndTime == 0 || settings_.startTime <= settings_.depositEndTime, "invalid depositEndTime");
        require(settings_.harvestStartTime == 0 || settings_.startTime <= settings_.harvestStartTime, "invalid harvestStartTime");
        require(address(rewardsToken1_) != address(rewardsToken2_), "invalid tokens");

        factory = IThunderPoolFactory(msg.sender);

        flashToken = flashToken_;
        xFlashToken = xFlashToken_;
        nftPool = nftPool_;
        creationTime = _currentBlockTimestamp();

        rewardsToken1.token = rewardsToken1_;
        rewardsToken2.token = rewardsToken2_;

        settings.startTime = settings_.startTime;
        settings.endTime = settings_.endTime;
        lastRewardTime = settings_.startTime;

        if (settings_.harvestStartTime == 0) settings.harvestStartTime = settings_.startTime;
        else settings.harvestStartTime = settings_.harvestStartTime;
        settings.depositEndTime = settings_.depositEndTime;

        settings.description = settings_.description;

        _setRequirements(settings_.lockDurationReq, settings_.lockEndReq, settings_.depositAmountReq, settings_.whitelist);

        Ownable.transferOwnership(owner_);
    }


    /********************************************/
    /****************** EVENTS ******************/
    /********************************************/

    event ActivateEmergencyClose();
    event AddRewardsToken1(uint256 amount, uint256 feeAmount);
    event AddRewardsToken2(uint256 amount, uint256 feeAmount);
    event Deposit(address indexed userAddress, uint256 tokenId, uint256 amount);
    event Harvest(address indexed userAddress, IERC20 rewardsToken, uint256 pending);
    event Publish();
    event SetDateSettings(uint256 endTime, uint256 harvestStartTime, uint256 depositEndTime);
    event SetDescription(string description);
    event SetRequirements(uint256 lockDurationReq, uint256 lockEndReq, uint256 depositAmountReq, bool whitelist);
    event SetRewardsToken2(IERC20 rewardsToken2);
    event SetCustomReqContract(address contractAddress);
    event UpdatePool();
    event WhitelistUpdated();
    event Withdraw(address indexed userAddress, uint256 tokenId, uint256 amount);
    event EmergencyWithdraw(address indexed userAddress, uint256 tokenId, uint256 amount);
    event WithdrawRewardsToken1(uint256 amount, uint256 totalRewardsAmount);
    event WithdrawRewardsToken2(uint256 amount, uint256 totalRewardsAmount);


    /**************************************************/
    /****************** PUBLIC VIEWS ******************/
    /**************************************************/

    /**
     * @dev Returns the amount of rewardsToken1 distributed every second
     */
    function rewardsToken1PerSecond() public view returns (uint256) {
        if (settings.endTime <= lastRewardTime) return 0;
        return rewardsToken1.remainingAmount.div(settings.endTime.sub(lastRewardTime));
    }

    /**
     * @dev Returns the amount of rewardsToken2 distributed every second
     */
    function rewardsToken2PerSecond() public view returns (uint256) {
        if (settings.endTime <= lastRewardTime) return 0;
        return rewardsToken2.remainingAmount.div(settings.endTime.sub(lastRewardTime));
    }

    /**
     * @dev Returns the number of whitelisted addresses
     */
    function whitelistLength() external view returns (uint256) {
        return _whitelistedUsers.length();
    }

    /**
     * @dev Returns a whitelisted address from its "index"
     */
    function whitelistAddress(uint256 index) external view returns (address) {
        return _whitelistedUsers.at(index);
    }

    /**
     * @dev Checks if "account" address is whitelisted
     */
    function isWhitelisted(address account) external view returns (bool) {
        return _whitelistedUsers.contains(account);
    }

    /**
     * @dev Returns the number of tokenIds from positions deposited by "account" address
     */
    function userTokenIdsLength(address account) external view returns (uint256) {
        return _userTokenIds[account].length();
    }

    /**
     * @dev Returns a position's tokenId deposited by "account" address from its "index"
     */
    function userTokenId(address account, uint256 index) external view returns (uint256) {
        return _userTokenIds[account].at(index);
    }

    /**
     * @dev Returns pending rewards (rewardsToken1 and rewardsToken2) for "account" address
     */
    function pendingRewards(address account) external view returns (uint256 pending1, uint256 pending2) {
        UserInfo memory user = userInfo[account];

        // recompute accRewardsPerShare for rewardsToken1 & rewardsToken2 if not up to date
        uint256 accRewardsToken1PerShare_ = rewardsToken1.accRewardsPerShare;
        uint256 accRewardsToken2PerShare_ = rewardsToken2.accRewardsPerShare;

        // only if existing deposits and lastRewardTime already passed
        if (lastRewardTime < _currentBlockTimestamp() && totalDepositAmount > 0) {
            uint256 rewardsAmount = rewardsToken1PerSecond().mul(_currentBlockTimestamp().sub(lastRewardTime));
            // in case of rounding errors
            if (rewardsAmount > rewardsToken1.remainingAmount) rewardsAmount = rewardsToken1.remainingAmount;
            accRewardsToken1PerShare_ = accRewardsToken1PerShare_.add(rewardsAmount.mul(1e18).div(totalDepositAmount));

            rewardsAmount = rewardsToken2PerSecond().mul(_currentBlockTimestamp().sub(lastRewardTime));
            // in case of rounding errors
            if (rewardsAmount > rewardsToken2.remainingAmount) rewardsAmount = rewardsToken2.remainingAmount;
            accRewardsToken2PerShare_ = accRewardsToken2PerShare_.add(rewardsAmount.mul(1e18).div(totalDepositAmount));
        }
        pending1 = (user.totalDepositAmount.mul(accRewardsToken1PerShare_).div(1e18).sub(user.rewardDebtToken1)).add(user.pendingRewardsToken1);
        pending2 = (user.totalDepositAmount.mul(accRewardsToken2PerShare_).div(1e18).sub(user.rewardDebtToken2)).add(user.pendingRewardsToken2);
    }


    /***********************************************/
    /****************** MODIFIERS ******************/
    /***********************************************/

    modifier isValidNFTPool(address sender) {
        require(sender == address(nftPool), "invalid NFTPool");
        _;
    }


    /*****************************************************************/
    /******************  EXTERNAL PUBLIC FUNCTIONS  ******************/
    /*****************************************************************/

    /**
     * @dev Update this ThunderPool
     */
    function updatePool() external nonReentrant {
        _updatePool();
    }

    /**
     * @dev Automatically stakes transferred positions from a NFTPool
     */
    function onERC721Received(address /*operator*/, address from, uint256 tokenId, bytes calldata /*data*/) external override nonReentrant isValidNFTPool(msg.sender) returns (bytes4) {
        require(published, "not published");
        require(!settings.whitelist || _whitelistedUsers.contains(from), "not whitelisted");

        // save tokenId previous owner
        _userTokenIds[from].add(tokenId);
        tokenIdOwner[tokenId] = from;

        (uint256 amount,uint256 startLockTime, uint256 lockDuration) = _getStackingPosition(tokenId);
        _checkPositionRequirements(amount, startLockTime, lockDuration);

        _deposit(from, tokenId, amount);

        // allow depositor to interact with the staked position later
        nftPool.approve(from, tokenId);
        return _ERC721_RECEIVED;
    }

    /**
     * @dev Withdraw a position from the ThunderPool
     *
     * Can only be called by the position's previous owner
     */
    function withdraw(uint256 tokenId) external virtual nonReentrant {
        require(msg.sender == tokenIdOwner[tokenId], "not allowed");

        (uint256 amount,,) = _getStackingPosition(tokenId);

        _updatePool();
        UserInfo storage user = userInfo[msg.sender];
        _harvest(user, msg.sender);

        user.totalDepositAmount = user.totalDepositAmount.sub(amount);
        totalDepositAmount = totalDepositAmount.sub(amount);

        _updateRewardDebt(user);

        // remove from previous owners info
        _userTokenIds[msg.sender].remove(tokenId);
        delete tokenIdOwner[tokenId];

        nftPool.safeTransferFrom(address(this), msg.sender, tokenId);

        emit Withdraw(msg.sender, tokenId, amount);
    }

    /**
     * @dev Withdraw a position from the ThunderPool without caring about rewards, EMERGENCY ONLY
     *
     * Can only be called by position's previous owner
     */
    function emergencyWithdraw(uint256 tokenId) external virtual nonReentrant {
        require(msg.sender == tokenIdOwner[tokenId], "not allowed");

        (uint256 amount,,) = _getStackingPosition(tokenId);
        UserInfo storage user = userInfo[msg.sender];
        user.totalDepositAmount = user.totalDepositAmount.sub(amount);
        totalDepositAmount = totalDepositAmount.sub(amount);

        _updateRewardDebt(user);

        // remove from previous owners info
        _userTokenIds[msg.sender].remove(tokenId);
        delete tokenIdOwner[tokenId];

        nftPool.safeTransferFrom(address(this), msg.sender, tokenId);

        emit EmergencyWithdraw(msg.sender, tokenId, amount);
    }

    /**
     * @dev Harvest pending ThunderPool rewards
     */
    function harvest() external nonReentrant {
        _updatePool();
        UserInfo storage user = userInfo[msg.sender];
        _harvest(user, msg.sender);
        _updateRewardDebt(user);
    }

    /**
     * @dev Allow stacked positions to be harvested
     *
     * "to" can be set to token's previous owner
     * "to" can be set to this address only if this contract is allowed to transfer xFLASH
     */
    function onNFTHarvest(address operator, address to, uint256 tokenId, uint256 artAmount, uint256 xFlashAmount) external override isValidNFTPool(msg.sender) returns (bool) {
        address owner = tokenIdOwner[tokenId];
        require(operator == owner, "not allowed");

        // if not whitelisted, the ThunderPool can't transfer any xFLASH rewards
        require(to != address(this) || xFlashToken.isTransferWhitelisted(address(this)), "cant handle rewards");

        // redirect rewards to position's previous owner
        if (to == address(this)) {
            flashToken.safeTransfer(owner, artAmount);
            xFlashToken.safeTransfer(owner, xFlashAmount);
        }

        return true;
    }

    /**
     * @dev Allow position's previous owner to add more assets to his position
     */
    function onNFTAddToPosition(address operator, uint256 tokenId, uint256 amount) external override nonReentrant isValidNFTPool(msg.sender) returns (bool) {
        require(operator == tokenIdOwner[tokenId], "not allowed");
        _deposit(operator, tokenId, amount);
        return true;
    }

    /**
     * @dev Disallow withdraw assets from a stacked position
     */
    function onNFTWithdraw(address /*operator*/, uint256 /*tokenId*/, uint256 /*amount*/) external pure override returns (bool){
        return false;
    }


    /*****************************************************************/
    /****************** EXTERNAL OWNABLE FUNCTIONS  ******************/
    /*****************************************************************/

    /**
     * @dev Transfer ownership of this ThunderPool
     *
     * Must only be called by the owner of this contract
     */
    function transferOwnership(address newOwner) public override onlyOwner {
        _setThunderPoolOwner(newOwner);
        Ownable.transferOwnership(newOwner);
    }

    /**
     * @dev Transfer ownership of this ThunderPool
     *
     * Must only be called by the owner of this contract
     */
    function renounceOwnership() public override onlyOwner {
        _setThunderPoolOwner(address(0));
        Ownable.renounceOwnership();
    }

    /**
     * @dev Add rewards to this ThunderPool
     */
    function addRewards(uint256 amountToken1, uint256 amountToken2) external nonReentrant {
        require(_currentBlockTimestamp() < settings.endTime, "pool ended");
        _updatePool();

        // get active fee share for this ThunderPool
        uint256 feeShare = factory.getThunderPoolFee(address(this), owner());
        address feeAddress = factory.feeAddress();
        uint256 feeAmount;

        if (amountToken1 > 0) {
            // token1 fee
            feeAmount = amountToken1.mul(feeShare).div(10000);
            amountToken1 = _transferSupportingFeeOnTransfer(rewardsToken1.token, msg.sender, amountToken1.sub(feeAmount));

            // recomputes rewards to distribute
            rewardsToken1.amount = rewardsToken1.amount.add(amountToken1);
            rewardsToken1.remainingAmount = rewardsToken1.remainingAmount.add(amountToken1);

            emit AddRewardsToken1(amountToken1, feeAmount);

            if (feeAmount > 0) {
                rewardsToken1.token.safeTransferFrom(msg.sender, feeAddress, feeAmount);
            }
        }

        if (amountToken2 > 0) {
            require(address(rewardsToken2.token) != address(0), "rewardsToken2");

            // token2 fee
            feeAmount = amountToken2.mul(feeShare).div(10000);
            amountToken2 = _transferSupportingFeeOnTransfer(rewardsToken2.token, msg.sender, amountToken2.sub(feeAmount));

            // recomputes rewards to distribute
            rewardsToken2.amount = rewardsToken2.amount.add(amountToken2);
            rewardsToken2.remainingAmount = rewardsToken2.remainingAmount.add(amountToken2);

            emit AddRewardsToken2(amountToken2, feeAmount);

            if (feeAmount > 0) {
                rewardsToken2.token.safeTransferFrom(msg.sender, feeAddress, feeAmount);
            }
        }
    }

    /**
     * @dev Withdraw rewards from this ThunderPool
     *
     * Must only be called by the owner
     * Must only be called before the publication of the Thunder Pool
     */
    function withdrawRewards(uint256 amountToken1, uint256 amountToken2) external onlyOwner nonReentrant {
        require(!published, "published");

        if (amountToken1 > 0) {
            // recomputes rewards to distribute
            rewardsToken1.amount = rewardsToken1.amount.sub(amountToken1, "too high");
            rewardsToken1.remainingAmount = rewardsToken1.remainingAmount.sub(amountToken1, "too high");

            emit WithdrawRewardsToken1(amountToken1, rewardsToken1.amount);
            _safeRewardsTransfer(rewardsToken1.token, msg.sender, amountToken1);
        }

        if (amountToken2 > 0 && address(rewardsToken2.token) != address(0)) {
            // recomputes rewards to distribute
            rewardsToken2.amount = rewardsToken2.amount.sub(amountToken2, "too high");
            rewardsToken2.remainingAmount = rewardsToken2.remainingAmount.sub(amountToken2, "too high");

            emit WithdrawRewardsToken2(amountToken2, rewardsToken2.amount);
            _safeRewardsTransfer(rewardsToken2.token, msg.sender, amountToken2);
        }
    }

    /**
     * @dev Set the rewardsToken2
     *
     * Must only be called by the owner
     * Must only be initialized once
     */
    function setRewardsToken2(IERC20 rewardsToken2_) external onlyOwner nonReentrant {
        require(!published, "published");
        require(address(rewardsToken2.token) == address(0), "already set");
        require(rewardsToken1.token != rewardsToken2_, "invalid");
        rewardsToken2.token = rewardsToken2_;

        emit SetRewardsToken2(rewardsToken2_);
    }

    /**
     * @dev Set an external custom requirement contract
     */
    function setCustomReqContract(address contractAddress) external onlyOwner {
        // Allow to disable customReq event if pool is published
        require(!published || contractAddress == address(0), "published");
        customReqContract = IThunderCustomReq(contractAddress);

        emit SetCustomReqContract(contractAddress);
    }

    /**
     * @dev Set requirements that positions must meet to be staked on this Thunder Pool
     *
     * Must only be called by the owner
     */
    function setRequirements(uint256 lockDurationReq_, uint256 lockEndReq_, uint256 depositAmountReq_, bool whitelist_) external onlyOwner {
        _setRequirements(lockDurationReq_, lockEndReq_, depositAmountReq_, whitelist_);
    }

    /**
     * @dev Set the pool's datetime settings
     *
     * Must only be called by the owner
     * Thunder duration can only be extended once already published
     * Harvest start time can only be updated if not published
     * Deposit end time can only be updated if not been published
     */
    function setDateSettings(uint256 endTime_, uint256 harvestStartTime_, uint256 depositEndTime_) external nonReentrant onlyOwner {
        require(settings.startTime < endTime_, "invalid endTime");
        require(_currentBlockTimestamp() <= settings.endTime, "pool ended");
        require(depositEndTime_ == 0 || settings.startTime <= depositEndTime_, "invalid depositEndTime");
        require(harvestStartTime_ == 0 || settings.startTime <= harvestStartTime_, "invalid harvestStartTime");

        if (published) {
            // can only be extended
            require(settings.endTime <= endTime_, "not allowed endTime");
            // can't be updated
            require(settings.depositEndTime == depositEndTime_, "not allowed depositEndTime");
            // can't be updated
            require(settings.harvestStartTime == harvestStartTime_, "not allowed harvestStartTime");
        }

        settings.endTime = endTime_;
        // updated only when not published
        if (harvestStartTime_ == 0) settings.harvestStartTime = settings.startTime;
        else settings.harvestStartTime = harvestStartTime_;
        settings.depositEndTime = depositEndTime_;

        emit SetDateSettings(endTime_, harvestStartTime_, depositEndTime_);
    }

    /**
     * @dev Set pool's description
     *
     * Must only be called by the owner
     */
    function setDescription(string calldata description) external onlyOwner {
        settings.description = description;
        emit SetDescription(description);
    }

    /**
     * @dev Set whitelisted users
     *
     * Must only be called by the owner
     */
    function setWhitelist(WhitelistStatus[] calldata whitelistStatuses) external virtual onlyOwner {
        uint256 whitelistStatusesLength = whitelistStatuses.length;
        require(whitelistStatusesLength > 0, "empty");

        for (uint256 i; i < whitelistStatusesLength; ++i) {
            if (whitelistStatuses[i].status) _whitelistedUsers.add(whitelistStatuses[i].account);
            else _whitelistedUsers.remove(whitelistStatuses[i].account);
        }

        emit WhitelistUpdated();
    }

    /**
     * @dev Fully reset the current whitelist
     *
     * Must only be called by the owner
     */
    function resetWhitelist() external onlyOwner {
        uint256 i = _whitelistedUsers.length();
        for (i; i > 0; --i) {
            _whitelistedUsers.remove(_whitelistedUsers.at(i - 1));
        }

        emit WhitelistUpdated();
    }

    /**
     * @dev Publish the thunder Pool
     *
     * Must only be called by the owner
     */
    function publish() external onlyOwner {
        require(!published, "published");
        // this thunderPool is Stale
        require(settings.startTime > _currentBlockTimestamp(), "stale");
        require(rewardsToken1.amount > 0, "no rewards");

        published = true;
        publishTime = _currentBlockTimestamp();
        factory.publishThunderPool(address(nftPool));

        emit Publish();
    }

    /**
     * @dev Emergency close
     *
     * Must only be called by the owner
     * Emergency only: if used, the whole pool is definitely made void
     * All rewards are automatically transferred to the emergency recovery address
     */
    function activateEmergencyClose() external nonReentrant onlyOwner {
        address emergencyRecoveryAddress = factory.emergencyRecoveryAddress();

        uint256 remainingToken1 = rewardsToken1.remainingAmount;
        uint256 remainingToken2 = rewardsToken2.remainingAmount;

        rewardsToken1.amount = rewardsToken1.amount.sub(remainingToken1);
        rewardsToken1.remainingAmount = 0;

        rewardsToken2.amount = rewardsToken2.amount.sub(remainingToken2);
        rewardsToken2.remainingAmount = 0;
        emergencyClose = true;

        emit ActivateEmergencyClose();
        // transfer rewardsToken1 remaining amount if any
        _safeRewardsTransfer(rewardsToken1.token, emergencyRecoveryAddress, remainingToken1);
        // transfer rewardsToken2 remaining amount if any
        _safeRewardsTransfer(rewardsToken2.token, emergencyRecoveryAddress, remainingToken2);
    }


    /********************************************************/
    /****************** INTERNAL FUNCTIONS ******************/
    /********************************************************/

    /**
     * @dev Set requirements that positions must meet to be staked on this Thunder Pool
     */
    function _setRequirements(uint256 lockDurationReq_, uint256 lockEndReq_, uint256 depositAmountReq_, bool whitelist_) internal {
        require(lockEndReq_ == 0 || settings.startTime < lockEndReq_, "invalid lockEnd");

        if (published) {
            // Can't decrease requirements if already published
            require(lockDurationReq_ >= settings.lockDurationReq, "invalid lockDuration");
            require(lockEndReq_ >= settings.lockEndReq, "invalid lockEnd");
            require(depositAmountReq_ >= settings.depositAmountReq, "invalid depositAmount");
            require(!settings.whitelist || settings.whitelist == whitelist_, "invalid whitelist");
        }

        settings.lockDurationReq = lockDurationReq_;
        settings.lockEndReq = lockEndReq_;
        settings.depositAmountReq = depositAmountReq_;
        settings.whitelist = whitelist_;

        emit SetRequirements(lockDurationReq_, lockEndReq_, depositAmountReq_, whitelist_);
    }

    /**
     * @dev Updates rewards states of this Thunder Pool to be up-to-date
     */
    function _updatePool() internal {
        uint256 currentBlockTimestamp = _currentBlockTimestamp();

        if (currentBlockTimestamp <= lastRewardTime) return;

        // do nothing if there is no deposit
        if (totalDepositAmount == 0) {
            lastRewardTime = currentBlockTimestamp;
            emit UpdatePool();
            return;
        }

        // updates rewardsToken1 state
        uint256 rewardsAmount = rewardsToken1PerSecond().mul(currentBlockTimestamp.sub(lastRewardTime));
        // ensure we do not distribute more than what's available
        if (rewardsAmount > rewardsToken1.remainingAmount) rewardsAmount = rewardsToken1.remainingAmount;
        rewardsToken1.remainingAmount = rewardsToken1.remainingAmount.sub(rewardsAmount);
        rewardsToken1.accRewardsPerShare = rewardsToken1.accRewardsPerShare.add(rewardsAmount.mul(1e18).div(totalDepositAmount));

        // if rewardsToken2 is activated
        if (address(rewardsToken2.token) != address(0)) {
            // updates rewardsToken2 state
            rewardsAmount = rewardsToken2PerSecond().mul(currentBlockTimestamp.sub(lastRewardTime));
            // ensure we do not distribute more than what's available
            if (rewardsAmount > rewardsToken2.remainingAmount) rewardsAmount = rewardsToken2.remainingAmount;
            rewardsToken2.remainingAmount = rewardsToken2.remainingAmount.sub(rewardsAmount);
            rewardsToken2.accRewardsPerShare = rewardsToken2.accRewardsPerShare.add(rewardsAmount.mul(1e18).div(totalDepositAmount));
        }

        lastRewardTime = currentBlockTimestamp;
        emit UpdatePool();
    }

    /**
     * @dev Add a user's deposited amount into this Thunder Pool
     */
    function _deposit(address account, uint256 tokenId, uint256 amount) internal {
        require((settings.depositEndTime == 0 || settings.depositEndTime >= _currentBlockTimestamp()) && !emergencyClose, "not allowed");

        if(address(customReqContract) != address(0)){
            require(customReqContract.canDeposit(account, tokenId), "invalid customReq");
        }

        _updatePool();

        UserInfo storage user = userInfo[account];
        _harvest(user, account);

        user.totalDepositAmount = user.totalDepositAmount.add(amount);
        totalDepositAmount = totalDepositAmount.add(amount);
        _updateRewardDebt(user);

        emit Deposit(account, tokenId, amount);
    }

    /**
     * @dev Transfer to a user its pending rewards
     */
    function _harvest(UserInfo storage user, address to) internal {
        bool canHarvest = true;
        if(address(customReqContract) != address(0)){
            canHarvest = customReqContract.canHarvest(to);
        }

        // rewardsToken1
        uint256 pending = user.totalDepositAmount.mul(rewardsToken1.accRewardsPerShare).div(1e18).sub(user.rewardDebtToken1);
        // check if harvest is allowed
        if (_currentBlockTimestamp() < settings.harvestStartTime || !canHarvest) {
            // if not allowed, add to rewards buffer
            user.pendingRewardsToken1 = user.pendingRewardsToken1.add(pending);
        } else {
            // if allowed, transfer rewards
            pending = pending.add(user.pendingRewardsToken1);
            user.pendingRewardsToken1 = 0;
            _safeRewardsTransfer(rewardsToken1.token, to, pending);

            emit Harvest(to, rewardsToken1.token, pending);
        }

        // rewardsToken2 (if initialized)
        if (address(rewardsToken2.token) != address(0)) {
            pending = user.totalDepositAmount.mul(rewardsToken2.accRewardsPerShare).div(1e18).sub(user.rewardDebtToken2);
            // check if harvest is allowed
            if (_currentBlockTimestamp() < settings.harvestStartTime || !canHarvest) {
                // if not allowed, add to rewards buffer
                user.pendingRewardsToken2 = user.pendingRewardsToken2.add(pending);
            } else {
                // if allowed, transfer rewards
                pending = pending.add(user.pendingRewardsToken2);
                user.pendingRewardsToken2 = 0;
                _safeRewardsTransfer(rewardsToken2.token, to, pending);

                emit Harvest(to, rewardsToken2.token, pending);
            }
        }
    }

    /**
     * @dev Update a user's rewardDebt for rewardsToken1 and rewardsToken2
     */
    function _updateRewardDebt(UserInfo storage user) internal virtual {
        (bool succeed, uint256 result) = user.totalDepositAmount.tryMul(rewardsToken1.accRewardsPerShare);
        if(succeed) user.rewardDebtToken1 = result.div(1e18);

        (succeed, result) = user.totalDepositAmount.tryMul(rewardsToken2.accRewardsPerShare);
        if(succeed) user.rewardDebtToken2 = result.div(1e18);
    }

    /**
     * @dev Check whether a position with "tokenId" ID is meeting all of this Thunder Pool's active requirements
     */
    function _checkPositionRequirements(uint256 amount, uint256 startLockTime, uint256 lockDuration) internal virtual {
        // lock duration requirement
        if (settings.lockDurationReq > 0) {
            // for unlocked position that have not been updated yet
            require(_currentBlockTimestamp() < startLockTime.add(lockDuration) && settings.lockDurationReq <= lockDuration, "invalid lockDuration");
        }

        // lock end time requirement
        if (settings.lockEndReq > 0) {
            require(settings.lockEndReq <= startLockTime.add(lockDuration), "invalid lockEnd");
        }

        // deposit amount requirement
        if (settings.depositAmountReq > 0) {
            require(settings.depositAmountReq <= amount, "invalid amount");
        }
    }

    /**
  * @dev Handle deposits of tokens with transfer tax
  */
    function _transferSupportingFeeOnTransfer(IERC20 token, address user, uint256 amount) internal returns (uint256 receivedAmount) {
        uint256 previousBalance = token.balanceOf(address(this));
        token.safeTransferFrom(user, address(this), amount);
        return token.balanceOf(address(this)).sub(previousBalance);
    }


    /**
     * @dev Safe token transfer function, in case rounding error causes pool to not have enough tokens
     */
    function _safeRewardsTransfer(IERC20 token, address to, uint256 amount) internal virtual {
        if(amount == 0) return;

        uint256 balance = token.balanceOf(address(this));
        // cap to available balance
        if (amount > balance) {
            amount = balance;
        }
        token.safeTransfer(to, amount);
    }


    function _getStackingPosition(uint256 tokenId) internal view returns (uint256 amount, uint256 startLockTime, uint256 lockDuration) {
        (amount,, startLockTime, lockDuration,,,,) = nftPool.getStakingPosition(tokenId);
    }

    function _setThunderPoolOwner(address newOwner) internal {
        factory.setThunderPoolOwner(owner(), newOwner);
    }

    /**
     * @dev Utility function to get the current block timestamp
     */
    function _currentBlockTimestamp() internal view virtual returns (uint256) {
        /* solhint-disable not-rely-on-time */
        return block.timestamp;
    }
}