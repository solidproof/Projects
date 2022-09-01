// SPDX-License-Identifier: MIT
pragma solidity >= 0.4.22 < 0.9.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract JYDFarm is ReentrancyGuard {
    using SafeERC20 for IERC20;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Caller is not the owner!");
        _;
    }

    // Info of each user.
    struct UserInfo {
        uint256 amount; // How many staked tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint256 unlocksAt; // The time the user's stake unlocks at
    }

    // Info of each pool.
    struct PoolInfo {
        IERC20 stakedToken; // Address of staked token contract.
        uint256 allocPoint; // How many allocation points assigned to this pool.
        uint256 lastRewardBlock; // Last block number that reward distribution occurs.
        uint256 accRewardPerShare; // Accumulated rewards per share, times 1e12. See below.
        uint256 lockDuration; // How long the lock of the stake is
        uint256 amountStaked; // The total amount of tokens staked
    }

    IERC20 public jydToken; // The main rewards token
    uint256 public rewardsPerBlock; // How many rewards from the contract balance to pay each block in total
    PoolInfo[] public poolInfo; // Info of each pool.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo; // Info of each user that stakes LP tokens.
    uint256 public totalAllocPoint = 0; // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public startBlock; // The block number where mining starts.
    uint256 public minHold;

    address private owner;
    address private feeReceiver;
    mapping (address => uint256) jydStaked;

    constructor(
        IERC20 _jydToken,
        uint256 _rewardsPerBlock,
        uint256 _startBlock,
        address _feeReceiver
    ) {
        jydToken = _jydToken;
        rewardsPerBlock = _rewardsPerBlock;
        startBlock = _startBlock;
        owner = msg.sender;
        feeReceiver = _feeReceiver;

        // 1 week staking
        poolInfo.push(PoolInfo({
            stakedToken: _jydToken,
            allocPoint: 100,
            lastRewardBlock: _startBlock,
            accRewardPerShare: 0,
            lockDuration: 1 weeks,
            amountStaked: 0
        }));

        // 1 month staking
        poolInfo.push(PoolInfo({
            stakedToken: _jydToken,
            allocPoint: 500,
            lastRewardBlock: _startBlock,
            accRewardPerShare: 0,
            lockDuration: 4 weeks,
            amountStaked: 0
        }));

        // 3 month staking
        poolInfo.push(PoolInfo({
            stakedToken: _jydToken,
            allocPoint: 2000,
            lastRewardBlock: _startBlock,
            accRewardPerShare: 0,
            lockDuration: 12 weeks,
            amountStaked: 0
        }));

        totalAllocPoint = 2600;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    function jydOwned(address user) public view returns (uint256) {
        return jydToken.balanceOf(user) + jydStaked[user];
    }

    function setOwner(address _owner) external onlyOwner {
        owner = _owner;
    }

    function setFeeReceiver(address _feeReceiver) external onlyOwner {
        feeReceiver = _feeReceiver;
    }

    function setRewardsPerBlock(uint256 _rewardsPerBlock) external onlyOwner {
        rewardsPerBlock = _rewardsPerBlock;
    }

    function setMinHold(uint256 _minHold) external onlyOwner {
        minHold = _minHold;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same LP token more than once. Rewards will be messed up if you do.
    function add(
        uint256 _allocPoint,
        IERC20 _stakedToken,
        bool _withUpdate,
        uint256 _lockDuration
    ) external onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint + _allocPoint;
        poolInfo.push(PoolInfo({
            stakedToken: _stakedToken,
            allocPoint: _allocPoint,
            lastRewardBlock: lastRewardBlock,
            accRewardPerShare: 0,
            lockDuration: _lockDuration,
            amountStaked: 0
        }));
    }

    // Update the given pool's reward allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate) external onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 prevAllocPoint = poolInfo[_pid].allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        if (prevAllocPoint != _allocPoint) {
            totalAllocPoint = (totalAllocPoint - prevAllocPoint) + _allocPoint;
        }
    }

    // View function to see pending rewards on frontend.
    function pendingRewards(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accRewardPerShare = pool.accRewardPerShare;
        if (block.number > pool.lastRewardBlock && pool.amountStaked != 0) {
            uint256 rewards = ((block.number - pool.lastRewardBlock) * rewardsPerBlock * pool.allocPoint) / totalAllocPoint;
            accRewardPerShare = accRewardPerShare + (rewards * 1e12) / pool.amountStaked;
        }
        return (user.amount * accRewardPerShare) / 1e12 - user.rewardDebt;
    }

    // Update reward variables for all pools. Be careful of gas spending!
    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    // Update reward variables of the given pool to be up-to-date.
    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.number <= pool.lastRewardBlock) {
            return;
        }

        if (pool.amountStaked == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 rewards = ((block.number - pool.lastRewardBlock) * rewardsPerBlock * pool.allocPoint) / totalAllocPoint;
        pool.accRewardPerShare = pool.accRewardPerShare + ((rewards * 1e12) / pool.amountStaked);
        pool.lastRewardBlock = block.number;
    }

    // Deposit LP tokens to MasterChef for reward allocation.
    function deposit(uint256 _pid, uint256 _amount) external {
        require(jydOwned(msg.sender) >= minHold, "deposit(): user doesn't meet the minimum hold requirements!");

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        if (user.unlocksAt == 0) {
            user.unlocksAt = block.timestamp + pool.lockDuration;
        }

        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = (user.amount * pool.accRewardPerShare) / 1e12 - user.rewardDebt;
            if(pending > 0) {
                jydToken.safeTransfer(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            uint256 balanceBefore = pool.stakedToken.balanceOf(address(this));
            pool.stakedToken.safeTransferFrom(address(msg.sender), address(this), _amount);

            // Taxes
            uint256 tax = (_amount * 25) / 1000; // 2.5%
            pool.stakedToken.transfer(0x000000000000000000000000000000000000dEaD, tax); // 2.5% burn
            pool.stakedToken.transfer(feeReceiver, tax); // 2.5% to fee receiver

            uint256 balanceAfter = pool.stakedToken.balanceOf(address(this));
            uint256 amountTransfered = balanceAfter - balanceBefore;

            // Keep track of staked jyd for fair min hold requirements
            if (pool.stakedToken == jydToken) {
                jydStaked[msg.sender] += amountTransfered;
            }

            pool.amountStaked += amountTransfered;
            user.amount = user.amount + amountTransfered;
        }
        user.rewardDebt = (user.amount * pool.accRewardPerShare) / 1e12;
        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _amount) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(user.amount >= _amount, "withdraw(): user does not have enough stake in the pool!");
        require(block.timestamp >= user.unlocksAt, "withdraw(): user stake is not unlocked yet!");

        updatePool(_pid);
        uint256 pending = (user.amount * pool.accRewardPerShare) / 1e12 - user.rewardDebt;
        if(pending > 0) {
            jydToken.safeTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount - _amount;
            pool.stakedToken.safeTransfer(address(msg.sender), _amount);
            // Keep track of staked jyd for fair min hold requirements
            if (pool.stakedToken == jydToken) {
                jydStaked[msg.sender] -= _amount;
            }
            pool.amountStaked -= _amount;
        }
        user.rewardDebt = (user.amount * pool.accRewardPerShare) / 1e12;
        emit Withdraw(msg.sender, _pid, _amount);
    }

    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) external {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.stakedToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

}
