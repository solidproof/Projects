// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.2;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface ITGC {
   function lockedAmount(address account) external view returns (uint256);
   function lockToken(uint256 amount, address user) external;
   function unlockToken(uint256 amount, address user) external;
   function unlockSend(uint256 amount, address user) external;
}

contract TGCStaking {
    using SafeERC20 for IERC20;
	
	address public immutable TGC;
	
	struct UserInfo {
	  uint256 amount; 
	  uint256 rewardDebt;
	  uint256 startTime;
	  uint256 claimed;
	  uint256 lockClaimed;
	  uint256 locked;
	  uint256 pendingToClaimed;
    }
	
	struct UserInfoLock {
	  uint256 amount; 
	  uint256 startTime;
	  uint256 endTime;
	  uint256 rewardDebt;
    }
	
	struct HighestAstaStaker {
       uint256 deposited;
       address addr;
    }
	
	uint256 public totalStaked;
	uint256 public totalLocked;
	uint256 public totalStaker;
	uint256 public accTokenPerShare;
	uint256 public accTokenPerShareLock;
	uint256 public accTokenPerShareLastTxn;
	uint256 public harvestFee;
	uint256 public lockFee;
	uint256 public precisionFactor;
	
	uint256 public immutable minStakingToken;
	uint256 public immutable topStakerNumber;
	
	mapping(address => UserInfo) public mapUserInfo;
	mapping(address => mapping(uint256 => UserInfoLock)) public mapUserInfoLock;
    mapping(uint256 => HighestAstaStaker[]) public highestStakerInPool;
	mapping(address => uint256) public lockCount;
	
    event MigrateTokens(address tokenRecovered, address receiver, uint256 amount);
    event Deposit(address user, uint256 amount);
    event Withdraw(address user, uint256 amount);
	event NewUnlockFeeUpdated(uint256 newFee);
	event PoolUpdated(uint256 amount);	
	event Lock(uint256 amount, uint256 period);	
	
    constructor () {
	   harvestFee = 100;
	   lockFee = 3000;
	   topStakerNumber = 100;
	   minStakingToken = 1 * 10**18;
	   precisionFactor = 10**18;
	   TGC = address(0x1a3855143c423b4fEB5FF8ce23b5aF968eB15Fb7);
    }
	
	function deposit(uint256 amount) external {
		require(IERC20(TGC).balanceOf(msg.sender) - ITGC(TGC).lockedAmount(msg.sender) >= amount, "balance not available for staking");
		require(amount >= minStakingToken, "amount is less than minimum staking amount");
		
		if(mapUserInfo[msg.sender].amount > 0) 
		{
            uint256 pending = pendingReward(msg.sender);
            if(pending > 0) 
			{
			   mapUserInfo[msg.sender].pendingToClaimed += pending;
            }
        }
		
		if(mapUserInfo[msg.sender].amount == 0) {
		   totalStaker++;
		}
		
		mapUserInfo[msg.sender].amount += amount;
		mapUserInfo[msg.sender].startTime = block.timestamp;
		mapUserInfo[msg.sender].rewardDebt = (mapUserInfo[msg.sender].amount * accTokenPerShare) / (precisionFactor);
		
		totalStaked += amount;
		ITGC(TGC).lockToken(amount, msg.sender);
		addHighestStakedUser(mapUserInfo[msg.sender].amount, msg.sender);
        emit Deposit(msg.sender, amount);
    }
	
	function lock(uint256 amount, uint256 period) external {
		require(mapUserInfo[msg.sender].amount - mapUserInfo[msg.sender].locked >= amount, "amount is greater than available");
		require(period >= 90 days, "min 90 day locking is required");
		require(period <= 3650 days, "max locking period is 10 years");
		
		lockCount[msg.sender] += 1;
		mapUserInfo[msg.sender].locked += amount;
		totalLocked += amount;
		
		mapUserInfoLock[msg.sender][lockCount[msg.sender]].amount = amount;
		mapUserInfoLock[msg.sender][lockCount[msg.sender]].startTime = block.timestamp;
		mapUserInfoLock[msg.sender][lockCount[msg.sender]].endTime = block.timestamp + period;
		mapUserInfoLock[msg.sender][lockCount[msg.sender]].rewardDebt = (amount * accTokenPerShareLock) / (precisionFactor);
		
        emit Lock(amount, period);
    }
	
	function unlock(uint256[] calldata lockID) external {
		for(uint i=0; i < lockID.length; i++)
		{
		   if(mapUserInfoLock[msg.sender][lockID[i]].amount > 0)
		   {
		       uint256 pending = pendingRewardLock(msg.sender, lockID[i]);
			   if(pending > 0)
			   {
				   uint256 burnAmount;
				   uint256 period = mapUserInfoLock[msg.sender][lockID[i]].endTime - mapUserInfoLock[msg.sender][lockID[i]].startTime;
				   
				   if(period >= 9 * 365 days)
				   {
				       burnAmount = 0;
				   }
				   else if(period >= 8 * 365 days)
				   {
				       burnAmount = pending * 5 / 100;
				   }
				   else if(period >= 7 * 365 days)
				   {
				       burnAmount = pending * 10 / 100;
				   }
				   else if(period >= 6 * 365 days)
				   {
				       burnAmount = pending * 15 / 100;
				   }
				   else if(period >= 5 * 365 days)
				   {
				       burnAmount = pending * 20 / 100;
				   }
				   else if(period >= 4 * 365 days)
				   {
				       burnAmount = pending * 25 / 100;
				   }
				   else if(period >= 3 * 365 days)
				   {
				       burnAmount = pending * 30 / 100;
				   }
				   else if(period >= 2 * 365 days)
				   {
				       burnAmount = pending * 35 / 100;
				   }
				   else if(period >= 365 days)
				   {
				       burnAmount = pending * 40 / 100;
				   }
				   else
				   {
				       burnAmount = pending * 45 / 100;
				   }
				   
				   if(burnAmount > 0)
				   {
				       mapUserInfo[msg.sender].lockClaimed += pending - burnAmount;
				       IERC20(TGC).safeTransfer(address(0x000000000000000000000000000000000000dEaD), burnAmount);
				       IERC20(TGC).safeTransfer(address(msg.sender), pending - burnAmount);
				   }
				   else
				   {
				       mapUserInfo[msg.sender].lockClaimed += pending;
				       IERC20(TGC).safeTransfer(address(msg.sender), pending);
				   }
			   }
			   
			   totalLocked -= mapUserInfoLock[msg.sender][lockID[i]].amount;
			   mapUserInfo[msg.sender].locked -= mapUserInfoLock[msg.sender][lockID[i]].amount;
			   
			   if(mapUserInfoLock[msg.sender][lockID[i]].endTime > block.timestamp) 
			   {
				  uint256 fee = mapUserInfoLock[msg.sender][lockID[i]].amount * lockFee / 10000;
				  ITGC(TGC).unlockSend(fee, msg.sender);
				  _updatePoolLock(fee);
				  
				  uint256 pendingR = pendingReward(msg.sender);
				  if(pendingR > 0)  
				  {
					  mapUserInfo[msg.sender].pendingToClaimed += pendingR;
				  }
				  
				  totalStaked -= fee;
				  mapUserInfo[msg.sender].startTime = block.timestamp;
				  mapUserInfo[msg.sender].amount -= fee;
				  mapUserInfo[msg.sender].rewardDebt = (mapUserInfo[msg.sender].amount * accTokenPerShare) / (precisionFactor);
			   }
			   
			   mapUserInfoLock[msg.sender][lockID[i]].amount = 0;
			   mapUserInfoLock[msg.sender][lockID[i]].startTime = 0;
			   mapUserInfoLock[msg.sender][lockID[i]].endTime = 0;
			   mapUserInfoLock[msg.sender][lockID[i]].rewardDebt = 0;
		   }
		}
    }
	
	function withdrawReward() external {
		if(mapUserInfo[msg.sender].amount > 0) 
		{
            uint256 pending = pendingReward(msg.sender);
			        pending += mapUserInfo[msg.sender].pendingToClaimed; 
			if (pending > 0) 
			{
                IERC20(TGC).safeTransfer(address(msg.sender), pending);
				
			    mapUserInfo[msg.sender].rewardDebt = (mapUserInfo[msg.sender].amount * accTokenPerShare) / (precisionFactor);
				mapUserInfo[msg.sender].claimed += pending;
				mapUserInfo[msg.sender].pendingToClaimed = 0;
			    emit Withdraw(msg.sender, pending);
            }
        } 
    }
	
	function withdrawRewardLock(uint256[] calldata lockID) external {
		for(uint i=0; i < lockID.length; i++)
		{
		   if(mapUserInfoLock[msg.sender][lockID[i]].amount > 0)
		   {
		       uint256 pending = pendingRewardLock(msg.sender, lockID[i]);
			   if(pending > 0)
			   {
			       mapUserInfoLock[msg.sender][lockID[i]].rewardDebt += pending;
				   uint256 period = mapUserInfoLock[msg.sender][lockID[i]].endTime - mapUserInfoLock[msg.sender][lockID[i]].startTime;
				   uint256 burnAmount;
				   
				   if(period >= 9 * 365 days)
				   {
				       burnAmount = 0;
				   }
				   else if(period >= 8 * 365 days)
				   {
				       burnAmount = pending * 5 / 100;
				   }
				   else if(period >= 7 * 365 days)
				   {
				       burnAmount = pending * 10 / 100;
				   }
				   else if(period >= 6 * 365 days)
				   {
				       burnAmount = pending * 15 / 100;
				   }
				   else if(period >= 5 * 365 days)
				   {
				       burnAmount = pending * 20 / 100;
				   }
				   else if(period >= 4 * 365 days)
				   {
				       burnAmount = pending * 25 / 100;
				   }
				   else if(period >= 3 * 365 days)
				   {
				       burnAmount = pending * 30 / 100;
				   }
				   else if(period >= 2 * 365 days)
				   {
				       burnAmount = pending * 35 / 100;
				   }
				   else if(period >= 365 days)
				   {
				       burnAmount = pending * 40 / 100;
				   }
				   else
				   {
				       burnAmount = pending * 45 / 100;
				   }
				   
				   if(burnAmount > 0)
				   {
				       mapUserInfo[msg.sender].lockClaimed += pending - burnAmount;
				       IERC20(TGC).safeTransfer(address(0x000000000000000000000000000000000000dEaD), burnAmount);
				       IERC20(TGC).safeTransfer(address(msg.sender), pending - burnAmount);
				   }
				   else
				   {
				       mapUserInfo[msg.sender].lockClaimed += pending;
				       IERC20(TGC).safeTransfer(address(msg.sender), pending);
				   }
				   emit Withdraw(msg.sender, pending);
			   }
            }
		}	
    }
	
	function withdraw(uint256 amount) external {
	    require(mapUserInfo[msg.sender].amount - mapUserInfo[msg.sender].locked >= amount, "amount is greater than available");
		
		if(mapUserInfo[msg.sender].amount > amount)
		{
			uint256 pending = pendingReward(msg.sender);
					pending += mapUserInfo[msg.sender].pendingToClaimed; 
			if(pending > 0)
			{
			   IERC20(TGC).safeTransfer(address(msg.sender), pending);
			}
			totalStaked -= amount;
			
			removeHighestStakedUser(msg.sender);
		
			mapUserInfo[msg.sender].startTime = block.timestamp;
			mapUserInfo[msg.sender].amount -= amount;
			mapUserInfo[msg.sender].rewardDebt = (mapUserInfo[msg.sender].amount * accTokenPerShare) / (precisionFactor);
			mapUserInfo[msg.sender].claimed += pending;
			mapUserInfo[msg.sender].pendingToClaimed = 0;
			
			uint256 fee = amount * harvestFee / 10000;
		    ITGC(TGC).unlockSend(fee, msg.sender);
			ITGC(TGC).unlockToken(amount - fee, msg.sender);
			_updatePool(fee);
			
			addHighestStakedUser(mapUserInfo[msg.sender].amount, msg.sender);
			emit Withdraw(msg.sender, pending + amount);
		}
		else
		{
			uint256 pending = pendingReward(msg.sender);
					pending += mapUserInfo[msg.sender].pendingToClaimed; 
			if(pending > 0)
			{
			   IERC20(TGC).safeTransfer(address(msg.sender), pending);
			}
			totalStaked -= amount;
			
			uint256 fee = amount * harvestFee / 10000;
		    ITGC(TGC).unlockSend(fee, msg.sender);
			ITGC(TGC).unlockToken(amount - fee, msg.sender);
			_updatePool(fee);
			totalStaker--;
			
			removeHighestStakedUser(msg.sender);
			
			mapUserInfo[msg.sender].startTime = 0;
			mapUserInfo[msg.sender].amount = 0;
			mapUserInfo[msg.sender].rewardDebt = 0;
			mapUserInfo[msg.sender].claimed += pending;
			mapUserInfo[msg.sender].pendingToClaimed = 0;
			emit Withdraw(msg.sender, pending + amount);
		}
         
    }
	
	function _updatePoolLock(uint256 amount) internal {
	    if(totalLocked > 0) 
		{
		    accTokenPerShareLock = accTokenPerShareLock + (amount * precisionFactor) / totalLocked;
		}
		emit PoolUpdated(amount);
    }
	
	function _updatePool(uint256 amount) internal {
		if(totalStaked > 0) 
		{
			accTokenPerShare = accTokenPerShare + (amount * precisionFactor) / totalStaked;
			accTokenPerShareLastTxn = amount;
		}
		emit PoolUpdated(amount);
    }
	
	function updatePool(uint256 amount) external {
	   require(msg.sender == address(TGC), "sender not allowed");
	   _updatePool(amount);
    }
	
	function pendingReward(address user) public view returns (uint256) {
		if(mapUserInfo[user].amount > 0) 
		{
            uint256 pending = (mapUserInfo[user].amount * accTokenPerShare) / (precisionFactor) - mapUserInfo[user].rewardDebt;
			return pending;
        } 
		else 
		{
		   return 0;
		}
    }
	
	function pendingRewardLock(address user, uint256 id) public view returns (uint256) {
		if(mapUserInfoLock[user][id].amount > 0)
		{
		    uint256 pending = (mapUserInfoLock[user][id].amount * accTokenPerShareLock) / (precisionFactor) - mapUserInfoLock[user][id].rewardDebt;
			return pending;
		}
		else
		{
		   return 0;
		}
    }
	
	function quickSort(uint256 pid, uint256 left, uint256 right) internal {
        HighestAstaStaker[] storage arr = highestStakerInPool[pid];
        if (left >= right) return;
        uint256 divtwo = 2;
        uint256 p = arr[(left + right) / divtwo].deposited;
        uint256 i = left;
        uint256 j = right;
        while (i < j) 
		{
			while (arr[i].deposited < p) ++i;
			while (arr[j].deposited > p) --j;
			if (arr[i].deposited > arr[j].deposited) {
				(arr[i].deposited, arr[j].deposited) = (
				   arr[j].deposited,
				   arr[i].deposited
				);
			   (arr[i].addr, arr[j].addr) = (arr[j].addr, arr[i].addr);
			} else ++i;
        }
        if (j > left) quickSort(pid, left, j - 1);
        quickSort(pid, j + 1, right);
    }
	
	function addHighestStakedUser(uint256 amount, address user) private {
        uint256 i;
        HighestAstaStaker[] storage highestStaker = highestStakerInPool[0];
        for (i = 0; i < highestStaker.length; i++) {
			if (highestStaker[i].addr == user) {
			    highestStaker[i].deposited = amount;
			    quickSort(0, 0, highestStaker.length - 1);
				return;
			}
        }
		
        if(highestStaker.length < topStakerNumber)
		{
            highestStaker.push(HighestAstaStaker(amount, user));
            quickSort(0, 0, highestStaker.length - 1);
        } 
		else 
		{
            if (highestStaker[0].deposited < amount) 
			{
                highestStaker[0].deposited = amount;
                highestStaker[0].addr = user;
                quickSort(0, 0, highestStaker.length - 1);
            }
        }
    }
	
	function removeHighestStakedUser(address user) private {
        HighestAstaStaker[] storage highestStaker = highestStakerInPool[0];
        for (uint256 i = 0; i < highestStaker.length; i++) {
            if (highestStaker[i].addr == user) {
                delete highestStaker[i];
                return;
            }
        }
    }
	
	function checkHighestStaker(address user) external view returns (bool){
        HighestAstaStaker[] storage highestStaker = highestStakerInPool[0];
        uint256 i = 0;
        for (i; i < highestStaker.length; i++) {
            if (highestStaker[i].addr == user) {
                return true;
            }
        }
		return false;
    }
}
