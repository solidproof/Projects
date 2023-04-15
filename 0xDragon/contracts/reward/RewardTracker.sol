// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity =0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

import "../interfaces/IMintableToken.sol";
import "../interfaces/IRewardDistributor.sol";
import "../interfaces/IVirtualBalanceRewardPool.sol";

import "../token/BaseToken.sol";

contract RewardTracker is BaseToken {
    using SafeERC20 for IMintableToken;

    uint public immutable PRECISION = 1e30;

    IMintableToken public fire;
    IMintableToken public esFire;

    IRewardDistributor public distributor;

    uint public maxBoost = 2;
    uint public maxBoostTime = 365 days;
    uint public minLockTime = 30 days;

    mapping(address => uint) public stakedAmount;
    uint public stakedTotalAmount;

    mapping(address => uint) public lockedAmount;
    uint public lockedTotalAmount;

    mapping(address => uint) public lockTime;

    mapping(address => uint) public boostedAmount;
    uint public boostedTotalAmount;

    mapping(address => uint) public claimableReward;
    mapping(address => uint) public previousCumulatedRewardPerToken;

    uint public cumulativeRewardPerToken;

    address[] public extraRewards;

    event Stake(address indexed user, uint amount, uint lockTime);
    event Unstake(address indexed user, uint amount, uint lockTime);
    event ClaimReward(address indexed user, uint reward, uint lockTime);

    constructor(
        IMintableToken _fire,
        IMintableToken _esFire
    ) ERC20("Staked FIRE", "sFIRE") {
        fire = _fire;
        esFire = _esFire;
    }

    function recoverToken(address[] calldata tokens) external onlyOwner {
        unchecked {
            for (uint256 i; i < tokens.length; i++) {
                IMintableToken(tokens[i]).safeTransfer(
                    msg.sender,
                    IERC20(tokens[i]).balanceOf(address(this))
                );
            }
        }
    }

    function setRewardDistributor(
        IRewardDistributor _distributor
    ) external onlyOwner {
        distributor = _distributor;
    }

    function extraRewardsLength() external view returns (uint) {
        return extraRewards.length;
    }

    function addExtraReward(address _reward) external onlyOwner {
        require(_reward != address(0), "!reward setting");

        extraRewards.push(_reward);
    }

    function clearExtraRewards() external onlyOwner {
        delete extraRewards;
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        if (inPrivateTransferMode && from != address(0) && to != address(0)) {
            BaseToken._beforeTokenTransfer(from, to, amount);
        }
    }

    function updateBoostParameters(
        uint _maxBoost,
        uint _maxBoostTime,
        uint _minLockTime
    ) external onlyOwner {
        maxBoost = _maxBoost;
        maxBoostTime = _maxBoostTime;
        minLockTime = _minLockTime;
    }

    function claimable(address _account) public view returns (uint) {
        uint staked = boostedAmount[_account];
        if (staked == 0) {
            return claimableReward[_account];
        }
        uint supply = boostedTotalAmount;
        uint pendingRewards = IRewardDistributor(distributor).pendingRewards() *
            PRECISION;
        uint nextCumulativeRewardPerToken = cumulativeRewardPerToken +
            pendingRewards /
            supply;
        return
            claimableReward[_account] +
            (staked *
                (nextCumulativeRewardPerToken -
                    previousCumulatedRewardPerToken[_account])) /
            PRECISION;
    }

    function boostMultiplier(uint _lockTime) public view returns (uint) {
        if (_lockTime > block.timestamp) {
            uint maxTime = block.timestamp + maxBoostTime;
            if (_lockTime >= maxTime) {
                return PRECISION * maxBoost;
            } else {
                return
                    PRECISION *
                    maxBoost -
                    (PRECISION * (maxBoost - 1) * (maxTime - _lockTime)) /
                    maxBoostTime;
            }
        }
        return PRECISION;
    }

    function _claim(address user) internal returns (uint) {
        _updateRewards(user);

        uint tokenAmount = claimableReward[user];
        claimableReward[user] = 0;

        if (tokenAmount > 0) {
            esFire.safeTransfer(user, tokenAmount);
            emit ClaimReward(user, tokenAmount, lockTime[user]);
        }

        if (lockedAmount[user] > 0) {
            unchecked {
                for (uint8 i; i < extraRewards.length; i++) {
                    IVirtualBalanceRewardPool(extraRewards[i])
                        .getRewardBasePool(user);
                }
            }
        }
        return tokenAmount;
    }

    function claim(uint _lockTime) external {
        if (_lockTime != 0) {
            _increaseLock(msg.sender, _lockTime);
        }
        _claim(msg.sender);
        _updateExtraRewardStaked(msg.sender, _updateBoostedAmount(msg.sender));
    }

    function claimForAccount(address account) external {
        require(isHandler[msg.sender], "RewardTracker: forbidden");
        _claim(account);
        _updateExtraRewardStaked(account, _updateBoostedAmount(account));
    }

    function _updateBoostedAmount(
        address user
    ) internal returns (uint newLockBoostAmount) {
        newLockBoostAmount =
            (lockedAmount[user] * boostMultiplier(lockTime[user])) /
            PRECISION;
        boostedTotalAmount -= boostedAmount[user];
        boostedAmount[user] = stakedAmount[user] + newLockBoostAmount;
        boostedTotalAmount += boostedAmount[user];
    }

    function _deposit(address user, uint amount, uint _lockTime) internal {
        _claim(user);

        fire.safeTransferFrom(user, address(this), amount);
        if (_lockTime != 0) {
            _increaseLock(user, _lockTime);
            lockedAmount[user] += amount;
            lockedTotalAmount += amount;
        } else {
            stakedAmount[user] += amount;
            stakedTotalAmount += amount;
        }
        _updateExtraRewardStaked(user, _updateBoostedAmount(user));

        _mint(user, amount);

        emit Stake(user, amount, _lockTime);
    }

    function deposit(uint amount, uint _lockTime) external {
        _deposit(msg.sender, amount, _lockTime);
    }

    //must increase more than minLockTime
    function _increaseLock(address user, uint _lockTime) internal {
        require(_lockTime >= lockTime[user], "Invalid lock time");
        if (_lockTime > lockTime[user]) {
            require(
                _lockTime >= block.timestamp + minLockTime,
                "Increase lock too short"
            );
        }
        lockTime[user] = _lockTime;
    }

    function _updateExtraRewardStaked(address user, uint newAmount) internal {
        if (lockTime[user] <= block.timestamp) {
            newAmount = 0;
        }
        unchecked {
            for (uint8 i; i < extraRewards.length; i++) {
                IVirtualBalanceRewardPool(extraRewards[i]).updateStaked(
                    user,
                    newAmount
                );
            }
        }
    }

    function _withdraw(address user, uint amount, uint _lockTime) internal {
        _claim(user);
        if (_lockTime != 0) {
            require(block.timestamp > lockTime[user], "Still locked");
            require(amount <= lockedAmount[user], "Too much");

            _increaseLock(user, _lockTime);
            lockedAmount[user] -= amount;
            lockedTotalAmount -= amount;
        } else {
            require(amount <= stakedAmount[user], "Too much");
            stakedAmount[user] -= amount;
            stakedTotalAmount -= amount;
        }
        _updateExtraRewardStaked(user, _updateBoostedAmount(user));

        fire.safeTransfer(user, amount);

        _burn(user, amount);

        emit Unstake(user, amount, lockTime[user]);
    }

    function withdraw(uint amount, uint _lockTime) external {
        _withdraw(msg.sender, amount, _lockTime);
    }

    function updateRewards() external {
        _updateRewards(address(0));
    }

    function _updateRewards(address _account) private {
        uint blockReward;

        if (address(distributor) != address(0)) {
            blockReward = IRewardDistributor(distributor).distribute();
        }

        uint _cumulativeRewardPerToken = cumulativeRewardPerToken;
        uint totalStaked = boostedTotalAmount;
        // only update cumulativeRewardPerToken when there are stakers, i.e. when totalStaked > 0
        // if blockReward == 0, then there will be no change to cumulativeRewardPerToken
        if (totalStaked > 0 && blockReward > 0) {
            _cumulativeRewardPerToken +=
                (blockReward * PRECISION) /
                totalStaked;
            cumulativeRewardPerToken = _cumulativeRewardPerToken;
        }

        // cumulativeRewardPerToken can only increase
        // so if cumulativeRewardPerToken is zero, it means there are no rewards yet
        if (_cumulativeRewardPerToken == 0) {
            return;
        }

        if (_account != address(0)) {
            uint stakedBalance = boostedAmount[_account];
            uint _previousCumulatedReward = previousCumulatedRewardPerToken[
                _account
            ];
            uint _claimableReward = claimableReward[_account] +
                (stakedBalance *
                    (_cumulativeRewardPerToken - _previousCumulatedReward)) /
                PRECISION;

            claimableReward[_account] = _claimableReward;
            previousCumulatedRewardPerToken[
                _account
            ] = _cumulativeRewardPerToken;
        }
    }
}
