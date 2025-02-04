// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./StakingRewards.sol";

contract StakingRewardsFactory is Ownable {
    // immutables
    address public rewardsToken;
    uint256 public stakingRewardsGenesis;

    // the staking tokens for which the rewards contract has been deployed
    address[] public stakingTokens;

    // info about rewards for a particular staking token
    struct StakingRewardsInfo {
        address stakingRewards;
        uint256 rewardAmount;
    }

    // rewards info by staking token
    mapping(address => StakingRewardsInfo)
        public stakingRewardsInfoByStakingToken;

    constructor(
        address _rewardsToken,
        uint256 _stakingRewardsGenesis,
        address initialOwner
    ) Ownable(initialOwner) {
        require(
            initialOwner != address(0),
            "StakingRewardsFactory::constructor: owner cannot be the zero address"
        );
        require(
            _stakingRewardsGenesis >= block.timestamp,
            "StakingRewardsFactory::constructor: genesis too soon"
        );

        rewardsToken = _rewardsToken;
        stakingRewardsGenesis = _stakingRewardsGenesis;
    }

    function isContract(address account) public view returns (bool) {
        return account.code.length > 0;
    }

    ///// permissioned functions

    // deploy a staking reward contract for the staking token, and store the reward amount, rewardsDuration in days
    // the reward will be distributed to the staking reward contract no sooner than the genesis
    function deploy(
        address stakingToken,
        uint256 rewardAmount,
        uint256 rewardsDuration
    ) external onlyOwner {
        require(
            isContract(stakingToken),
            "StakingRewardsFactory::deploy: Invalid staking token"
        );
        StakingRewardsInfo storage info = stakingRewardsInfoByStakingToken[
            stakingToken
        ];
        require(
            rewardsDuration > 0,
            "StakingRewardsFactory::deploy: rewardsDuration can not be zero"
        );
        require(
            info.stakingRewards == address(0),
            "StakingRewardsFactory::deploy: already deployed"
        );

        info.stakingRewards = address(
            new StakingRewards(
                /*_rewardsDistribution=*/
                address(this),
                rewardsToken,
                rewardsDuration,
                stakingToken,
                owner()
            )
        );
        info.rewardAmount = rewardAmount;
        stakingTokens.push(stakingToken);
    }

    ///// permissionless functions

    // call notifyRewardAmount for all staking tokens.
    function notifyRewardAmounts() external {
        require(
            stakingTokens.length > 0,
            "StakingRewardsFactory::notifyRewardAmounts: called before any deploys"
        );
        for (uint256 i = 0; i < stakingTokens.length; i++) {
            notifyRewardAmount(stakingTokens[i]);
        }
    }

    // notify reward amount for an individual staking token.
    // this is a fallback in case the notifyRewardAmounts costs too much gas to call for all contracts
    function notifyRewardAmount(address stakingToken) public {
        require(
            block.timestamp >= stakingRewardsGenesis,
            "StakingRewardsFactory::notifyRewardAmount: not ready"
        );

        StakingRewardsInfo storage info = stakingRewardsInfoByStakingToken[
            stakingToken
        ];
        require(
            info.stakingRewards != address(0),
            "StakingRewardsFactory::notifyRewardAmount: not deployed"
        );

        if (info.rewardAmount > 0) {
            uint256 rewardAmount = info.rewardAmount;
            info.rewardAmount = 0;

            require(
                IERC20(rewardsToken).transfer(
                    info.stakingRewards,
                    rewardAmount
                ),
                "StakingRewardsFactory::notifyRewardAmount: transfer failed"
            );
            StakingRewards(info.stakingRewards).notifyRewardAmount(
                rewardAmount
            );
        }
    }
}
