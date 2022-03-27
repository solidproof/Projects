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
contract MasterChefAPE is Ownable {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many LP tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 rewardAPEDebt; // Reward debt in APE.
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
        uint256 accAPEPerShare; // Accumulated APEs per share, times 1e12. See below.
        uint256 lastTotalAPEReward; // last total rewards
        uint256 lastAPERewardBalance; // last APE rewards tokens
        uint256 totalAPEReward; // total APE rewards tokens
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
    // Total allocation poitns. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when VEMP mining starts.
    uint256 public startBlock;
    // total APE staked
    uint256 public totalAPEStaked;
    // total APE used for purchase land
    uint256 public totalAPEUsedForPurchase = 0;
    // withdraw status
    bool public withdrawStatus;
    // reward end status
    bool public rewardEndStatus;
    // rewad end block number
    uint256 public rewardEndBlock;

    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    constructor() public {}

    function initialize(
        IERC20 _VEMP,
        IERC20 _lpToken,
        address _adminaddr,
        uint256 _VEMPPerBlock,
        uint256 _startBlock
    ) public initializer {
        Ownable.init(_adminaddr);
        VEMP = _VEMP;
        adminaddr = _adminaddr;
        VEMPPerBlock = _VEMPPerBlock;
        startBlock = _startBlock;
        withdrawStatus = false;
        rewardEndStatus = false;
        rewardEndBlock = 0;

        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(100);
        poolInfo.lpToken = _lpToken;
        poolInfo.allocPoint = 100;
        poolInfo.lastRewardBlock = lastRewardBlock;
        poolInfo.accVEMPPerShare = 0;
        poolInfo.accAPEPerShare = 0;
        poolInfo.lastTotalAPEReward = 0;
        poolInfo.lastAPERewardBalance = 0;
        poolInfo.totalAPEReward = 0;
    }

    // Update the given pool's VEMP allocation point. Can only be called by the owner.
    function set( uint256 _allocPoint, bool _withUpdate) public onlyOwner {
        if (_withUpdate) {
            updatePool();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo.allocPoint).add(_allocPoint);
        poolInfo.allocPoint = _allocPoint;
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
        uint256 lpSupply = totalAPEStaked;
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, rewardBlockNumber);
            uint256 VEMPReward = multiplier.mul(VEMPPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accVEMPPerShare = accVEMPPerShare.add(VEMPReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accVEMPPerShare).div(1e12).sub(user.rewardDebt);
    }

    // View function to see pending APEs on frontend.
    function pendingAPE(address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[_user];
        uint256 accAPEPerShare = pool.accAPEPerShare;
        uint256 lpSupply = totalAPEStaked;
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 rewardBalance = pool.lpToken.balanceOf(address(this)).sub(totalAPEStaked.sub(totalAPEUsedForPurchase));
            uint256 _totalReward = rewardBalance.sub(pool.lastAPERewardBalance);
            accAPEPerShare = accAPEPerShare.add(_totalReward.mul(1e12).div(lpSupply));
        }
        return user.amount.mul(accAPEPerShare).div(1e12).sub(user.rewardAPEDebt);
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
        uint256 rewardBalance = pool.lpToken.balanceOf(address(this)).sub(totalAPEStaked.sub(totalAPEUsedForPurchase));
        uint256 _totalReward = pool.totalAPEReward.add(rewardBalance.sub(pool.lastAPERewardBalance));
        pool.lastAPERewardBalance = rewardBalance;
        pool.totalAPEReward = _totalReward;

        uint256 lpSupply = totalAPEStaked;
        if (lpSupply == 0) {
            pool.lastRewardBlock = rewardBlockNumber;
            pool.accAPEPerShare = 0;
            pool.lastTotalAPEReward = 0;
            user.rewardAPEDebt = 0;
            pool.lastAPERewardBalance = 0;
            pool.totalAPEReward = 0;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, rewardBlockNumber);
        uint256 VEMPReward = multiplier.mul(VEMPPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
        pool.accVEMPPerShare = pool.accVEMPPerShare.add(VEMPReward.mul(1e12).div(lpSupply));
        pool.lastRewardBlock = rewardBlockNumber;

        uint256 reward = _totalReward.sub(pool.lastTotalAPEReward);
        pool.accAPEPerShare = pool.accAPEPerShare.add(reward.mul(1e12).div(lpSupply));
        pool.lastTotalAPEReward = _totalReward;
    }

    // Deposit LP tokens to MasterChef for VEMP allocation.
    function deposit(uint256 _amount) public {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];
        updatePool();
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accVEMPPerShare).div(1e12).sub(user.rewardDebt);
            safeVEMPTransfer(msg.sender, pending);

            uint256 APEReward = user.amount.mul(pool.accAPEPerShare).div(1e12).sub(user.rewardAPEDebt);
            pool.lpToken.safeTransfer(msg.sender, APEReward);
            pool.lastAPERewardBalance = pool.lpToken.balanceOf(address(this)).sub(totalAPEStaked.sub(totalAPEUsedForPurchase));
        }
        pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
        totalAPEStaked = totalAPEStaked.add(_amount);
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(pool.accVEMPPerShare).div(1e12);
        user.rewardAPEDebt = user.amount.mul(pool.accAPEPerShare).div(1e12);
        emit Deposit(msg.sender, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _amount) public {
        require(withdrawStatus != true, "Withdraw not allowed");
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount >= _amount, "withdraw: not good");
        updatePool();
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accVEMPPerShare).div(1e12).sub(user.rewardDebt);
            safeVEMPTransfer(msg.sender, pending);

            uint256 APEReward = user.amount.mul(pool.accAPEPerShare).div(1e12).sub(user.rewardAPEDebt);
            pool.lpToken.safeTransfer(msg.sender, APEReward);
            pool.lastAPERewardBalance = pool.lpToken.balanceOf(address(this)).sub(totalAPEStaked.sub(totalAPEUsedForPurchase));
        }
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(pool.accVEMPPerShare).div(1e12);
        user.rewardAPEDebt = user.amount.mul(pool.accAPEPerShare).div(1e12);
        totalAPEStaked = totalAPEStaked.sub(_amount);
        pool.lpToken.safeTransfer(msg.sender, _amount);
        emit Withdraw(msg.sender, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw() public {
        require(withdrawStatus != true, "Withdraw not allowed");
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];
        pool.lpToken.safeTransfer(msg.sender, user.amount);
        totalAPEStaked = totalAPEStaked.sub(user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
        user.rewardAPEDebt = 0;
        emit EmergencyWithdraw(msg.sender, user.amount);
    }

    // Safe VEMP transfer function, just in case if rounding error causes pool to not have enough VEMPs.
    function safeVEMPTransfer(address _to, uint256 _amount) internal {
        uint256 VEMPBal = VEMP.balanceOf(address(this));
        if (_amount > VEMPBal) {
            VEMP.transfer(_to, VEMPBal);
        } else {
            VEMP.transfer(_to, _amount);
        }
    }

    // Earn APE tokens to MasterChef.
    function claimAPE() public {
        PoolInfo storage pool = poolInfo;
        UserInfo storage user = userInfo[msg.sender];
        updatePool();

        uint256 APEReward = user.amount.mul(pool.accAPEPerShare).div(1e12).sub(user.rewardAPEDebt);
        pool.lpToken.safeTransfer(msg.sender, APEReward);
        pool.lastAPERewardBalance = pool.lpToken.balanceOf(address(this)).sub(totalAPEStaked.sub(totalAPEUsedForPurchase));

        user.rewardAPEDebt = user.amount.mul(pool.accAPEPerShare).div(1e12);
    }

    // Safe APE transfer function to admin.
    function accessAPETokens(address _to, uint256 _amount) public {
        require(msg.sender == adminaddr, "sender must be admin address");
        require(totalAPEStaked.sub(totalAPEUsedForPurchase) >= _amount, "Amount must be less than staked APE amount");
        PoolInfo storage pool = poolInfo;
        uint256 APEBal = pool.lpToken.balanceOf(address(this));
        if (_amount > APEBal) {
            pool.lpToken.safeTransfer(_to, APEBal);
            totalAPEUsedForPurchase = totalAPEUsedForPurchase.add(APEBal);
        } else {
            pool.lpToken.safeTransfer(_to, _amount);
            totalAPEUsedForPurchase = totalAPEUsedForPurchase.add(_amount);
        }
    }

    // Safe add APE in pool
     function addAPETokensInPool(uint256 _amount) public {
        require(_amount > 0, "APE amount must be greater than 0");
        require(msg.sender == adminaddr, "sender must be admin address");
        require(_amount.add(totalAPEStaked.sub(totalAPEUsedForPurchase)) <= totalAPEStaked, "Amount must be less than staked APE amount");
        PoolInfo storage pool = poolInfo;
        totalAPEUsedForPurchase = totalAPEUsedForPurchase.sub(_amount);
        pool.lpToken.safeTransferFrom(address(msg.sender), address(this), _amount);
    }

    // Update Reward per block
    function updateRewardPerBlock(uint256 _newRewardPerBlock) public onlyOwner {
        updatePool();
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
    }

    // Update admin address by the previous admin.
    function admin(address _adminaddr) public {
        require(msg.sender == adminaddr, "admin: wut?");
        adminaddr = _adminaddr;
    }

    // Safe VEMP transfer function to admin.
    function emergencyWithdrawRewardTokens(address _to, uint256 _amount) public {
        require(msg.sender == adminaddr, "sender must be admin address");
        safeVEMPTransfer(_to, _amount);
    }
}