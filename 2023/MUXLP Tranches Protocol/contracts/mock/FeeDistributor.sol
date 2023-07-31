// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./interfaces/IRewardDistributor.sol";
import "./interfaces/IMlpRewardTracker.sol";
import "./interfaces/IMuxRewardTracker.sol";
import "./interfaces/IVotingEscrow.sol";
import "./interfaces/IRewardRouter.sol";

contract FeeDistributor is ReentrancyGuardUpgradeable, OwnableUpgradeable, IRewardDistributor {
    using SafeMathUpgradeable for uint256;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    uint256 public constant EPOCH_PERIOD = 7 days;

    address public override rewardToken; // fee token

    address public rewardRouter;
    address public mlpRewardTracker;
    address public muxRewardTracker;

    uint256 public holderRewardProportion;

    uint256 public epochBeginTime;
    uint256 public epochEndTime;
    uint256 public lastUpdateTime;

    uint256 public override rewardRate;

    uint256 public extraRewardProportion;

    event NotifyReward(
        uint256 amount,
        uint256 rewardRate,
        uint256 _epochBeginTime,
        uint256 _epochEndTime
    );
    event Distribute(uint256 amount, uint256 toMlpAmount, uint256 toMuxAmount, uint256 toPorAmount);
    event SetHolderRewardProportion(uint256 newProportion);
    event SetExtraRewardProportion(uint256 newProportion);

    function initialize(
        address _rewardToken,
        address _rewardRouter,
        address _mlpFeeTracker,
        address _veFeeTracker,
        uint256 _holderRewardProportion
    ) external initializer {
        __Ownable_init();

        rewardToken = _rewardToken;
        rewardRouter = _rewardRouter;
        mlpRewardTracker = _mlpFeeTracker;
        muxRewardTracker = _veFeeTracker;
        _setHolderRewardProportion(_holderRewardProportion);
    }

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(address _token, address _account, uint256 _amount) external onlyOwner {
        IERC20Upgradeable(_token).safeTransfer(_account, _amount);
    }

    function setHolderRewardProportion(uint256 _proportion) external onlyOwner {
        _setHolderRewardProportion(_proportion);
    }

    function notifyReward(uint256 amount) external nonReentrant {
        require(amount > 0, "amount is zero");

        distribute();
        IERC20Upgradeable(rewardToken).safeTransferFrom(msg.sender, address(this), amount);

        uint256 _now = _blockTime();
        if (_now > epochEndTime) {
            // if epoch ended, reset epoch time
            epochBeginTime = _now;
            epochEndTime = (_now / EPOCH_PERIOD + 1) * EPOCH_PERIOD; // to next weekend
            rewardRate = amount / (epochEndTime - _now);
            lastUpdateTime = _now;
        } else {
            // if not, increase current reward rate
            rewardRate += amount / (epochEndTime - _now);
        }

        emit NotifyReward(amount, rewardRate, epochBeginTime, epochEndTime);
    }

    function pendingRewards() public view returns (uint256 totalAmount) {
        (totalAmount, , , ) = _pendingAmounts();
    }

    function pendingMlpRewards() public view returns (uint256 toMlpAmount) {
        (, toMlpAmount, , ) = _pendingAmounts();
    }

    function pendingMuxRewards() public view returns (uint256 toMuxAmount) {
        (, , toMuxAmount, ) = _pendingAmounts();
    }

    function distribute() public override {
        (
            uint256 totalAmount,
            uint256 toMlpAmount,
            uint256 toMuxAmount,
            uint256 toPmoAmount
        ) = _pendingAmounts();
        if (totalAmount == 0) {
            return;
        }
        lastUpdateTime = lastTimeRewardApplicable();
        IERC20Upgradeable _rewardToken = IERC20Upgradeable(rewardToken);
        _rewardToken.safeTransfer(muxRewardTracker, toMuxAmount);
        IMuxRewardTracker(muxRewardTracker).checkpointToken();
        _rewardToken.safeTransfer(mlpRewardTracker, toMlpAmount);
        _rewardToken.safeTransfer(IRewardRouter(rewardRouter).vault(), toPmoAmount);

        emit Distribute(totalAmount, toMlpAmount, toMuxAmount, toPmoAmount);
    }

    function lastTimeRewardApplicable() public view returns (uint256) {
        uint256 _now = _blockTime();
        return _now <= epochEndTime ? _now : epochEndTime;
    }

    function _setHolderRewardProportion(uint256 _proportion) internal {
        require(_proportion <= 1e18, "proportion exceeds 100%");
        require(extraRewardProportion + _proportion <= 1e18, "total proportion exceeds 100%");
        holderRewardProportion = _proportion;
        emit SetHolderRewardProportion(_proportion);
    }

    function _setExtraRewardProportion(uint256 _proportion) internal {
        require(_proportion <= 1e18, "proportion exceeds 100%");
        require(holderRewardProportion + _proportion <= 1e18, "total proportion exceeds 100%");
        extraRewardProportion = _proportion;
        emit SetExtraRewardProportion(_proportion);
    }

    function _getFeeDistribution(
        uint256 feeAmount
    ) internal view returns (uint256 toMlpAmount, uint256 toMuxAmount, uint256 toPmoAmount) {
        uint256 toHolderAmount = (feeAmount * holderRewardProportion) / 1e18;
        uint256 extraToVeAmount = (feeAmount * extraRewardProportion) / 1e18;
        // distribute to holder part
        toMuxAmount = (toHolderAmount * IRewardRouter(rewardRouter).poolOwnedRate()) / 1e18;
        toMlpAmount = toHolderAmount - toMuxAmount;
        // add up extra part for mux (ve)
        toMuxAmount += extraToVeAmount;
        // others goes to pol
        toPmoAmount = feeAmount - toHolderAmount - extraToVeAmount;
    }

    function _pendingAmounts()
        internal
        view
        returns (uint256 totalAmount, uint256 toMlpAmount, uint256 toMuxAmount, uint256 toPmoAmount)
    {
        uint256 periodElapsed = lastTimeRewardApplicable() - lastUpdateTime;
        // no new rewards
        if (periodElapsed == 0) {
            (totalAmount, toMlpAmount, toMuxAmount, toPmoAmount) = (0, 0, 0, 0);
        } else {
            totalAmount = rewardRate * periodElapsed;
            (toMlpAmount, toMuxAmount, toPmoAmount) = _getFeeDistribution(totalAmount);
        }
    }

    function _blockTime() internal view virtual returns (uint256) {
        return block.timestamp;
    }
}
