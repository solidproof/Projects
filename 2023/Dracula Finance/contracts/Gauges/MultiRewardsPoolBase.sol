// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "../interface/IERC20.sol";
import "../interface/IMultiRewardsPool.sol";
import "../lib/Math.sol";
import "../lib/SafeERC20.sol";
import "../lib/CheckpointLib.sol";
import "../Reentrancy.sol";

abstract contract MultiRewardsPoolBase is Reentrancy, IMultiRewardsPool {
    using SafeERC20 for IERC20;
    using CheckpointLib for mapping(uint256 => CheckpointLib.Checkpoint);

    /// @dev Operator can add/remove reward tokens
    address public operator;

    /// @dev The LP token that needs to be staked for rewards
    address public immutable override underlying;

    uint256 public override derivedSupply;
    mapping(address => uint256) public override derivedBalances;

    /// @dev Rewards are released over 7 days
    uint256 internal constant DURATION = 7 days;
    uint256 internal constant PRECISION = 10 ** 18;
    uint256 internal constant MAX_REWARD_TOKENS = 10;

    /// Default snx staking contract implementation
    /// https://github.com/Synthetixio/synthetix/blob/develop/contracts/StakingRewards.sol

    /// @dev Reward rate with precision 1e18
    mapping(address => uint256) public rewardRate;
    mapping(address => uint256) public periodFinish;
    mapping(address => uint256) public lastUpdateTime;
    mapping(address => uint256) public rewardPerTokenStored;

    mapping(address => mapping(address => uint256)) public lastEarn;
    mapping(address => mapping(address => uint256))
        public userRewardPerTokenStored;

    uint256 public override totalSupply;
    mapping(address => uint256) public override balanceOf;

    address[] public override rewardTokens;
    mapping(address => bool) public override isRewardToken;

    /// @notice A record of balance checkpoints for each account, by index
    mapping(address => mapping(uint256 => CheckpointLib.Checkpoint))
        public checkpoints;
    /// @notice The number of checkpoints for each account
    mapping(address => uint256) public numCheckpoints;
    /// @notice A record of balance checkpoints for each token, by index
    mapping(uint256 => CheckpointLib.Checkpoint) public supplyCheckpoints;
    /// @notice The number of checkpoints
    uint256 public supplyNumCheckpoints;
    /// @notice A record of balance checkpoints for each token, by index
    mapping(address => mapping(uint256 => CheckpointLib.Checkpoint))
        public rewardPerTokenCheckpoints;
    /// @notice The number of checkpoints for each token
    mapping(address => uint256) public rewardPerTokenNumCheckpoints;

    event Deposit(address indexed from, uint256 amount);
    event Withdraw(address indexed from, uint256 amount);
    event NotifyReward(
        address indexed from,
        address indexed reward,
        uint256 amount
    );
    event ClaimRewards(
        address indexed from,
        address indexed reward,
        uint256 amount,
        address recepient
    );

    constructor(
        address _stake,
        address _operator,
        address[] memory _allowedRewardTokens
    ) {
        underlying = _stake;
        operator = _operator;
        for (uint256 i; i < _allowedRewardTokens.length; i++) {
            if (_allowedRewardTokens[i] != address(0)) {
                _registerRewardToken(_allowedRewardTokens[i]);
            }
        }
    }

    modifier onlyOperator() {
        require(msg.sender == operator, "Not operator");
        _;
    }

    //**************************************************************************
    //************************ VIEWS *******************************************
    //**************************************************************************

    function getRewardTokens() external view returns (address[] memory) {
        return rewardTokens;
    }

    function rewardTokensLength() external view override returns (uint256) {
        return rewardTokens.length;
    }

    function rewardPerToken(address token) external view returns (uint256) {
        return _rewardPerToken(token);
    }

    function _rewardPerToken(address token) internal view returns (uint256) {
        if (derivedSupply == 0) {
            return rewardPerTokenStored[token];
        }
        return
            rewardPerTokenStored[token] +
            (((_lastTimeRewardApplicable(token) -
                Math.min(lastUpdateTime[token], periodFinish[token])) *
                rewardRate[token]) / derivedSupply);
    }

    function derivedBalance(
        address account
    ) external view override returns (uint256) {
        return _derivedBalance(account);
    }

    function left(address token) external view override returns (uint256) {
        if (block.timestamp >= periodFinish[token]) return 0;
        uint256 _remaining = periodFinish[token] - block.timestamp;
        return (_remaining * rewardRate[token]) / PRECISION;
    }

    function earned(
        address token,
        address account
    ) external view override returns (uint256) {
        return _earned(token, account);
    }

    //**************************************************************************
    //************************ OPERATOR ACTIONS ********************************
    //**************************************************************************

    function registerRewardToken(address token) external onlyOperator {
        _registerRewardToken(token);
    }

    function _registerRewardToken(address token) internal {
        require(
            rewardTokens.length < MAX_REWARD_TOKENS,
            "Too many reward tokens"
        );
        require(!isRewardToken[token], "Already registered");
        isRewardToken[token] = true;
        rewardTokens.push(token);
    }

    function removeRewardToken(address token) external onlyOperator {
        require(periodFinish[token] < block.timestamp, "Rewards not ended");
        require(isRewardToken[token], "Not reward token");

        isRewardToken[token] = false;
        uint256 length = rewardTokens.length;
        require(length > 3, "First 3 tokens should not be removed");
        // keep 3 tokens as guarantee against malicious actions
        // assume it will be FANG + pool tokens
        uint256 i = 3;
        bool found = false;
        for (; i < length; i++) {
            address t = rewardTokens[i];
            if (t == token) {
                found = true;
                break;
            }
        }
        require(found, "First tokens forbidden to remove");
        rewardTokens[i] = rewardTokens[length - 1];
        rewardTokens.pop();
    }

    //**************************************************************************
    //************************ USER ACTIONS ************************************
    //**************************************************************************

    function _deposit(uint256 amount) internal virtual lock {
        require(amount > 0, "Zero amount");
        _increaseBalance(msg.sender, amount);
        IERC20(underlying).safeTransferFrom(msg.sender, address(this), amount);
        emit Deposit(msg.sender, amount);
    }

    function _increaseBalance(
        address account,
        uint256 amount
    ) internal virtual {
        _updateRewardForAllTokens();

        totalSupply += amount;
        balanceOf[account] += amount;

        _updateDerivedBalanceAndWriteCheckpoints(account);
    }

    function _withdraw(uint256 amount) internal virtual lock {
        _decreaseBalance(msg.sender, amount);
        IERC20(underlying).safeTransfer(msg.sender, amount);
        emit Withdraw(msg.sender, amount);
    }

    function _decreaseBalance(
        address account,
        uint256 amount
    ) internal virtual {
        _updateRewardForAllTokens();

        totalSupply -= amount;
        balanceOf[account] -= amount;

        _updateDerivedBalanceAndWriteCheckpoints(account);
    }

    /// @dev Implement restriction checks!
    function _getReward(
        address account,
        address[] memory tokens,
        address recipient
    ) internal virtual lock {
        for (uint256 i = 0; i < tokens.length; i++) {
            (
                rewardPerTokenStored[tokens[i]],
                lastUpdateTime[tokens[i]]
            ) = _updateRewardPerToken(tokens[i], type(uint256).max, true);

            uint256 _reward = _earned(tokens[i], account);
            lastEarn[tokens[i]][account] = block.timestamp;
            userRewardPerTokenStored[tokens[i]][account] = rewardPerTokenStored[
                tokens[i]
            ];
            if (_reward > 0) {
                IERC20(tokens[i]).safeTransfer(recipient, _reward);
            }

            emit ClaimRewards(msg.sender, tokens[i], _reward, recipient);
        }

        _updateDerivedBalanceAndWriteCheckpoints(account);
    }

    function _updateDerivedBalanceAndWriteCheckpoints(
        address account
    ) internal {
        uint256 __derivedBalance = derivedBalances[account];
        derivedSupply -= __derivedBalance;
        __derivedBalance = _derivedBalance(account);
        derivedBalances[account] = __derivedBalance;
        derivedSupply += __derivedBalance;

        _writeCheckpoint(account, __derivedBalance);
        _writeSupplyCheckpoint();
    }

    //**************************************************************************
    //************************ REWARDS CALCULATIONS ****************************
    //**************************************************************************

    // earned is an estimation, it won't be exact till the supply > rewardPerToken calculations have run
    function _earned(
        address token,
        address account
    ) internal view returns (uint256) {
        // zero checkpoints means zero deposits
        if (numCheckpoints[account] == 0) {
            return 0;
        }
        // last claim rewards time
        uint256 _startTimestamp = Math.max(
            lastEarn[token][account],
            rewardPerTokenCheckpoints[token][0].timestamp
        );

        // find an index of the balance that the user had on the last claim
        uint256 _startIndex = _getPriorBalanceIndex(account, _startTimestamp);
        uint256 _endIndex = numCheckpoints[account] - 1;

        uint256 reward = 0;

        // calculate previous snapshots if exist
        if (_endIndex > 0) {
            for (uint256 i = _startIndex; i <= _endIndex - 1; i++) {
                CheckpointLib.Checkpoint memory cp0 = checkpoints[account][i];
                CheckpointLib.Checkpoint memory cp1 = checkpoints[account][
                    i + 1
                ];
                (uint256 _rewardPerTokenStored0, ) = _getPriorRewardPerToken(
                    token,
                    cp0.timestamp
                );
                (uint256 _rewardPerTokenStored1, ) = _getPriorRewardPerToken(
                    token,
                    cp1.timestamp
                );
                reward +=
                    (cp0.value *
                        (_rewardPerTokenStored1 - _rewardPerTokenStored0)) /
                    PRECISION;
            }
        }

        CheckpointLib.Checkpoint memory cp = checkpoints[account][_endIndex];
        (uint256 _rewardPerTokenStored, ) = _getPriorRewardPerToken(
            token,
            cp.timestamp
        );
        reward +=
            (cp.value *
                (_rewardPerToken(token) -
                    Math.max(
                        _rewardPerTokenStored,
                        userRewardPerTokenStored[token][account]
                    ))) /
            PRECISION;
        return reward;
    }

    function _derivedBalance(
        address account
    ) internal view virtual returns (uint256) {
        // supposed to be implemented in a parent contract
        return balanceOf[account];
    }

    /// @dev Update stored rewardPerToken values without the last one snapshot
    ///      If the contract will get "out of gas" error on users actions this will be helpful
    function batchUpdateRewardPerToken(
        address token,
        uint256 maxRuns
    ) external {
        (
            rewardPerTokenStored[token],
            lastUpdateTime[token]
        ) = _updateRewardPerToken(token, maxRuns, false);
    }

    function _updateRewardForAllTokens() internal {
        uint256 length = rewardTokens.length;
        for (uint256 i; i < length; i++) {
            address token = rewardTokens[i];
            (
                rewardPerTokenStored[token],
                lastUpdateTime[token]
            ) = _updateRewardPerToken(token, type(uint256).max, true);
        }
    }

    /// @dev Should be called only with properly updated snapshots, or with actualLast=false
    function _updateRewardPerToken(
        address token,
        uint256 maxRuns,
        bool actualLast
    ) internal returns (uint256, uint256) {
        uint256 _startTimestamp = lastUpdateTime[token];
        uint256 reward = rewardPerTokenStored[token];

        if (supplyNumCheckpoints == 0) {
            return (reward, _startTimestamp);
        }

        if (rewardRate[token] == 0) {
            return (reward, block.timestamp);
        }
        uint256 _startIndex = _getPriorSupplyIndex(_startTimestamp);
        uint256 _endIndex = Math.min(supplyNumCheckpoints - 1, maxRuns);

        if (_endIndex > 0) {
            for (uint256 i = _startIndex; i <= _endIndex - 1; i++) {
                CheckpointLib.Checkpoint memory sp0 = supplyCheckpoints[i];
                if (sp0.value > 0) {
                    CheckpointLib.Checkpoint memory sp1 = supplyCheckpoints[
                        i + 1
                    ];
                    (uint256 _reward, uint256 _endTime) = _calcRewardPerToken(
                        token,
                        sp1.timestamp,
                        sp0.timestamp,
                        sp0.value,
                        _startTimestamp
                    );
                    reward += _reward;
                    _writeRewardPerTokenCheckpoint(token, reward, _endTime);
                    _startTimestamp = _endTime;
                }
            }
        }

        // need to override the last value with actual numbers only on deposit/withdraw/claim/notify actions
        if (actualLast) {
            CheckpointLib.Checkpoint memory sp = supplyCheckpoints[_endIndex];
            if (sp.value > 0) {
                (uint256 _reward, ) = _calcRewardPerToken(
                    token,
                    _lastTimeRewardApplicable(token),
                    Math.max(sp.timestamp, _startTimestamp),
                    sp.value,
                    _startTimestamp
                );
                reward += _reward;
                _writeRewardPerTokenCheckpoint(token, reward, block.timestamp);
                _startTimestamp = block.timestamp;
            }
        }

        return (reward, _startTimestamp);
    }

    function _calcRewardPerToken(
        address token,
        uint256 lastSupplyTs1,
        uint256 lastSupplyTs0,
        uint256 supply,
        uint256 startTimestamp
    ) internal view returns (uint256, uint256) {
        uint256 endTime = Math.max(lastSupplyTs1, startTimestamp);
        uint256 _periodFinish = periodFinish[token];
        return (
            ((Math.min(endTime, _periodFinish) -
                Math.min(
                    Math.max(lastSupplyTs0, startTimestamp),
                    _periodFinish
                )) * rewardRate[token]) / supply,
            endTime
        );
    }

    /// @dev Returns the last time the reward was modified or periodFinish if the reward has ended
    function _lastTimeRewardApplicable(
        address token
    ) internal view returns (uint256) {
        return Math.min(block.timestamp, periodFinish[token]);
    }

    //**************************************************************************
    //************************ NOTIFY ******************************************
    //**************************************************************************

    function _notifyRewardAmount(
        address token,
        uint256 amount
    ) internal virtual lock {
        require(token != underlying, "Wrong token for rewards");
        require(amount > 0, "Zero amount");
        require(isRewardToken[token], "Token not allowed");
        if (rewardRate[token] == 0) {
            _writeRewardPerTokenCheckpoint(token, 0, block.timestamp);
        }
        (
            rewardPerTokenStored[token],
            lastUpdateTime[token]
        ) = _updateRewardPerToken(token, type(uint256).max, true);

        if (block.timestamp >= periodFinish[token]) {
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
            rewardRate[token] = (amount * PRECISION) / DURATION;
        } else {
            uint256 _remaining = periodFinish[token] - block.timestamp;
            uint256 _left = _remaining * rewardRate[token];
            // not sure what the reason was in the original solidly implementation for this restriction
            // however, by design probably it is a good idea against human errors
            require(
                amount > _left / PRECISION,
                "Amount should be higher than remaining rewards"
            );
            IERC20(token).safeTransferFrom(msg.sender, address(this), amount);
            rewardRate[token] = (amount * PRECISION + _left) / DURATION;
        }

        periodFinish[token] = block.timestamp + DURATION;
        emit NotifyReward(msg.sender, token, amount);
    }

    //**************************************************************************
    //************************ CHECKPOINTS *************************************
    //**************************************************************************

    function getPriorBalanceIndex(
        address account,
        uint256 timestamp
    ) external view returns (uint256) {
        return _getPriorBalanceIndex(account, timestamp);
    }

    /// @notice Determine the prior balance for an account as of a block number
    /// @dev Block number must be a finalized block or else this function will revert to prevent misinformation.
    /// @param account The address of the account to check
    /// @param timestamp The timestamp to get the balance at
    /// @return The balance the account had as of the given block
    function _getPriorBalanceIndex(
        address account,
        uint256 timestamp
    ) internal view returns (uint256) {
        uint256 nCheckpoints = numCheckpoints[account];
        if (nCheckpoints == 0) {
            return 0;
        }
        return checkpoints[account].findLowerIndex(nCheckpoints, timestamp);
    }

    function getPriorSupplyIndex(
        uint256 timestamp
    ) external view returns (uint256) {
        return _getPriorSupplyIndex(timestamp);
    }

    function _getPriorSupplyIndex(
        uint256 timestamp
    ) internal view returns (uint256) {
        uint256 nCheckpoints = supplyNumCheckpoints;
        if (nCheckpoints == 0) {
            return 0;
        }
        return supplyCheckpoints.findLowerIndex(nCheckpoints, timestamp);
    }

    function getPriorRewardPerToken(
        address token,
        uint256 timestamp
    ) external view returns (uint256, uint256) {
        return _getPriorRewardPerToken(token, timestamp);
    }

    function _getPriorRewardPerToken(
        address token,
        uint256 timestamp
    ) internal view returns (uint256, uint256) {
        uint256 nCheckpoints = rewardPerTokenNumCheckpoints[token];
        if (nCheckpoints == 0) {
            return (0, 0);
        }
        mapping(uint256 => CheckpointLib.Checkpoint)
            storage cps = rewardPerTokenCheckpoints[token];
        uint256 lower = cps.findLowerIndex(nCheckpoints, timestamp);
        CheckpointLib.Checkpoint memory cp = cps[lower];
        return (cp.value, cp.timestamp);
    }

    function _writeCheckpoint(address account, uint256 balance) internal {
        uint256 _timestamp = block.timestamp;
        uint256 _nCheckPoints = numCheckpoints[account];

        if (
            _nCheckPoints > 0 &&
            checkpoints[account][_nCheckPoints - 1].timestamp == _timestamp
        ) {
            checkpoints[account][_nCheckPoints - 1].value = balance;
        } else {
            checkpoints[account][_nCheckPoints] = CheckpointLib.Checkpoint(
                _timestamp,
                balance
            );
            numCheckpoints[account] = _nCheckPoints + 1;
        }
    }

    function _writeRewardPerTokenCheckpoint(
        address token,
        uint256 reward,
        uint256 timestamp
    ) internal {
        uint256 _nCheckPoints = rewardPerTokenNumCheckpoints[token];

        if (
            _nCheckPoints > 0 &&
            rewardPerTokenCheckpoints[token][_nCheckPoints - 1].timestamp ==
            timestamp
        ) {
            rewardPerTokenCheckpoints[token][_nCheckPoints - 1].value = reward;
        } else {
            rewardPerTokenCheckpoints[token][_nCheckPoints] = CheckpointLib
                .Checkpoint(timestamp, reward);
            rewardPerTokenNumCheckpoints[token] = _nCheckPoints + 1;
        }
    }

    function _writeSupplyCheckpoint() internal {
        uint256 _nCheckPoints = supplyNumCheckpoints;
        uint256 _timestamp = block.timestamp;

        if (
            _nCheckPoints > 0 &&
            supplyCheckpoints[_nCheckPoints - 1].timestamp == _timestamp
        ) {
            supplyCheckpoints[_nCheckPoints - 1].value = derivedSupply;
        } else {
            supplyCheckpoints[_nCheckPoints] = CheckpointLib.Checkpoint(
                _timestamp,
                derivedSupply
            );
            supplyNumCheckpoints = _nCheckPoints + 1;
        }
    }
}
