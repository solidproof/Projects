// SPDX-License-Identifier: MIT

pragma solidity =0.6.12;

import "@openzeppelin/contracts/GSN/Context.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "../common/Ownable.sol";

// MasterChef is the master of VEMP. He can make VEMP and he is a fair guy.
//
// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once VEMP is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract MasterChefLP is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 rewardLPDebt; // Reward debt in LP.
        //
        // We do some fancy math here. Basically, any point in time, the amount of VEMPs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accVEMPPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws LP tokens to a pool. Here's what happens:
        //   1. The pool's `accVEMPPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 lpToken;           // Address of LP token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. VEMPs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that VEMPs distribution occurs.
        uint256 accVEMPPerShare; // Accumulated VEMPs per share, times 1e12. See below.
        uint256 accLPPerShare; // Accumulated LPs per share, times 1e12. See below.
        uint256 lastTotalLPReward; // last total rewards
        uint256 lastLPRewardBalance; // last LP rewards tokens
        uint256 totalLPReward; // total LP rewards tokens
    }

    // Info of each user.
    struct UserLockInfo {
        uint256 amount;     // How many LP tokens the user has withdraw.
        uint256 lockTime; // lockTime of VEMP
    }

    // The VEMP TOKEN!
    IERC20 public VEMP;
    // admin address.
    address public adminaddr;
    // VEMP tokens created per block.
    uint256 public VEMPPerBlock;
    // Bonus muliplier for early VEMP makers.
    uint256 public constant BONUS_MULTIPLIER = 1;

    // Info of each pool.
    PoolInfo public poolInfo;
    // Info of each user that stakes LP tokens.
    mapping (address => UserInfo) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when VEMP mining starts.
    uint256 public startBlock;
    // total LP staked
    uint256 public totalLPStaked;
    // total LP used for purchase land
    uint256 public totalLPUsedForPurchase = 0;
    // withdraw status
    bool public withdrawStatus;
    // reward end status
    bool public rewardEndStatus;
    // reward end block number
    uint256 public rewardEndBlock;

    uint256 public vempLockAmount;
    uint256 public lockPeriod;
    uint256 public totalVempLock;
    mapping (address => UserLockInfo) public userLockInfo;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event Set(uint256 allocPoint, bool overwrite);
    event RewardEndStatus(bool rewardStatus, uint256 rewardEndBlock);
    event RewardPerBlock(uint256 oldRewardPerBlock, uint256 newRewardPerBlock);
    event AccessLPToken(address indexed user, uint256 amount, uint256 totalLPUsedForPurchase);
    event AddLPTokensInPool(uint256 amount, uint256 totalLPUsedForPurchase);
    event UpdateVempLockAmount(uint256 _oldLockAmount, uint256 _newLockAmount);
    event UpdateLockPeriod(uint256 _oldLockPeriod, uint256 _newLockPeriod);

    constructor() public {}

    function initialize(
        IERC20 _VEMP,
        IERC20 _lpToken,
        address _adminaddr,
        uint256 _VEMPPerBlock,
        uint256 _startBlock,
        uint256 _vempLockAmount,
        uint256 _lockPeriod
    ) public initializer {
        require(address(_VEMP) != address(0), "Invalid VEMP address");
        require(address(_lpToken) != address(0), "Invalid lpToken address");
        require(address(_adminaddr) != address(0), "Invalid admin address");

        Ownable.init(_adminaddr);
        VEMP = _VEMP;
        adminaddr = _adminaddr;
        VEMPPerBlock = _VEMPPerBlock;
        startBlock = _startBlock;
        withdrawStatus = false;
        rewardEndStatus = false;
        rewardEndBlock = 0;

        vempLockAmount = _vempLockAmount;
        lockPeriod = _lockPeriod;

        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(100);
        poolInfo.lpToken = _lpToken;
        poolInfo.allocPoint = 100;
        poolInfo.lastRewardBlock = lastRewardBlock;
        poolInfo.accVEMPPerShare = 0;
        poolInfo.accLPPerShare = 0;
        poolInfo.lastTotalLPReward = 0;
        poolInfo.lastLPRewardBalance = 0;
        poolInfo.totalLPReward = 0;
    }

    function updateVempLockAmount(uint256 _vempLockAmount) public onlyOwner {
        emit UpdateVempLockAmount(vempLockAmount, _vempLockAmount);
        vempLockAmount = _vempLockAmount;
    }

    function updateLockPeriod(uint256 _lockPeriod) public onlyOwner {
        emit UpdateLockPeriod(lockPeriod, _lockPeriod);
        lockPeriod = _lockPeriod;
    }

    function lock() public {
        UserLockInfo storage userLock = userLockInfo[msg.sender];

        UserInfo storage user = userInfo[msg.sender];
        require(user.amount > 0, "Not Staked");
        VEMP.transferFrom(msg.sender, address(this), vempLockAmount);
        userLock.amount = userLock.amount.add(vempLockAmount);
        totalVempLock = totalVempLock.add(vempLockAmount);
        if(userLock.lockTime <= 0)
        userLock.lockTime = block.timestamp;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public pure returns (uint256) {
        if (_to >= _from) {
            return _to.sub(_from).mul(BONUS_MULTIPLIER);
        } else {
            return _from.sub(_to);
        }
    }

    // View function to see pending VEMPs on frontend.
    function pendingVEMP(address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[_user];
        uint256 accVEMPPerShare = pool.accVEMPPerShare;
        uint256 rewardBlockNumber = block.number;
        if(rewardEndStatus != false) {
           rewardBlockNumber = rewardEndBlock;
        }
        uint256 lpSupply = totalLPStaked;
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, rewardBlockNumber);
            uint256 VEMPReward = multiplier.mul(VEMPPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accVEMPPerShare = accVEMPPerShare.add(VEMPReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accVEMPPerShare).div(1e12).sub(user.rewardDebt);
    }

    // View function to see pending LPs on frontend.
    function pendingLP(address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[_user];
        uint256 accLPPerShare = pool.accLPPerShare;
        uint256 lpSupply = totalLPStaked;
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 rewardBalance = pool.lpToken.balanceOf(address(this)).sub(totalLPStaked.sub(totalLPUsedForPurchase));
            uint256 _totalReward = rewardBalance.sub(pool.lastLPRewardBalance);
            accLPPerShare = accLPPerShare.add(_totalReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accLPPerShare).div(1e12).sub(user.rewardLPDebt);
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool() internal {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];

        if (block.number <= pool.lastRewardBlock) {
            return;
        }
        uint256 rewardBlockNumber = block.number;
        if(rewardEndStatus != false) {
           rewardBlockNumber = rewardEndBlock;
        }
        uint256 rewardBalance = pool.lpToken.balanceOf(address(this)).sub(totalLPStaked.sub(totalLPUsedForPurchase));
        uint256 _totalReward = pool.totalLPReward.add(rewardBalance.sub(pool.lastLPRewardBalance));
        pool.lastLPRewardBalance = rewardBalance;
        pool.totalLPReward = _totalReward;

        uint256 lpSupply = totalLPStaked;
        if (lpSupply == 0) {
            pool.lastRewardBlock = rewardBlockNumber;
            pool.accLPPerShare = 0;
            pool.lastTotalLPReward = 0;
            user.rewardLPDebt = 0;
            pool.lastLPRewardBalance = 0;
            pool.totalLPReward = 0;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, rewardBlockNumber);
        uint256 VEMPReward = multiplier.mul(VEMPPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        pool.accVEMPPerShare = pool.accVEMPPerShare.add(VEMPReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = rewardBlockNumber;

        uint256 reward = _totalReward.sub(pool.lastTotalLPReward);
        pool.accLPPerShare = pool.accLPPerShare.add(reward.mul(1e12).div(lpSupply));
        pool.lastTotalLPReward = _totalReward;
    }

    // Deposit LP tokens to MasterChef for VEMP allocation.
    function deposit(address _user, uint256 _amount) public {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[_user];
        updatePool();
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accVEMPPerShare).div(1e12).sub(user.rewardDebt);
            safeVEMPTransfer(_user, pending);

            uint256 LPReward = user.amount.mul(pool.accLPPerShare).div(1e12).sub(user.rewardLPDebt);
            pool.lpToken.safeTransfer(_user, LPReward);
            pool.lastLPRewardBalance = pool.lpToken.balanceOf(address(this)).sub(totalLPStaked.sub(totalLPUsedForPurchase));
        }
        pool.lpToken.safeTransferFrom(msg.sender, address(this), _amount);
        totalLPStaked = totalLPStaked.add(_amount);
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accVEMPPerShare).div(1e12);
        user.rewardLPDebt = user.amount.mul(pool.accLPPerShare).div(1e12);

        emit Deposit(_user, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _amount, bool _directStatus) public {
        require(withdrawStatus != true, "Withdraw not allowed");
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool();
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accVEMPPerShare).div(1e12).sub(user.rewardDebt);
            safeVEMPTransfer(msg.sender, pending);

            uint256 LPReward = user.amount.mul(pool.accLPPerShare).div(1e12).sub(user.rewardLPDebt);
            pool.lpToken.safeTransfer(msg.sender, LPReward);
            pool.lastLPRewardBalance = pool.lpToken.balanceOf(address(this)).sub(totalLPStaked.sub(totalLPUsedForPurchase));
        }
        UserLockInfo storage userLock = userLockInfo[msg.sender];

        if(_directStatus) {
            uint256 vempAmount = VEMP.balanceOf(msg.sender);
            uint256 burnAmount = vempLockAmount;
            if((userLock.amount >= vempLockAmount && userLock.lockTime.add(lockPeriod) <= block.timestamp)) {
                burnAmount = 0;
                VEMP.transfer(msg.sender, userLock.amount.sub(burnAmount));
            } else if(userLock.amount >= vempLockAmount && userLock.lockTime.add(lockPeriod.div(2)) <= block.timestamp) {
                burnAmount = vempLockAmount.div(2);
                require(burnAmount <= userLock.amount, "Insufficient VEMP Burn Amount");
                VEMP.transfer(address(0x000000000000000000000000000000000000dEaD), burnAmount);
                VEMP.transfer(msg.sender, userLock.amount.sub(burnAmount));
            } else if(userLock.amount >= vempLockAmount && userLock.lockTime.add(lockPeriod.div(2)) >= block.timestamp) {
                burnAmount = vempLockAmount;
                require(burnAmount <= userLock.amount, "Insufficient VEMP Burn Amount");
                VEMP.transfer(address(0x000000000000000000000000000000000000dEaD), burnAmount);
                VEMP.transfer(msg.sender, userLock.amount.sub(burnAmount));
            } else if(userLock.amount == 0) {
                require(vempLockAmount <= vempAmount, "Insufficient VEMP Burn Amount");
                VEMP.transferFrom(msg.sender, address(0x000000000000000000000000000000000000dEaD), vempLockAmount);
            }
        } else {
            require(vempLockAmount <= userLock.amount, "Insufficient VEMP Locked");
            require(userLock.lockTime.add(lockPeriod) <= block.timestamp, "Lock period not complete.");
            VEMP.transfer(msg.sender, userLock.amount);
        }
        totalVempLock = totalVempLock.sub(userLock.amount);
        userLock.amount = 0;
        userLock.lockTime = 0;

        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accVEMPPerShare).div(1e12);
        user.rewardLPDebt = user.amount.mul(pool.accLPPerShare).div(1e12);
        totalLPStaked = totalLPStaked.sub(_amount);
        pool.lpToken.safeTransfer(msg.sender, _amount);

        emit Withdraw(msg.sender, _amount);
    }

    // Safe VEMP transfer function, just in case if rounding error causes pool to not have enough VEMPs.
    function safeVEMPTransfer(address _to, uint256 _amount) internal {
        uint256 VEMPBal = VEMP.balanceOf(address(this)).sub(totalVempLock);
        if (_amount > VEMPBal) {
            VEMP.transfer(_to, VEMPBal);
        } else {
            VEMP.transfer(_to, _amount);
        }
    }

    // Earn LP tokens to MasterChef.
    function claimLP() public {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];
        updatePool();

        uint256 LPReward = user.amount.mul(pool.accLPPerShare).div(1e12).sub(user.rewardLPDebt);
        pool.lpToken.safeTransfer(msg.sender, LPReward);
        pool.lastLPRewardBalance = pool.lpToken.balanceOf(address(this)).sub(totalLPStaked.sub(totalLPUsedForPurchase));

        user.rewardLPDebt = user.amount.mul(pool.accLPPerShare).div(1e12);
    }

    // Safe LP transfer function to admin.
    function accessLPTokens(address _to, uint256 _amount) public {
        require(_to != address(0), "Invalid to address");
        require(msg.sender == adminaddr, "sender must be admin address");
        require(totalLPStaked.sub(totalLPUsedForPurchase) >= _amount, "Amount must be less than staked LP amount");
        PoolInfo storage pool = poolInfo;
        uint256 LPBal = pool.lpToken.balanceOf(address(this));
        if (_amount > LPBal) {
            pool.lpToken.safeTransfer(_to, LPBal);
            totalLPUsedForPurchase = totalLPUsedForPurchase.add(LPBal);
        } else {
            pool.lpToken.safeTransfer(_to, _amount);
            totalLPUsedForPurchase = totalLPUsedForPurchase.add(_amount);
        }
        emit AccessLPToken(_to, _amount, totalLPUsedForPurchase);
    }

    // Safe add LP in pool
     function addLPTokensInPool(uint256 _amount) public {
        require(_amount > 0, "LP amount must be greater than 0");
        require(msg.sender == adminaddr, "sender must be admin address");
        require(_amount.add(totalLPStaked.sub(totalLPUsedForPurchase)) <= totalLPStaked, "Amount must be less than staked LP amount");
        PoolInfo storage pool = poolInfo;
        totalLPUsedForPurchase = totalLPUsedForPurchase.sub(_amount);
        pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        emit AddLPTokensInPool(_amount, totalLPUsedForPurchase);
    }

    // Update Reward per block
    function updateRewardPerBlock(uint256 _newRewardPerBlock) public onlyOwner {
        updatePool();
        emit RewardPerBlock(VEMPPerBlock, _newRewardPerBlock);
        VEMPPerBlock = _newRewardPerBlock;
    }

    // Update withdraw status
    function updateWithdrawStatus(bool _status) public onlyOwner {
        require(withdrawStatus != _status, "Already same status");
        withdrawStatus = _status;
    }

    // Update reward end status
    function updateRewardEndStatus(bool _status, uint256 _rewardEndBlock) public onlyOwner {
        require(rewardEndStatus != _status, "Already same status");
        rewardEndBlock = _rewardEndBlock;
        rewardEndStatus = _status;
        emit RewardEndStatus(_status, _rewardEndBlock);
    }

    // Update admin address by the previous admin.
    function admin(address _adminaddr) public {
        require(_adminaddr != address(0), "Invalid admin address");
        require(msg.sender == adminaddr, "admin: wut?");
        adminaddr = _adminaddr;
    }

    // Safe VEMP transfer function to admin.
    function emergencyWithdrawRewardTokens(address _to, uint256 _amount) public {
        require(_to != address(0), "Invalid to address");
        require(msg.sender == adminaddr, "sender must be admin address");
        safeVEMPTransfer(_to, _amount);
    }
}