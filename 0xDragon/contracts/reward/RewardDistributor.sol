// SPDX-License-Identifier: AGPL-3.0-or-later

pragma solidity =0.8.18;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../interfaces/IMintableToken.sol";
import "../interfaces/IRewardTracker.sol";

contract RewardDistributor is Ownable {
    using SafeERC20 for IERC20;

    address public rewardToken;
    uint public tokensPerInterval;
    uint public lastDistributionTime;
    address public rewardTracker;

    event Distribute(uint amount);
    event TokensPerIntervalChange(uint amount);

    constructor(
        address _rewardToken,
        address _rewardTracker,
        uint _tokensPerInterval
    ) {
        rewardToken = _rewardToken;
        rewardTracker = _rewardTracker;
        tokensPerInterval = _tokensPerInterval;
    }

    // to help users who accidentally send their tokens to this contract
    function withdrawToken(
        address _token,
        address _account,
        uint _amount
    ) external onlyOwner {
        IERC20(_token).safeTransfer(_account, _amount);
    }

    //start reward distribution
    function updateLastDistributionTime() external onlyOwner {
        lastDistributionTime = block.timestamp;
    }

    function setTokensPerInterval(uint _amount) external onlyOwner {
        require(
            lastDistributionTime != 0,
            "RewardDistributor: invalid lastDistributionTime"
        );
        IRewardTracker(rewardTracker).updateRewards();
        tokensPerInterval = _amount;
        emit TokensPerIntervalChange(_amount);
    }

    function pendingRewards() public view returns (uint) {
        // no reward untill call updateLastDistributionTime()
        if (
            block.timestamp == lastDistributionTime || lastDistributionTime == 0
        ) {
            return 0;
        }

        uint timeDiff = block.timestamp - lastDistributionTime;
        return tokensPerInterval * timeDiff;
    }

    function distribute() external returns (uint) {
        require(
            msg.sender == rewardTracker,
            "RewardDistributor: invalid msg.sender"
        );

        uint amount = pendingRewards();
        if (amount == 0) {
            return 0;
        }

        lastDistributionTime = block.timestamp;

        amount = IMintableToken(rewardToken).mint(msg.sender, amount);

        emit Distribute(amount);
        return amount;
    }
}
