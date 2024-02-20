// Turbo Treats :: Crypto Culinary Sensation!

// Decentralized DAO & Staking
// Fixed Supply
// Staking With No Time Limit Bound
// Staking APR Based on Trading Volume
// Harvest Staking Reward Any Time
// Zero Fee on Stake, Unstake and Harvest
// Submit Proposal and Earn ETH by DAO

// Website  : https://turbotreats.xyz
// Staking  : https://turbotreats.xyz/staking
// DAO      : https://turbotreats.xyz/dao
// Twitter  : https://twitter.com/turbo_treats
// Discord  : https://discord.com/invite/DjzNgj5T
// YouTube  : https://www.youtube.com/@Turbo-iy9nv
// Email    : info@turbotreats.xyz

// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract TurboTreatsStaking {
    using SafeERC20 for IERC20;
	
    address public TurboTreats;
	
	uint256 public rewardPerShare;
	uint256 public precisionFactor;
	uint256 public TurboTreatsStaked;
	uint256 public TurboTreatsDistributed;
	uint256 public TurboTreatsUndistributed;
	
	struct StakingInfo {
	   uint256 stakedAmount; 
	   uint256 pendingReward;
	   uint256 claimedReward;
	   uint256 totalClaimed;
    }
	mapping(address => StakingInfo) public mapStakingInfo;
	
	event Stake(address staker, uint256 amount);
	event Unstake(address staker, uint256 amount);
	event Harvest(address staker, uint256 amount);
	event PoolUpdated(uint256 amount);
	
    constructor() {
	   TurboTreats = address(0xdd9E0F62d06d1DF429cE5339C30c676D7D4Ec740);
       precisionFactor = 1 ether;
    }
	
	function stake(uint256 amount) external {
		require(IERC20(TurboTreats).balanceOf(msg.sender) >= amount, "Balance not available for staking");
		
		if(mapStakingInfo[address(msg.sender)].stakedAmount > 0) 
		{
            uint256 pending = pendingReward(address(msg.sender));
            if(pending > 0)
			{
			    mapStakingInfo[address(msg.sender)].pendingReward = pending;
            }
        }
		IERC20(TurboTreats).safeTransferFrom(address(msg.sender), address(this), amount);
		TurboTreatsStaked += amount;
		mapStakingInfo[address(msg.sender)].stakedAmount += amount;
		mapStakingInfo[address(msg.sender)].claimedReward = mapStakingInfo[address(msg.sender)].stakedAmount * rewardPerShare / precisionFactor;
        emit Stake(address(msg.sender), amount);
    }
	
	function unstake(uint256 amount) external {
		require(mapStakingInfo[address(msg.sender)].stakedAmount >= amount, "Amount is greater than staked");
		
	    if(mapStakingInfo[address(msg.sender)].stakedAmount > amount) 
		{
			uint256 pending = pendingReward(address(msg.sender));
			
			mapStakingInfo[address(msg.sender)].pendingReward = pending;
			IERC20(TurboTreats).safeTransfer(address(msg.sender), amount);
			TurboTreatsStaked -= amount;
			
			mapStakingInfo[address(msg.sender)].stakedAmount -= amount;
		    mapStakingInfo[address(msg.sender)].claimedReward = mapStakingInfo[address(msg.sender)].stakedAmount * rewardPerShare / precisionFactor;
			emit Unstake(msg.sender, amount);
        }
        else
		{
		    uint256 pending = pendingReward(address(msg.sender));
			IERC20(TurboTreats).safeTransfer(address(msg.sender), (amount + pending));
			TurboTreatsStaked -= amount;
			
			mapStakingInfo[address(msg.sender)].stakedAmount = 0;
		    mapStakingInfo[address(msg.sender)].claimedReward = 0;
			mapStakingInfo[address(msg.sender)].pendingReward = 0;
			mapStakingInfo[address(msg.sender)].totalClaimed += pending;
			emit Unstake(msg.sender, amount);
		}		
    }
	
	function harvest(uint256 amount) external {
	
		if(mapStakingInfo[address(msg.sender)].stakedAmount > 0) 
		{
		    uint256 pending = pendingReward(address(msg.sender));
            if(pending >= amount)
		    {
			    IERC20(TurboTreats).safeTransfer(address(msg.sender), amount);
				
			    mapStakingInfo[address(msg.sender)].claimedReward += amount;
			    mapStakingInfo[address(msg.sender)].totalClaimed += amount;
			    emit Harvest(msg.sender, amount);
		    }
        } 
    }
	
	function pendingReward(address staker) public view returns (uint256) {
		if(mapStakingInfo[address(staker)].stakedAmount > 0) 
		{
            uint256 pending = (((mapStakingInfo[address(staker)].stakedAmount * rewardPerShare) / precisionFactor) + mapStakingInfo[address(staker)].pendingReward) - (mapStakingInfo[address(staker)].claimedReward);
		    return pending;
        } 
		else 
		{
		   return 0;
		}
    }
	
	function updatePool(uint256 amount) external {
		require(address(msg.sender) == address(TurboTreats), "Incorrect request");
		if(TurboTreatsStaked > 0)
		{
		    uint256 totalAmount = TurboTreatsUndistributed + amount;
		    rewardPerShare = rewardPerShare + (totalAmount * precisionFactor / TurboTreatsStaked);
			TurboTreatsUndistributed = 0;
		}
		else
		{
		    TurboTreatsUndistributed += amount;
		}
		TurboTreatsDistributed += amount;
		emit PoolUpdated(amount);
    }
}