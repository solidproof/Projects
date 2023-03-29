pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/utils/ContextUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

import "./interfaces/IDione.sol";

contract DioneStaking is Initializable, ContextUpgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IDione;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.AddressSet;

    struct UserInfo {
        uint256 amount;
        uint256 penaltyDebt;
        uint256 rewardClaimable;
        uint256 rewardClaimed;
        uint256 penaltyClaimable;
        uint256 stakingTimestamp;
        uint256 lastRewardTime;
        uint256 reimbursementAmount;
    }

    struct Statistics {
        uint256 totalStakers;
        uint256 totalDeposit;
        uint256 totalReimbursement;
        uint256 totalRewards;
    }

    struct PenaltyTiers {
        uint256 validUntil;
        uint256 percent;
    }

    uint256 constant public REWARD_PERIOD = 30 * 24 * 60 * 60; // A month

    uint256 constant public REWARD_MAX_LIMIT = 800; // 8% with 2 decimals

    uint256 constant public MAX_SPEND_AMOUNT = 200; // 2% with 2 decimals

    uint256 private accPenalty; // Not distributed yet amount of penalties

    uint256 public accPenaltyPerShare; // accumulated penalty per share

    uint256 public stakingEndTime; // Staking end time - 0 initially - will be setup by admin
    uint256 public stakingStartTime; // Staking start time - 0 initially - will be stup by init() function

    uint256 public lastPenaltyTime; // Last time when penalty shared to accounts

    uint256 public PRECISION_FACTOR; // Precision factor

    uint256 public rewardPercent; // Reward percent Monthly (2 decimals)
    uint256 public reimbursementFee; // Reimbursement Fee

    address public burnAddress; // Burn address
    IDione public dione; // Dione Address

    bool public isStarted; // Is Staking started?
    bool public isFinished; // Is Staking finished?
    bool public isWithdrawable; // Is withdrawable?

    mapping(address => UserInfo) public userInfo; // Users staking info

    EnumerableSetUpgradeable.AddressSet private stakers;
    Statistics public statistics; // Staking app statistics
    PenaltyTiers[] public tiers; // Penalty tiers
    PenaltyTiers public outOfTiersPenalty; // Last penalty tier

    modifier isStaking() { // Can a user stake?
        require(isStarted, "DioneStaking: NOT_STARTED");
        require(!isFinished, "DioneStaking: STAKING_FINISHED");
        _;
    }

    event Init();
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event EarlyWithdraw(address indexed user, uint256 amount);

    event AdminTokenRecovery(address tokenRecovered, uint256 amount);
    event NewRewardPercent(uint256 rewardPercent);
    event PenaltyTierAdded(uint256 validUntil, uint256 percent);
    event PenaltyTaken(address indexed user, uint256 amount);
    event WithdrawStatusUpdated(bool withdrawable);
    event FinishStatusUpdated(bool finished);
    event UpdateReimbursementFee(uint256 reimbursementFee);

    // Proxy initializer
    function initialize(
        IDione _dione,
        uint256 _reimbursementFee,
        address _burnAddress
    ) public initializer {
        __Context_init_unchained();
        __Ownable_init_unchained();
        __ReentrancyGuard_init_unchained();
        __DioneStaking_init_unchained(_dione, _reimbursementFee, _burnAddress);
    }

    // Dione Proxy initializer
    function __DioneStaking_init_unchained(
        IDione _dione,
        uint256 _reimbursementFee,
        address _burnAddress
    ) internal initializer {
        require(_dione.totalSupply() >= 0);

        dione = _dione;
        reimbursementFee = _reimbursementFee;
        burnAddress = _burnAddress;

        isStarted = false;
        isFinished = false;
        isWithdrawable = false;

        PRECISION_FACTOR = uint256(10**(uint256(30).sub(_dione.decimals())));
    }

    /// @notice OwnerOnly Function - Updates last penalty tier 
    /// @param _validUntil Penalty tier valid length (will be calculated from user staking start timestamp)
    /// @param _percent Penalty percent for new penalty tier
    function updateOutOfTiersPenalty(uint256 _validUntil, uint256 _percent) external onlyOwner {
        require(_percent <= 1000, "INVALID PERCENT");
        outOfTiersPenalty.validUntil = _validUntil;
        outOfTiersPenalty.percent = _percent;
    }

    /// @notice OwnerOnly Function - Adding new Penalty tier
    /// @param _validUntil Penalty tier valid length (will be calculated from user staking start timestamp)
    /// @param _percent Penalty percent for new penalty tier
    function addPenaltyTier(uint256 _validUntil, uint256 _percent) external onlyOwner {
        require(_percent <= 1000, "INVALID PERCENT");
        _addPenaltyTier(_validUntil, _percent);
    }

    /// @notice Internal Function - Adding new Penalty tier
    /// @param _validUntil Penalty tier valid length (will be calculated from user staking start timestamp)
    /// @param _percent Penalty percent for new penalty tier
    function _addPenaltyTier(uint256 _validUntil, uint256 _percent) internal {
        tiers.push(PenaltyTiers(_validUntil, _percent));

        emit PenaltyTierAdded(_validUntil, _percent);
    }

    /// @notice View Function - Calculates penalty amount for a specific user
    /// @param _user Selected user address
    function getPenaltyAmount(address _user) external view returns (uint256) {
        if(isWithdrawable) return 0;

        return _calculatePenalty(_user);
    }

    /// @notice View Function - Returns current penalty tier for a specific user
    /// @param _user Selected user address
    function getPenaltyTier(address _user) external view returns (uint256) {
        if(userInfo[_user].amount == 0) return 0;
        if(isWithdrawable) return 0;

        return _getPenaltyTier(userInfo[_user].stakingTimestamp);
    }

    /// @notice Internal Function - Calculates penalty amount for a specific user
    /// @param _user Selected user address
    function _calculatePenalty(address _user) internal view returns (uint256) {
        uint256 penaltyPercent = _getPenaltyTier(userInfo[_user].stakingTimestamp);
        return penaltyPercent.mul(userInfo[_user].amount).div(10**4);
    }

    /// @notice Internal Function - Finds current penalty tier based on staking timestamp
    /// @param _timestamp Staking start timestamp
    function _getPenaltyTier(uint256 _timestamp) internal view returns (uint256) {
        uint256 penaltyPercent = 0;
        for(uint256 i = 0; i < tiers.length; i++) {
            if(tiers[i].validUntil + _timestamp >= block.timestamp) {
                penaltyPercent = tiers[i].percent;
                break;
            }
        }

        if(penaltyPercent == 0) {
            return outOfTiersPenalty.percent;
        }
        return penaltyPercent;
    }

    /// @notice OwnerOnly Function - Admin would be able to start staking and let users to stake their DIONE tokens.
    /// @param _rewardPercent Monthly reward percent
    function init(uint256 _rewardPercent) external onlyOwner {
        require(!isStarted, "DioneStaking: ALREADY_STARTED");
        require(!isFinished, "DioneStaking: ALREADY_FINISHED");
        require(!isWithdrawable, "DioneStaking: WITHDRAWAL_STAGE");

        isStarted = true;
        rewardPercent = _rewardPercent;
        stakingStartTime = block.timestamp;
        lastPenaltyTime = stakingStartTime;
        emit Init();
    }

    /// @notice OwnerOnly Function - Admin would be able to update Finished flag to finish Staking and don't let users to Stake DIONE.
    /// @param _status Finished flag new Status
    function updateFinishedStatus(bool _status) external onlyOwner {
        require(isStarted, "DioneStaking: NOT_STARTED");
        require(!isWithdrawable, "DioneStaking: WITHDRAWAL_STAGE");
        stakingEndTime = block.timestamp;
        isFinished = _status;

        emit FinishStatusUpdated(_status);
    }

    /// @notice OwnerOnly Function - Admin would be able to update withdrawable flag to finish penalty and let users to claim their tokens in DIONE Protocol Blockchain.
    /// @param _status Withdrawable new Status
    function updateWithdrawStatus(bool _status) external onlyOwner {
        require(isFinished, "DioneStaking: NOT_FINISHED");
        isWithdrawable = _status;

        emit WithdrawStatusUpdated(_status);
    }

    /// @notice View Function - Returns Staking Maximum amount
    /// @return maxSpendAmount - Staking maximum amount
    function getMaxSpendAmount() public view returns (uint256) {
        uint256 _totalSupply = dione.totalSupply();
        return _totalSupply.mul(MAX_SPEND_AMOUNT).div(10**4);
    }


    /// @notice External Function - User Desposit (Stake) function
    /// @param _amount DIONE token amount which user wants to deposit (stake)
    function deposit(uint256 _amount) external isStaking nonReentrant {
        UserInfo storage user = userInfo[msg.sender];
        _updatePool();

        if (user.amount > 0) {
            uint256 _pendingPenalty = user.amount.mul(accPenaltyPerShare).div(PRECISION_FACTOR).sub(user.penaltyDebt);
            if (_pendingPenalty > 0) {
                user.penaltyClaimable = user.penaltyClaimable.add(_pendingPenalty);
            }

            uint256 _pendingReward = _getUserPendingReward(msg.sender);
            if (_pendingReward > 0) {
                statistics.totalRewards = statistics.totalRewards.sub(user.rewardClaimable).add(_pendingReward);
                user.rewardClaimable = _pendingReward;
                user.lastRewardTime = block.timestamp;
            }
        } else {
            user.stakingTimestamp = block.timestamp;
            statistics.totalStakers++;
            stakers.add(msg.sender);
        }

        uint256 _remaining = (getMaxSpendAmount()).sub(user.amount);
        if(_remaining < _amount) {
            _amount = _remaining;
        }

        if (_amount > 0) {
            uint256 allowance = dione.allowance(msg.sender, address(this));
            require(allowance >= _amount, "DioneStaking: INSUFFICIENT_ALLOWANCE");

            uint256 before = dione.balanceOf(address(this));
            dione.safeTransferFrom(address(msg.sender), address(this), _amount);
            uint256 _tAmount = dione.balanceOf(address(this)).sub(before);
            uint256 _reimbursementAmount = _amount.mul(reimbursementFee).div(10**4);

            user.amount = user.amount.add(_tAmount);
            user.reimbursementAmount = user.reimbursementAmount.add(_reimbursementAmount);

            statistics.totalDeposit = statistics.totalDeposit.add(_tAmount);
            statistics.totalReimbursement = statistics.totalReimbursement.add(_reimbursementAmount);
        }

        user.penaltyDebt = user.amount.mul(accPenaltyPerShare).div(PRECISION_FACTOR);
        emit Deposit(msg.sender, _amount);
    }

    /// @notice External Function - User withdrawal function
    function withdraw() external nonReentrant {
        require(isStarted, "DioneStaking: NOT_STARTED");
        uint256 stakedAmount = userInfo[msg.sender].amount;

        require(stakedAmount > 0, "DioneStaking: INSUFFICIENT_BALANCE");
        _updatePool();

        if(!isWithdrawable) {
            _earlyWithdraw(msg.sender);
        } else {
            _withdraw(msg.sender);
        }
    }

    /// @notice OwnerOnly Function - Mass Withdraw stake amount and auto-migrate to DIONE Protocol Blockchain
    function massWithdraw() external onlyOwner {
        require(isWithdrawable, "DioneStaking: NOT_WITHDRAWAL");
        for(uint256 i = 0; i < stakers.length(); i++) {
            uint256 amount = userInfo[stakers.at(i)].amount;
            if(amount > 0) {
                _withdraw(stakers.at(i));
            }
        }
    }

    /// @notice Internal Function - User Early withdraw
    /// @param _user User address
    function _earlyWithdraw(address _user) internal {
        UserInfo storage user = userInfo[_user];

        uint256 _pendingPenalty = user.amount.mul(accPenaltyPerShare).div(PRECISION_FACTOR).sub(user.penaltyDebt).add(user.penaltyClaimable);
        uint256 _pendingReward = _getUserPendingReward(_user);

        uint256 _penalty = _calculatePenalty(_user);
        uint256 _amount = user.amount.sub(_penalty).add(_pendingReward);
        _initializeUser(_user, true);
        user.rewardClaimed = user.rewardClaimed.add(_pendingReward);
        dione.safeTransfer(_user, _amount);

        _addPenalty(_user, _pendingPenalty, _penalty);

        emit EarlyWithdraw(_user, _amount);
    }

    /// @notice Internal Function - User normal withdraw
    /// @param _user User address
    function _withdraw(address _user) internal {
        UserInfo storage user = userInfo[_user];

        uint256 _pendingPenalty = user.amount.mul(accPenaltyPerShare).div(PRECISION_FACTOR).sub(user.penaltyDebt).add(user.penaltyClaimable);
        uint256 _pendingReward = _getUserPendingReward(_user);

        if(user.stakingTimestamp + REWARD_PERIOD >= stakingEndTime) {
            _pendingPenalty = 0;
            user.reimbursementAmount = 0;
        }

        uint256 _amount = user.amount.add(user.reimbursementAmount).add(_pendingPenalty).add(_pendingReward);
        _initializeUser(_user, false);
        user.rewardClaimed = user.rewardClaimed.add(_pendingReward);
        dione.safeTransfer(burnAddress, _amount);

        emit Withdraw(_user, _amount);
    }

    /// @notice Internal Function - Initialize user info on withdraw
    /// @param _user Selected user address
    /// @param _early Flag to specify withdraw was early or not
    function _initializeUser(address _user, bool _early) internal {
        UserInfo storage user = userInfo[_user];

        if(_early) {
            statistics.totalReimbursement = statistics.totalReimbursement.sub(user.reimbursementAmount);
            statistics.totalDeposit = statistics.totalDeposit.sub(user.amount);
            statistics.totalStakers = statistics.totalStakers.sub(1);
            statistics.totalRewards = statistics.totalRewards.sub(user.rewardClaimable);
            stakers.remove(_user);
        }

        user.amount = 0;
        user.rewardClaimable = 0;
        user.penaltyClaimable = 0;
        user.lastRewardTime = 0;
        user.penaltyDebt = 0;
        user.reimbursementAmount = 0;
        user.stakingTimestamp = 0;
    }

    /// @notice Internal Function - Take penalty from user early withdraw
    /// @param _user Selected user address
    /// @param _pendingPenalty Selected user pending penalty amount
    /// @param _penalty Penalty amount
    function _addPenalty(address _user, uint256 _pendingPenalty, uint256 _penalty) internal {
        accPenalty = accPenalty.add(_penalty).add(_pendingPenalty);

        emit PenaltyTaken(_user, _penalty);
    }

    /// @notice View Function - Returns Pending rewards amount for a specific user
    /// @param _user Selected user address
    function pendingReward(address _user) external view returns (uint256) {
        return _getUserPendingReward(_user);
    }


    /// @notice Internal Function - Returns Pending rewards amount for a specific user
    /// @param _user Selected user address
    function _getUserPendingReward(address _user) internal view returns (uint256) {
        UserInfo memory user = userInfo[_user];
        if(block.timestamp > user.lastRewardTime && user.amount != 0) {
            uint256 oldMultiplier = _getMultiplier(user.stakingTimestamp, user.lastRewardTime);
            uint256 allMultiplier = _getMultiplier(user.stakingTimestamp, block.timestamp);
            if(allMultiplier > REWARD_MAX_LIMIT) {
                allMultiplier = REWARD_MAX_LIMIT;
            }
            uint256 multiplier = 0;
            if(allMultiplier > oldMultiplier) {
                multiplier = allMultiplier.sub(oldMultiplier);
            }
            uint256 _pendingReward = multiplier.mul(user.amount).div(10**4);

            return user.rewardClaimable.add(_pendingReward);
        } else {
            return user.rewardClaimable;
        }

    }

    /// @notice View Function - Returns Pending penalty amount for a specific user
    /// @param _user Selected user address
    function pendingPenalty(address _user) external view returns (uint256) {
        UserInfo memory user = userInfo[_user];
        if(isFinished && user.stakingTimestamp + REWARD_PERIOD >= stakingEndTime) {
            return 0;
        }

        uint256 totalStaked = statistics.totalDeposit;
        if (accPenalty > 0 && totalStaked != 0) {
            uint256 adjustedTokenPerShare = accPenaltyPerShare.add(
                accPenalty.mul(PRECISION_FACTOR).div(totalStaked)
            );
            return user.amount.mul(adjustedTokenPerShare).div(PRECISION_FACTOR).sub(user.penaltyDebt).add(user.penaltyClaimable);
        } else {
            return user.amount.mul(accPenaltyPerShare).div(PRECISION_FACTOR).sub(user.penaltyDebt).add(user.penaltyClaimable);
        }
    }

    /// @notice Updates staking penalty pool shares on each deposit or withdraw function
    function _updatePool() internal {
        if (block.timestamp <= lastPenaltyTime) {
            return;
        }

        uint256 totalStaked = statistics.totalDeposit;
        if (totalStaked == 0) {
            lastPenaltyTime = block.timestamp;
            return;
        }

        accPenaltyPerShare = accPenaltyPerShare.add(accPenalty.mul(PRECISION_FACTOR).div(totalStaked));
        accPenalty = 0;

        lastPenaltyTime = block.timestamp;
    }

    /// @notice OwnerOnly Function - Admin would be able to recover wrong tokens which sent to the contract
    /// @param _tokenAddress Token address which sent to the contract
    /// @param _tokenAmount Amount of the token which admin wants to recover
    function recoverWrongTokens(address _tokenAddress, uint256 _tokenAmount) external onlyOwner {
        require(_tokenAddress != address(dione), "DioneStaking: NOT_ALLOWED_DIONE");

        IERC20Upgradeable(_tokenAddress).safeTransfer(address(msg.sender), _tokenAmount);

        emit AdminTokenRecovery(_tokenAddress, _tokenAmount);
    }

    /// @notice OwnerOnly Function - Update reimbursement fee percent before starting staking
    /// @param _reimbursementFee New Reimbursement Fee Percent
    function updateReimbursementFee(uint256 _reimbursementFee) external onlyOwner {
        require(!isStarted, "DioneStaking: ALREADY_STARTED");
        reimbursementFee = _reimbursementFee;
        emit UpdateReimbursementFee(_reimbursementFee);
    }

    /// @notice OwnerOnly Function - Update monthly reward percent before starting staking
    /// @param _rewardPercent New Reward Percent
    function updateRewardPercent(uint256 _rewardPercent) external onlyOwner {
        require(!isStarted, "DioneStaking: ALREADY_STARTED");

        rewardPercent = _rewardPercent;
        emit NewRewardPercent(_rewardPercent);
    }


    /// @notice Internal Function - Calculate Reward multiplier for the timeline between _from to _to timestamps
    /// @param _from Timeline start timestamp
    /// @param _to Timeline end timestamp
    function _getMultiplier(uint256 _from, uint256 _to) internal view returns (uint256) {
        if(!isStarted) return 0;

        if(_to < _from + REWARD_PERIOD ) return 0;
        if (!isFinished) {
            if(_from <= stakingStartTime) {
                return _to.sub(stakingStartTime).div(REWARD_PERIOD).mul(rewardPercent);
            } else {
                return _to.sub(_from).div(REWARD_PERIOD).mul(rewardPercent);
            }
        } else if (_from >= stakingEndTime) {
            return 0;
        } else {
            return stakingEndTime.sub(_from).div(REWARD_PERIOD).mul(rewardPercent);
        }
    }

}
