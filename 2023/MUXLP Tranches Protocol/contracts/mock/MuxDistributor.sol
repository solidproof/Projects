// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

import "./interfaces/IRewardDistributor.sol";
import "./interfaces/IMintable.sol";
import "./interfaces/IMuxRewardTracker.sol";
import "./interfaces/IRewardRouter.sol";

contract MuxDistributor is ReentrancyGuardUpgradeable, OwnableUpgradeable, IRewardDistributor {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    address public override rewardToken;

    address public rewardRouter;
    address public mlpRewardTracker;
    address public muxRewardTracker;
    uint256 public lastDistributionTime;
    uint256 public override rewardRate;

    event Distribute(uint256 amount, uint256 toMlpAmount, uint256 toMuxAmount);
    event SetRewardRate(uint256 oldRewardRate, uint256 newRewardRate);

    function initialize(
        address _rewardToken,
        address _rewardRouter,
        address _mlpMuxTracker,
        address _veMuxTracker,
        uint256 _startTime
    ) external initializer {
        __Ownable_init();

        rewardToken = _rewardToken;
        rewardRouter = _rewardRouter;
        mlpRewardTracker = _mlpMuxTracker;
        muxRewardTracker = _veMuxTracker;
        rewardRate = (1000 * 1e18) / uint256(86400);
        lastDistributionTime = _startTime;
    }

    function setRewardRate(uint256 _rewardRate) external onlyOwner {
        distribute();
        emit SetRewardRate(rewardRate, _rewardRate);
        rewardRate = _rewardRate;
        uint256 _now = _blockTime();
        if (_now >= lastDistributionTime) {
            lastDistributionTime = _now;
        }
    }

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(address _token, address _account, uint256 _amount) external onlyOwner {
        IERC20Upgradeable(_token).safeTransfer(_account, _amount);
    }

    function setLastDistributionTime(uint256 distributionTime) external onlyOwner {
        require(lastDistributionTime <= distributionTime, "Can not set passed time");
        distribute();
        lastDistributionTime = distributionTime;
    }

    function pendingRewards() public view override returns (uint256 totalAmount) {
        (totalAmount, , ) = _pendingAmounts();
    }

    function pendingMlpRewards() public view returns (uint256 toMlpAmount) {
        (, toMlpAmount, ) = _pendingAmounts();
    }

    function pendingMuxRewards() public view returns (uint256 toMuxAmount) {
        (, , toMuxAmount) = _pendingAmounts();
    }

    function distribute() public override {
        if (_blockTime() <= lastDistributionTime) {
            return;
        }
        (uint256 totalAmount, uint256 toMlpAmount, uint256 toMuxAmount) = _pendingAmounts();
        if (totalAmount == 0) {
            return;
        }
        lastDistributionTime = _blockTime();
        IMintable(rewardToken).mint(muxRewardTracker, toMuxAmount);
        IMuxRewardTracker(muxRewardTracker).checkpointToken();
        IMintable(rewardToken).mint(mlpRewardTracker, toMlpAmount);

        emit Distribute(totalAmount, toMlpAmount, toMuxAmount);
    }

    function _getMuxDistribution(
        uint256 amount
    ) internal view returns (uint256 toMlpAmount, uint256 toVeMuxAmount) {
        toMlpAmount = ((amount * (1e18 - IRewardRouter(rewardRouter).poolOwnedRate())) / 1e18);
        toMlpAmount =
            (toMlpAmount * (1e18 - IRewardRouter(rewardRouter).votingEscrowedRate())) /
            1e18;
        toVeMuxAmount = amount - toMlpAmount;
    }

    function _pendingAmounts()
        internal
        view
        returns (uint256 totalAmount, uint256 toMlpAmount, uint256 toMuxAmount)
    {
        uint256 _now = _blockTime();
        if (lastDistributionTime == 0 || _now <= lastDistributionTime) {
            (totalAmount, toMlpAmount, toMuxAmount) = (0, 0, 0);
        } else {
            uint256 timeDiff = _now - lastDistributionTime;
            totalAmount = rewardRate * timeDiff;
            (toMlpAmount, toMuxAmount) = _getMuxDistribution(totalAmount);
        }
    }

    function _blockTime() internal view virtual returns (uint256) {
        return block.timestamp;
    }
}
