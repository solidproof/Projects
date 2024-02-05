//SPDX-License-Identifier: LicenseRef-LICENSE

pragma solidity 0.6.12;
import './math/SafeMath.sol';
import './token/BEP20/IBEP20.sol';
import './token/BEP20/SafeBEP20.sol';
import './access/Ownable.sol';

//import "./../Token/DPAD.sol";

// import "@nomiclabs/buidler/console.sol";

// Note that it's ownable and the owner wields tremendous power. The ownership
// will be transferred to a governance smart contract once DPAD is sufficiently
// distributed and the community can show to govern itself.
//
// Have fun reading it. Hopefully it's bug-free. God bless.
contract Staking is Ownable {
    using SafeMath for uint256;
    using SafeBEP20 for IBEP20;

    // Info of each user.
    struct UserInfo {
        uint256 amount;     // How many Staking tokens the user has provided.
        uint256 rewardDebt; // Reward debt. See explanation below.
        uint32 lockedTill;
        //
        // We do some fancy math here. Basically, any point in time, the amount of DPADs
        // entitled to a user but is pending to be distributed is:
        //
        //   pending reward = (user.amount * pool.accDpadPerShare) - user.rewardDebt
        //
        // Whenever a user deposits or withdraws Staking tokens to a pool. Here's what happens:
        //   1. The pool's `accDpadPerShare` (and `lastRewardBlock`) gets updated.
        //   2. User receives the pending reward sent to his/her address.
        //   3. User's `amount` gets updated.
        //   4. User's `rewardDebt` gets updated.
    }

    // Info of each pool.
    struct PoolInfo {
        IBEP20 stakingToken;           // Address of Staking token contract.
        uint256 allocPoint;       // How many allocation points assigned to this pool. DPADs to distribute per block.
        uint256 lastRewardBlock;  // Last block number that DPADs distribution occurs.
        uint256 accDpadPerShare; // Accumulated DPADs per share, times 1e12. See below.
        uint32 lockTime;
    }

    // The DPAD TOKEN!
    IBEP20 public DPAD;

    // DPAD tokens created per block.
    uint256 public DPADPerBlock;

    // Info of each pool.
    PoolInfo[] public poolInfo;
    // Info of each user that stakes Staking tokens.
    mapping (uint256 => mapping (address => UserInfo)) public userInfo;
    // Total allocation points. Must be the sum of all allocation points in all pools.
    uint256 public totalAllocPoint = 0;
    // The block number when DPAD mining starts.
    uint256 public startBlock;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        IBEP20 _DPAD,
        uint256 _DPADPerBlock,
        uint256 _startBlock
    ) public {
        DPAD = _DPAD;
        DPADPerBlock = _DPADPerBlock;
        startBlock = _startBlock;

    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    // Add a new lp to the pool. Can only be called by the owner.
    // XXX DO NOT add the same Staking token more than once. Rewards will be messed up if you do.
    function add(uint256 _allocPoint, IBEP20 _stakingToken, bool _withUpdate, uint32 _lockTime) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(PoolInfo({
        stakingToken: _stakingToken,
        allocPoint: _allocPoint,
        lastRewardBlock: lastRewardBlock,
        accDpadPerShare: 0,
        lockTime: _lockTime
        }));
    }

    // Update the given pool's DPAD allocation point. Can only be called by the owner.
    function set(uint256 _pid, uint256 _allocPoint, bool _withUpdate, uint32 _lockTime) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 prevAllocPoint = poolInfo[_pid].allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
        poolInfo[_pid].lockTime = _lockTime;
        if (prevAllocPoint != _allocPoint) {
            totalAllocPoint = totalAllocPoint.sub(prevAllocPoint).add(_allocPoint);
        }
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        return _to.sub(_from);
    }

    // View function to see pending DPADs on frontend.
    function pendingDpad(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accDpadPerShare = pool.accDpadPerShare;
        uint256 stakingTokenSupply = pool.stakingToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && stakingTokenSupply != 0) {
            uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
            uint256 DPADReward = multiplier.mul(DPADPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
            accDpadPerShare = accDpadPerShare.add(DPADReward.mul(1e12).div(stakingTokenSupply));
        }
        return user.amount.mul(accDpadPerShare).div(1e12).sub(user.rewardDebt);
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
        uint256 stakingTokenSupply = pool.stakingToken.balanceOf(address(this));
        if (stakingTokenSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        uint256 DPADReward = multiplier.mul(DPADPerBlock).mul(pool.allocPoint).div(totalAllocPoint);
//        DPAD.mint(address(syrup), DPADReward);
        pool.accDpadPerShare = pool.accDpadPerShare.add(DPADReward.mul(1e12).div(stakingTokenSupply));
        pool.lastRewardBlock = block.number;
    }

    // Deposit Staking tokens to Staking for DPAD allocation.
    function deposit(uint256 _pid, uint256 _amount) public {

//        require (_pid != 0, 'deposit DPAD by staking');

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount.mul(pool.accDpadPerShare).div(1e12).sub(user.rewardDebt);
            if(pending > 0) {
                safeDpadTransfer(msg.sender, pending);
            }
        }
        if (_amount > 0) {
            pool.stakingToken.safeTransferFrom(address(msg.sender), address(this), _amount);
            user.amount = user.amount.add(_amount);
        }
        user.rewardDebt = user.amount.mul(pool.accDpadPerShare).div(1e12);

        if (user.lockedTill == 0) { // First deposit in the pool
            user.lockedTill = uint32(block.timestamp) + pool.lockTime;
        }

        emit Deposit(msg.sender, _pid, _amount);
    }

    // Withdraw Staking tokens from Staking.
    function withdraw(uint256 _pid, uint256 _amount) public {

//        require (_pid != 0, 'withdraw DPAD by unstaking');
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require (user.lockedTill <= block.timestamp, 'withdraw not unlocked yet');
        require(user.amount >= _amount, "withdraw: not good");

        updatePool(_pid);
        uint256 pending = user.amount.mul(pool.accDpadPerShare).div(1e12).sub(user.rewardDebt);
        if(pending > 0) {
            safeDpadTransfer(msg.sender, pending);
        }
        if(_amount > 0) {
            user.amount = user.amount.sub(_amount);
            pool.stakingToken.safeTransfer(address(msg.sender), _amount);
        }
        user.rewardDebt = user.amount.mul(pool.accDpadPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _amount);
    }


    // Withdraw without caring about rewards. EMERGENCY ONLY.
    function emergencyWithdraw(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        pool.stakingToken.safeTransfer(address(msg.sender), user.amount);
        emit EmergencyWithdraw(msg.sender, _pid, user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
    }

    // Safe DPAD transfer function, just in case if rounding error causes pool to not have enough DPADs.
    function safeDpadTransfer(address _to, uint256 _amount) internal {
        DPAD.transfer(_to, _amount);
    }
}
