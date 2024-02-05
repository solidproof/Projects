pragma solidity ^0.8.18;

import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import "./MerkleTree.sol";

interface Token {
    function transfer(address recipient, uint256 amount) external returns (bool);
    function balanceOf(address account) external view returns (uint256);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    function approve(address spender, uint256 amount) external returns (bool);
}

contract StakeDTL is Pausable, Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using MerkleTree for MerkleTree.Tree;
    
    MerkleTree.Tree private stakerTree;

    Token dtlToken;
    Token rewardToken;

    uint256[3] public lockPeriods = [3 * 60, 6 * 60, 8 * 60];
    uint256[3] public sharesPerToken = [20, 15, 10];

    uint256 public totalShares;
    uint256 public totalRewards;
    uint256 public totalStakers;
    uint256 public lastRewardDistribution;
    uint256 public rewardPercentage = 5;
    uint256 private constant PRECISION = 10**18;


    struct StakeInfo {
        uint256 startTS;
        uint256 endTS;
        uint256 amount;
        uint256 shares;
        uint8 lockPeriodIndex;
        bool expired;
    }


   
    event Staked(address indexed from, uint256 amount, uint8 lockPeriodIndex);
    event Claimed(address indexed from, uint256 amount);

    mapping(address => StakeInfo[]) public stakeInfos;
    mapping(address => uint256) public userTotalShares;
    mapping(address => uint256) public unclaimedRewards;   
    mapping(address => uint256) public claimedRewards;
  



    constructor(Token _dtlTokenAddress, Token _rewardTokenAddress) {
        require(address(_dtlTokenAddress) != address(0), "DTL Token Address cannot be address 0");
        require(address(_rewardTokenAddress) != address(0), "Reward Token Address cannot be address 0");

        dtlToken = _dtlTokenAddress;
        rewardToken = _rewardTokenAddress;

        totalShares = 0;
        totalRewards = 0;
        lastRewardDistribution = block.timestamp;
    
    }


    function addReward(uint256 amount) external onlyOwner {
        require(rewardToken.transferFrom(_msgSender(), address(this), amount), "Token transfer failed!");
        totalRewards += amount;
    }
    


    function divCeil(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "division by zero");
        return a.mul(PRECISION).add(b.sub(1)).div(b); // Support precision
    }



  
  function distributeRewards() internal {
    uint256 activeShares = 0;
    for (uint256 i = 0; i < stakerTree.length(); i++) {
        address staker = stakerTree.addressAt(i);
        for (uint256 j = 0; j < stakeInfos[staker].length; j++) {
            if (stakeInfos[staker][j].endTS < lastRewardDistribution) {
                stakeInfos[staker][j].expired = true;
            }
            if (!stakeInfos[staker][j].expired) {
                activeShares = activeShares.add(stakeInfos[staker][j].shares);
            }
        }
    }

    if(activeShares <= 0 ) {
        return;
    }

    uint256 elapsedTime = block.timestamp.sub(lastRewardDistribution);

    if (elapsedTime > 0) {
        uint256 rewardsForTwentyFourHours = totalRewards.mul(rewardPercentage).div(100);
        uint256 rewardsToDistribute = divCeil(rewardsForTwentyFourHours.mul(elapsedTime), 86400).div(PRECISION);

        require(rewardToken.balanceOf(address(this)) >= rewardsToDistribute, "Insufficient reward token balance");

        uint256 rewardsPerShare = divCeil(rewardsToDistribute, activeShares);

        totalRewards = totalRewards.sub(rewardsToDistribute);
        lastRewardDistribution = block.timestamp;

        for (uint256 i = 0; i < stakerTree.length(); i++) {
            address staker = stakerTree.addressAt(i);
            uint256 stakerShares = 0;
            for (uint256 j = 0; j < stakeInfos[staker].length; j++) {
                if (!stakeInfos[staker][j].expired) {
                    stakerShares = stakerShares.add(stakeInfos[staker][j].shares);
                }
            }

            if (stakerShares > 0) {
                uint256 stakerReward = stakerShares.mul(rewardsPerShare).div(PRECISION);
                unclaimedRewards[staker] = unclaimedRewards[staker].add(stakerReward);
            }
        }
    }
}

        
    function claimAllRewards() external nonReentrant {
                distributeRewards();
              

        uint256 stakerUnclaimedRewards = unclaimedRewards[_msgSender()];
        require(stakerUnclaimedRewards > 0, "No unclaimed rewards");
        require(rewardToken.transfer(_msgSender(), stakerUnclaimedRewards), "Token transfer failed!");
        claimedRewards[_msgSender()] += stakerUnclaimedRewards;

        unclaimedRewards[_msgSender()] = 0;
        emit Claimed(_msgSender(), stakerUnclaimedRewards);
    }

 


    function stakeToken(uint256 stakeAmount, uint8 lockPeriodIndex) external whenNotPaused nonReentrant {
         distributeRewards();
        require(stakeAmount > 0, "Stake amount should be correct");
        require(lockPeriodIndex < lockPeriods.length, "Invalid lock period");
        require(dtlToken.balanceOf(_msgSender()) >= stakeAmount, "Insufficient Balance");
        require(dtlToken.transferFrom(_msgSender(), address(this), stakeAmount), "Token transfer failed!");

        uint256 shares = stakeAmount / sharesPerToken[lockPeriodIndex];
        totalShares += shares;
        userTotalShares[_msgSender()] += shares;

        stakeInfos[_msgSender()].push(StakeInfo({
            startTS: block.timestamp,
            endTS: block.timestamp + lockPeriods[lockPeriodIndex],
            amount: stakeAmount,
            shares: shares,
            lockPeriodIndex: lockPeriodIndex,
            expired: false
        }));

        stakerTree.insertData(_msgSender(), stakeAmount, shares);  // Update totalStakers if necessary
        if (userTotalShares[_msgSender()] == shares) {
            totalStakers += 1;
        }



        emit Staked(_msgSender(), stakeAmount, lockPeriodIndex);
    }

    function unstake(uint256 stakeIndex) external nonReentrant {
        distributeRewards();

        require(stakeInfos[_msgSender()].length > stakeIndex, "Invalid stake index");
        require(stakeInfos[_msgSender()][stakeIndex].endTS < block.timestamp, "Stake Time is not over yet");

        uint256 stakeAmount = stakeInfos[_msgSender()][stakeIndex].amount;
        uint256 stakeShares = stakeInfos[_msgSender()][stakeIndex].shares;

        require(dtlToken.transfer(_msgSender(), stakeAmount), "Token transfer failed!");

        totalShares -= stakeShares;
        userTotalShares[_msgSender()] -= stakeShares;

        // Remove the stake instance from the stakeInfos mapping
        delete stakeInfos[_msgSender()][stakeIndex];

        // If no stake instances left for the user, remove the user's data from the MerkleTree
        if (stakeInfos[_msgSender()].length == 0) {
            stakerTree.removeData(_msgSender(), stakeAmount, stakeShares);
            // Update totalStakers if necessary
            if (userTotalShares[_msgSender()] == 0) {
                totalStakers -= 1;
            }
        }

         // Automatically claim all unclaimed rewards after unstaking
        uint256 stakerUnclaimedRewards = unclaimedRewards[_msgSender()];
        if (stakerUnclaimedRewards > 0) {
            require(rewardToken.transfer(_msgSender(), stakerUnclaimedRewards), "Token transfer failed!");
            claimedRewards[_msgSender()] += stakerUnclaimedRewards;

            unclaimedRewards[_msgSender()] = 0;
            emit Claimed(_msgSender(), stakerUnclaimedRewards);
        }

    
    }

    function getStakeInstances(address user) external view returns (StakeInfo[] memory) {
        return stakeInfos[user];
    }

    function getTokenExpiry(uint256 stakeIndex) external view returns (uint256) {
        require(stakeInfos[_msgSender()].length > stakeIndex, "Invalid stake index");
        return stakeInfos[_msgSender()][stakeIndex].endTS;
    }

    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }

    function getClaimedRewards(address user) external view returns (uint256) {
        return claimedRewards[user];
    }

    function distributeRewardsPublic() external onlyOwner {
    distributeRewards();
    }
 
    function setRewardPercentage(uint256 newRewardPercentage) external onlyOwner {
        require(newRewardPercentage > 0 && newRewardPercentage <= 100, "Reward percentage must be between 1 and 100");
        rewardPercentage = newRewardPercentage;
    }


    function emergencyWithdraw(uint256 amount) external onlyOwner {
        require(amount > 0, "Withdrawal amount must be greater than zero");
        require(rewardToken.balanceOf(address(this)) >= amount, "Insufficient reward token balance");

        require(rewardToken.transfer(owner(), amount), "Token transfer failed!");
        emit EmergencyWithdraw(owner(), amount);
    }

    event EmergencyWithdraw(address indexed to, uint256 amount);
}
