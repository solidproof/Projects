// SPDX-License-Identifier: MIT
pragma solidity =0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract DopeWarzStaking is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for ERC20;
    uint256 public constant MAX_TOKEN_PER_BLOCK = 10000000000000000000;
    uint256 public constant MAX_FEE = 1000; // 1000/10000 * 100 = 10%
    //uint256 public performanceFeeBurn       = 100; // 100/10000 * 100 = 1%
    uint256 public constant divisor = 10000;
    uint256  public earlyWithdrawFee         = 50; // 50/10000 * 100 = 0.5% 
    //uint256  public performanceFeeReserve    = 190; // 190/10000 * 100 = 1.9%
    uint256 public constant BLOCK_PER_SECOND = 3;
    uint256 public earlyWithdrawFeeTime = 72 * 60 * 60 / BLOCK_PER_SECOND;
    
    uint256 public totalShares;
    // Contracts to Interact with
    ERC20 public immutable drug;
    // Team address to maintain funds
    address public reserveAddress;
    
    struct UserStaking {
        uint256 shares;
        uint256 stakedAmount;
        uint256 claimedAmount;
        uint256 lastBlockCompounded;
        uint256 lastBlockStaked;
        uint256 apyBaseline;
    }
    mapping (address => UserStaking) public stakings;

    uint256 public tokenPerBlock = 1000000000000000000;
    
    // Pool Accumulated Reward Per Share (APY)
    uint256 public accRewardPerShare;
    uint256 public lastRewardBlock;
    
    // Tracking Totals
    uint256 public totalPool; // Reward for Staking
    uint256 public totalStaked;
    uint256 public totalClaimed; // Total Claimed as rewards
    uint256 public deploymentTimeStamp; 

    //total pool of funds after update
    event RewardPoolUpdated (uint256 indexed _amount); 
    //token emission per block after update
    event TokenPerBlockUpdated (uint256 indexed _amount); 
    //Early Withdrawal fee percentage after update 
    event EarlyWithdrawalFeeUpdated (uint256 indexed _amount); 
    //Early Withdrawal fee time after update
    event EarlyWithdrawalTimeUpdated (uint256 indexed _amount); 

    
    constructor (ERC20 _drug, uint256 _tokenPerBlock, address _reserveAddress) {
        require(address(_drug) != address(0x0), "DrugZ address can not be zero");
        require(_reserveAddress != address(0x0), "Reserve address can not be zero");
        drug = _drug;
        if(_tokenPerBlock <= MAX_TOKEN_PER_BLOCK){
            tokenPerBlock = _tokenPerBlock;
        }
        reserveAddress = _reserveAddress;
        deploymentTimeStamp = block.timestamp;
        lastRewardBlock = block.number;
    }
    

    /// Adds the provided amount to the totalPool
    /// @param _amount the amount to add
    /// @dev adds the provided amount to `totalPool` state variable
    function addRewardToPool (uint256 _amount) public  {
        require(drug.balanceOf(msg.sender) >= _amount, "Insufficient tokens for transfer");
        totalPool = totalPool.add(_amount);
        drug.safeTransferFrom(msg.sender, address(this), _amount);
        emit RewardPoolUpdated(totalPool);
    }

    /// @notice updates accRewardPerShare based on the last block calculated and totalShares
    /// @dev accRewardPerShare is accumulative, meaning it always holds the total historic 
    /// rewardPerShare making apyBaseline necessary to keep rewards fair
    function updateDistribution() public {
        if(block.number <= lastRewardBlock)
            return;
        if(totalStaked == 0){
            lastRewardBlock = block.number;
            return;
        }
        uint256 rewardPerBlock = tokenPerBlock;
        if(totalPool == 0)
            rewardPerBlock = 0;
        uint256 blocksSinceCalc = block.number.sub(lastRewardBlock);
        uint256 rewardCalc = blocksSinceCalc.mul(rewardPerBlock).mul(1e12).div(totalShares);
        accRewardPerShare = accRewardPerShare.add( rewardCalc );
        lastRewardBlock = block.number;
    }


    /// Store `token per block`.
    /// @param _amount the new value to store
    /// @dev stores the provided amount in the state variable `tokenPerBlock` which is used to control token emission
    function setTokenPerBlock (uint256 _amount) public onlyOwner {
        require(_amount >= 0, "Token per Block can not be negative" );
        require(_amount <= MAX_TOKEN_PER_BLOCK, "Token Per Block can not be more than 10");
        tokenPerBlock = _amount;
        emit TokenPerBlockUpdated(_amount);
    }


    /// Stake the provided amount
    /// @param _amount the amount to stake
    /// @dev stakes the provided amount
    function enterStaking (uint256 _amount) public  {
        require(drug.balanceOf(msg.sender) >= _amount, "Insufficient tokens for transfer");
        require(_amount > 0,"Invalid staking amount");
        updateDistribution();
        drug.safeTransferFrom(msg.sender, address(this), _amount);
        
        UserStaking storage user = stakings[msg.sender];
        if(user.stakedAmount == 0) {
            user.lastBlockCompounded = block.number;
        }
        else {
            uint256 pending = user.shares.mul(accRewardPerShare).div(1e12).sub(user.apyBaseline);
            if( pending > totalPool)
                pending = totalPool;
            totalPool = totalPool.sub(pending);
            
            if( pending > 0) {
                drug.safeTransfer(msg.sender, pending);
                user.claimedAmount = user.claimedAmount.add(pending);
                totalClaimed = totalClaimed.add(pending);
            }
        }
        uint256 currentShares = 0;
        if (totalShares != 0)
            currentShares = _amount.mul(totalShares).div(totalStaked);
        else
            currentShares = _amount;

        totalStaked = totalStaked.add(_amount);
        totalShares = totalShares.add(currentShares);
        if( user.shares == 0){
            user.lastBlockCompounded = block.number;
        }
        user.shares = user.shares.add(currentShares);
        user.apyBaseline = accRewardPerShare.mul(user.shares).div(1e12);
        user.stakedAmount = user.stakedAmount.add(_amount);
        user.lastBlockStaked = block.number;
    }



    /// Leaves staking for a user by the specified amount and transfering staked amount and reward to users address
    /// @param _amount the amount to unstake
    /// @dev leaves staking and deducts total pool by the users reward. early withdrawal fee applied if withdraw is made before earlyWithdrawFeeTime
    function leaveStaking (uint256 _amount) external  {  
        updateDistribution();
        UserStaking storage user = stakings[msg.sender];
        uint256 reward = user.shares.mul(accRewardPerShare).div(1e12).sub(user.apyBaseline);
        
        if( reward > totalPool )
            reward = totalPool;
        totalPool = totalPool.sub(reward);
        user.lastBlockCompounded = block.number;
        uint256 availableStaked = user.stakedAmount;
        require(availableStaked >= _amount, "Withdraw amount can not be greater than available staked amount");
        totalStaked = totalStaked.sub(_amount);
        uint256 shareReduction = _amount.mul( user.shares ).div( user.stakedAmount );
        user.stakedAmount = user.stakedAmount.sub(_amount);
        user.shares = user.shares.sub( shareReduction );
        totalShares = totalShares.sub( shareReduction );
        user.apyBaseline = user.shares.mul(accRewardPerShare).div(1e12);
        _amount = _amount.add(reward);
        if(block.number < user.lastBlockStaked.add(earlyWithdrawFeeTime)){
            //apply fee
            uint256 withdrawalFee = _amount.mul(earlyWithdrawFee).div(divisor);
            _amount = _amount.sub(withdrawalFee);
            drug.safeTransfer(reserveAddress, withdrawalFee);
        }
        drug.safeTransfer(msg.sender, _amount);
        
        user.claimedAmount = user.claimedAmount.add(reward);
        totalClaimed = totalClaimed.add(reward);
        
    }


    /// Harvests a users reward and transfers them to their wallet
    /// @dev updates shares distribution and harvests users pending rewards to their wallet
    function harvest () external  {
        updateDistribution();
        UserStaking storage user = stakings[msg.sender];
        uint256 reward = user.shares.mul(accRewardPerShare).div(1e12).sub(user.apyBaseline);
        if( reward > totalPool )
            reward = totalPool;
        totalPool = totalPool.sub(reward);
        user.lastBlockCompounded = block.number;
        drug.safeTransfer(msg.sender, reward);

        user.claimedAmount = user.claimedAmount.add(reward);
        totalClaimed = totalClaimed.add(reward);

        //---
        
        user.apyBaseline = accRewardPerShare.mul(user.shares).div(1e12);
    }

    /// compounds a users reward and adds them to their staked amount
    /// @dev updates shares distribution and compounts users pending rewards to their staked amount
    function compound () external  {
        updateDistribution();
        UserStaking storage user = stakings[msg.sender];
        uint256 reward = user.shares.mul(accRewardPerShare).div(1e12).sub(user.apyBaseline);
        if( reward > totalPool )
            reward = totalPool;
        totalPool = totalPool.sub(reward);
        user.lastBlockCompounded = block.number;

        uint256 currentShares = 0;
        if (totalShares != 0)
            currentShares = reward.mul(totalShares).div(totalStaked);
        else
            currentShares = reward;

        totalStaked = totalStaked.add(reward);
        totalShares = totalShares.add(currentShares);
        user.shares = user.shares.add(currentShares);
        user.apyBaseline = accRewardPerShare.mul(user.shares).div(1e12);
        user.stakedAmount = user.stakedAmount.add(reward);
        user.lastBlockStaked = block.number;
    }



    /// Get pending rewards of a user for UI
    /// @param _address the address to calculate the reward for
    /// @dev calculates potential reward for the address provided based on drug per block
    function pendingReward (address _address) external view returns (uint256){
        UserStaking storage user = stakings[_address];
        uint256 rewardPerBlock = tokenPerBlock;
        if(totalPool == 0)
            rewardPerBlock = 0;
        uint256 localAccRewardPerShare = accRewardPerShare;
        if(block.number > lastRewardBlock && totalShares !=0){
            uint256 blocksSinceCalc = block.number.sub(lastRewardBlock);
            uint256 rewardCalc = blocksSinceCalc.mul(rewardPerBlock).mul(1e12).div(totalShares);
            localAccRewardPerShare = accRewardPerShare.add( rewardCalc );
        }
        return user.shares.mul(localAccRewardPerShare).div(1e12).sub(user.apyBaseline);
    }



    /// Store `_fee`.
    /// @param _fee the new value to store
    /// @dev stores the fee in the state variable `earlyWithdrawFee`
    function setEarlyWithdrawFee (uint256 _fee) public onlyOwner {
        require(_fee > 0, "Fee must be greater than 0");
        require(_fee < MAX_FEE, "Fee must be less than 10%");
        earlyWithdrawFee = _fee;
        emit EarlyWithdrawalFeeUpdated(_fee);
    }


    /// Store `_time`.
    /// @param _time the new value to store
    /// @dev stores the time in the state variable `earlyWithdrawFeeTime`
    function setEarlyWithdrawFeeTime (uint256 _time) public onlyOwner {
        require(_time > 0, "Time must be greater than 0");
        earlyWithdrawFeeTime = _time;
        emit EarlyWithdrawalTimeUpdated(_time);
    }
    


    /// emergency withdraw funds of users
    /// @dev transfer all available funds of users to users wallet
    function emergencyWithdraw () public {
        
        updateDistribution();
        UserStaking storage user = stakings[msg.sender];
        user.lastBlockCompounded = block.number;
        uint256 availableStaked = user.stakedAmount;  
        totalStaked = totalStaked.sub(availableStaked);
        uint256 shareReduction = availableStaked.mul( user.shares ).div( user.stakedAmount );
        user.stakedAmount = user.stakedAmount.sub(availableStaked);
        user.shares = user.shares.sub( shareReduction );
        totalShares = totalShares.sub( shareReduction );
        user.apyBaseline = user.shares.mul(accRewardPerShare).div(1e12);
        
        if(block.number < user.lastBlockStaked.add(earlyWithdrawFeeTime)){
            //apply fee
            uint256 withdrawalFee = availableStaked.mul(earlyWithdrawFee).div(divisor);
            availableStaked = availableStaked.sub(withdrawalFee);
            drug.safeTransfer(reserveAddress, withdrawalFee);
        }
        drug.safeTransfer(msg.sender, availableStaked);

    }
   

   
}
