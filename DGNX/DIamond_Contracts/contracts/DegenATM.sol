// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.19;

import { Address } from "@openzeppelin/contracts/utils/Address.sol";
import { Ownable } from "@openzeppelin/contracts/access/Ownable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import { IERC20Facet } from "./diamond/interfaces/IERC20Facet.sol";

/// @title Degen ATM
/// @author Daniel <danieldegendev@gmail.com>
/// @notice Funds collecting and vesting smart contract
/// @custom:version 1.0.0
contract DegenATM is Ownable, ReentrancyGuard {
    using Address for address payable;

    uint256 public constant LOCK_PERIOD = 31_536_000; // 365 days
    uint256 public constant DENOMINATOR = 10_000_000;
    uint256 public constant TOTAL_REWARD_BPS = 2_400; // 24%
    uint256 public constant REWARD_PENALTY_BPS = 7_000; // 70%

    bool public claiming;
    bool public collecting;
    uint256 public totalDeposits;
    uint256 public startTimestamp;
    uint256 public allocationLimit = 3 * 10 ** 18;
    uint256 public totalLockedTokens;
    uint256 public tokensPerOneNative;
    uint256 public totalClaimedTokens;
    address public token;
    mapping(address => bool) public locked;
    mapping(address => bool) public claimed;
    mapping(address => bool) public whitelist;
    mapping(address => uint256) public deposits;
    mapping(address => uint256) public lockedAmount;
    mapping(address => uint256) public claimedAmount;

    event Deposit(address depositer, uint256 amount);
    event Claimed(address claimer, uint256 amount);
    event LockJoin(address locker, uint256 amount);
    event LockLeave(address locker, uint256 amount, uint256 reward, uint256 penalty);
    event CollectingEnabled();
    event CollectingDisabled();
    event ClaimingEnabled();
    event ClaimingDisabled();
    event LockingEnabled();
    event LockingDisabled();
    event UpdatedAllocationRate(uint256 rate);
    event UpdatedAllocationLimit(uint256 limit);
    event UpdatedToken(address token);
    event AddToWhitelist(address candidate);
    event RemoveFromWhitelist(address candidate);
    event StartLockPeriod();

    modifier qualifyCheck() {
        _checkQualification();
        _;
    }

    /// Deposit native token
    function deposit() external payable {
        _deposit(msg.value, _msgSender());
    }

    /// Claiming the tokens
    /// @notice claiming is only possible when the claiming period has started
    /// @dev it also makes some qualify checks whether sender is allowed to execute, otherwise it reverts
    /// @dev possible to execute when claming is started
    function claimTokens() external nonReentrant qualifyCheck {
        if (!claiming) revert("not started");
        uint256 _amount = _calcClaimAmount(_msgSender());
        if (!IERC20(token).transfer(_msgSender(), _amount)) revert("payout failed");
        claimed[_msgSender()] = true;
        claimedAmount[_msgSender()] = _amount;
        totalClaimedTokens += _amount;
        emit Claimed(_msgSender(), _amount);
    }

    /// Locks the tokens
    /// @notice the sender will enter a lock state with his allocated amount of tokens
    /// @dev it also makes some qualify checks whether sender is allowed to execute, otherwise it reverts
    /// @dev possible to execute when claming is started
    function lockJoin() external qualifyCheck {
        if (!claiming) revert("not started");
        if (startTimestamp > 0) revert("lock not possible anymore");
        uint256 _amount = _calcClaimAmount(_msgSender());
        locked[_msgSender()] = true;
        lockedAmount[_msgSender()] = _amount;
        totalLockedTokens += _amount;
        emit LockJoin(_msgSender(), _amount);
    }

    /// Leaves the lock of the tokens
    /// @notice The sender will leave the locked state if he has joined it.
    /// @notice After leaving, he will auto claim the tokens and not be able to join the lock anymore.
    /// @notice The sender can leave at any time. Before the lock period, he has not gained any rewards
    /// @notice and claims only his initial allocated amount of tokens. If the lock period has started
    /// @notice and not ended yet, the sender will receive his initial allocated tokens with 30% of the
    /// @notice rewards, because of the desined penalty when leaving the locked state before end of period.
    /// @notice After the lock period has ended, the sender will receive the allocated amount of tokens
    /// @notice and the full amount of rewards.
    function lockLeave() external nonReentrant {
        if (!locked[_msgSender()]) revert("not locked");
        uint256 _penalty = 0;
        uint256 _reward = 0;
        uint256 _amount = lockedAmount[_msgSender()];
        locked[_msgSender()] = false;
        lockedAmount[_msgSender()] = 0;
        totalLockedTokens -= _amount;

        if (startTimestamp > 0) {
            (, _penalty, _reward) = _calcRewards(_amount, startTimestamp);
            _amount += _reward;
        } else emit Claimed(_msgSender(), _amount);

        if (!IERC20(token).transfer(_msgSender(), _amount)) revert("payout failed");
        claimed[_msgSender()] = true;
        claimedAmount[_msgSender()] = _amount;
        totalClaimedTokens += _amount;

        emit LockLeave(_msgSender(), _amount, _reward, _penalty);
    }

    /// viewables

    struct StatsForQualifier {
        bool isWhitelisted;
        bool hasClaimed;
        bool hasLocked;
        uint256 tokenBalance;
        uint256 lockedAmount;
        uint256 claimedAmount;
        uint256 totalDeposited;
        uint256 currentRewardAmount;
        uint256 currentPenaltyAmount;
        uint256 currentRewardAmountNet;
        uint256 estimatedTotalRewardAmount;
        uint256 estimatedTotalClaimAmount;
    }

    /// Returns atm stats for a given qualifier
    /// @param _qualifier address of the account
    /// @return _stats statistics for a qualifier
    /// @dev `isWhitelisted` flag if the qualifier is whitelisted or not
    /// @dev `hasClaimed` flag if the qualifier has claimed his tokens
    /// @dev `hasLocked` flag if the qualifier has locked his tokens
    /// @dev `tokenBalance` qualifiers balance of the token
    /// @dev `lockedAmount` amount of locked tokens
    /// @dev `claimedAmount` amount of claimed tokens
    /// @dev `totalDeposited` amount of deposited native
    /// @dev `currentRewardAmount` returns the current reward amount (only if lock period has started, else 0)
    /// @dev `currentPenaltyAmount` returns the current penalty amount if the qualifier leaves the lock (only if lock period has started, else 0)
    /// @dev `currentRewardAmountNet` returns the current rewart amount excl. penalty amount (only if lock period has started, else 0)
    /// @dev `estimatedTotalRewardAmount` potential amount of rewards qualifier receives after whole lock period
    /// @dev `estimatedTotalClaimAmount` potential total amount (accumulated + rewards) which the qualifier will receive after whole lock period
    function getStatsForQualifier(address _qualifier) external view returns (StatsForQualifier memory _stats) {
        uint256 _amount = locked[_qualifier] ? lockedAmount[_qualifier] : _calcClaimAmount(_qualifier);
        (uint256 _currentRewardAmount, uint256 _currentPenaltyAmount, uint256 _currentRewardAmountNet) = _calcRewards(
            lockedAmount[_qualifier],
            startTimestamp > 0 ? startTimestamp : block.timestamp
        );
        _stats = StatsForQualifier(
            whitelist[_qualifier],
            claimed[_qualifier],
            locked[_qualifier],
            token != address(0) ? IERC20(token).balanceOf(_qualifier) : 0,
            lockedAmount[_qualifier],
            claimedAmount[_qualifier],
            deposits[_qualifier],
            _currentRewardAmount,
            _currentPenaltyAmount,
            _currentRewardAmountNet,
            (_amount * TOTAL_REWARD_BPS) / 10_000,
            _amount + (_amount * TOTAL_REWARD_BPS) / 10_000
        );
    }

    struct Stats {
        bool collecting;
        bool claiming;
        bool lockPeriodActive;
        address token;
        uint256 tokenBalance;
        uint256 allocationLimit;
        uint256 tokensPerOneNative;
        uint256 totalDeposits;
        uint256 totalLockedTokens;
        uint256 totalClaimedTokens;
        uint256 estimatedTotalLockedTokensRewards;
        uint256 estimatedTotalLockedTokensPayouts;
        uint256 estimatedTotalTokensPayout;
        uint256 lockPeriodStarts;
        uint256 lockPeriodEnds;
        uint256 lockPeriodInSeconds;
        uint256 rewardPenaltyBps;
        uint256 totalRewardBps;
    }

    /// Returns general atm stats
    /// @return _stats statistics for a qualifier
    /// @dev `collecting` flag if the native token collection has started or not
    /// @dev `claiming` flag if the claiming has started or not (will enable claiming and locking functionality)
    /// @dev `lockPeriodActive` flag is the lock period has started
    /// @dev `token` address of the token
    /// @dev `tokenBalance` contract balance of the token
    /// @dev `allocationLimit` defined alloctaion limit
    /// @dev `tokensPerOneNative` defined tokens per one native
    /// @dev `totalDeposits` total amount of native deposits
    /// @dev `totalLockedTokens` total amount of locked tokens
    /// @dev `totalClaimedTokens` total amount of claimed tokens
    /// @dev `estimatedTotalLockedTokensRewards` estimated amount of total rewards paid for current locked tokens
    /// @dev `estimatedTotalLockedTokensPayouts` estimated amount of tokens incl. rewards which are getting paid out
    /// @dev `estimatedTotalTokensPayout` estimated amount of ALL possible paid out tokens (claimed + locked + rewards)
    /// @dev `lockPeriodStarts` the timestamp when the lock period starts
    /// @dev `lockPeriodEnds` the timestamp when the lock period ends
    /// @dev `lockPeriodInSeconds` lock period in seconds which result in 365d or 1y
    /// @dev `rewardPenaltyBps` % loyalty penalty in basis points
    /// @dev `totalRewardBps` % reward in basis points
    function getStats() external view returns (Stats memory _stats) {
        _stats = Stats(
            collecting,
            claiming,
            startTimestamp > 0,
            token,
            token != address(0) ? IERC20(token).balanceOf(address(this)) : 0,
            allocationLimit,
            tokensPerOneNative,
            totalDeposits,
            totalLockedTokens,
            totalClaimedTokens,
            (totalLockedTokens * TOTAL_REWARD_BPS) / 10_000,
            totalLockedTokens + ((totalLockedTokens * TOTAL_REWARD_BPS) / 10_000),
            ((totalDeposits * tokensPerOneNative) / 10 ** 18) + ((totalLockedTokens * TOTAL_REWARD_BPS) / 10_000),
            startTimestamp,
            startTimestamp > 0 ? startTimestamp + LOCK_PERIOD : 0,
            LOCK_PERIOD,
            REWARD_PENALTY_BPS,
            TOTAL_REWARD_BPS
        );
    }

    /// admin

    /// Starts the lock period
    function startLockPeriod() external onlyOwner {
        if (!claiming) revert("not started");
        if (startTimestamp > 0) revert("lock period already started");
        startTimestamp = block.timestamp;
        emit StartLockPeriod();
    }

    /// Recovers the native funds and sends it to the owner
    function recoverNative() external onlyOwner {
        uint256 _balance = address(this).balance;
        if (_balance > 0) payable(owner()).sendValue(_balance);
    }

    /// Recovers the tokens and sends it to the owner
    function recoverTokens(address _asset) external onlyOwner {
        uint256 _balance = IERC20(_asset).balanceOf(address(this));
        if (_balance > 0) IERC20(_asset).transfer(owner(), _balance);
    }

    /// Sets the state of the claiming
    /// @param _enable true enables, false disables
    /// @dev when enabling, automaticall disabled collectiong flag and vice versa
    function enableClaiming(bool _enable) external onlyOwner {
        if (_enable && tokensPerOneNative == 0) revert("no rate set");
        claiming = _enable;
        enableCollecting(!_enable);
        if (_enable) emit ClaimingEnabled();
        else emit ClaimingDisabled();
    }

    /// Sets the state of the collecting
    /// @param _enable true enables, false disables
    function enableCollecting(bool _enable) public onlyOwner {
        collecting = _enable;
        if (_enable) emit CollectingEnabled();
        else emit CollectingDisabled();
    }

    /// Sets the allocation rate
    /// @param _rate amount of tokens
    /// @notice this number is used to calculate the accumulated token
    function setAllocationRate(uint256 _rate) external onlyOwner {
        tokensPerOneNative = _rate;
        emit UpdatedAllocationRate(_rate);
    }

    /// Sets the deposit limit for accounts
    /// @param _limit amount of native token a participant can deposit
    function setAllocationLimit(uint256 _limit) external onlyOwner {
        allocationLimit = _limit;
        emit UpdatedAllocationLimit(_limit);
    }

    /// Sets the token address which to pay out
    /// @param _token address of the token
    function setToken(address _token) external onlyOwner {
        if (claiming) revert("claiming already started");
        token = _token;
        emit UpdatedToken(_token);
    }

    /// Adds an account to the whitelist
    /// @param _account address of the participant
    function addToWhitelist(address _account) public onlyOwner {
        whitelist[_account] = true;
        emit AddToWhitelist(_account);
    }

    /// Adds multiple accounts to the whitelist
    /// @param _accounts array of addresses of participants
    function addToWhitelistInBulk(address[] calldata _accounts) external onlyOwner {
        for (uint256 i = 0; i < _accounts.length; i++) addToWhitelist(_accounts[i]);
    }

    /// Removes the address from the whitelist
    /// @param _account address of the participant
    /// @notice When the address is being removed and has already deposited, this amount will be sent back to the account
    function removeFromWhitelist(address payable _account) external onlyOwner {
        uint256 _returnAmount = deposits[_account];
        if (_returnAmount > 0) {
            delete deposits[_account];
            totalDeposits -= _returnAmount;
            _account.sendValue(_returnAmount);
        }
        delete whitelist[_account];
        emit RemoveFromWhitelist(_account);
    }

    /// internals

    function _checkQualification() internal view {
        if (!whitelist[_msgSender()]) revert("not whitelisted");
        if (deposits[_msgSender()] == 0) revert("not deposited");
        if (claimed[_msgSender()]) revert("already claimed");
        if (locked[_msgSender()]) revert("already locked");
    }

    function _deposit(uint256 _amount, address _sender) internal nonReentrant {
        if (!collecting) revert("not started");
        if (!whitelist[_sender]) revert("not whitelisted");
        uint256 _depositAmount = _amount;
        uint256 _actual = deposits[_sender] + _depositAmount;
        if (_actual > allocationLimit) {
            uint256 _sendBack = _actual - allocationLimit;
            payable(_sender).sendValue(_sendBack);
            _depositAmount = allocationLimit - deposits[_sender];
        }
        deposits[_sender] += _depositAmount;
        totalDeposits += _depositAmount;
        emit Deposit(_sender, _amount);
    }

    function _calcClaimAmount(address _depositer) internal view returns (uint256 _amount) {
        return (tokensPerOneNative * deposits[_depositer]) / 10 ** 18;
    }

    // function _calcClaimAmountTotal() internal view returns (uint256 _amount) {
    //     return (tokensPerOneNative * totalDeposits) / 10 ** 18;
    // }

    function _calcRewards(
        uint256 _lockedAmount,
        uint256 _startTimestamp
    ) internal view returns (uint256 _amount, uint256 _penalty, uint256 _amountNet) {
        _amount = (_lockedAmount * TOTAL_REWARD_BPS) / 10_000;
        _amountNet = _amount;
        if (block.timestamp > _startTimestamp && block.timestamp < _startTimestamp + LOCK_PERIOD) {
            _amount = (((_amount * DENOMINATOR) / LOCK_PERIOD) * (block.timestamp - _startTimestamp)) / DENOMINATOR;
            _penalty = (_amount * REWARD_PENALTY_BPS) / 10_000;
        } else if (block.timestamp <= _startTimestamp) {
            _amount = 0;
            _amountNet = 0;
        }

        _amountNet = _amount - _penalty;
    }

    /// receiver
    receive() external payable {
        _deposit(msg.value, _msgSender());
    }
}
