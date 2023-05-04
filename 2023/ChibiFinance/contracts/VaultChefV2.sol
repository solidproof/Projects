// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "./lib/access/Ownable.sol";
import "./lib/token/ERC20/SafeERC20.sol";
import "./lib/utils/EnumerableSet.sol";
import "./lib/utils/ReentrancyGuard.sol";

import "./libs/IStrategy.sol";
import "./Operators.sol";

contract VaultChefV2 is Ownable, ReentrancyGuard, Operators {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    // Info of each user.
    struct UserInfo {
        uint256 shares; // How many LP tokens the user has provided.
        uint256 rewardDebt; 
    }

    struct PoolInfo {
        IERC20 want; // Address of the want token.
        uint256 allocPoint; // How many allocation points assigned to this pool. BCARD to distribute per block.
        uint256 lastRewardBlock; // Last block number that BCARD distribution occurs.
        uint256 accBCARDPerShare; // Accumulated BCARD per share, times 1e12. See below.
        address strat; // Strategy address that will BCARD compound want tokens
    }

    address public BCARD;

    address public burnAddress = 0x000000000000000000000000000000000000dEaD;

    uint256 public BCARDMaxSupply = 2222222e18;
    uint256 public BCARDPerBlock = 100e18; // BCARD tokens created per block
    uint256 public startBlock = 0; 

    PoolInfo[] public poolInfo; // Info of each pool.
    mapping(uint256 => mapping(address => UserInfo)) public userInfo; // Info of each user that stakes LP tokens.
    mapping(address => bool) private strats;
    uint256 public totalAllocPoint = 0; // Total allocation points. Must be the sum of all allocation points in all pools.

    event AddPool(address indexed strat);
    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);

    constructor(
        address _tokenAddress
    ) public {
        BCARD = _tokenAddress;
    }

    function poolLength() external view returns (uint256) {
        return poolInfo.length;
    }

    /**
     * @dev Add a new want to the pool. Can only be called by the owner.
     */
    function addPool(
        uint256 _allocPoint,
        IERC20 _want,
        bool _withUpdate,
        address _strat
    ) external onlyOwner nonReentrant {
        require(!strats[_strat], "Existing strategy");
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock =
            block.number > startBlock ? block.number : startBlock;
        totalAllocPoint = totalAllocPoint.add(_allocPoint);
        poolInfo.push(
            PoolInfo({
                want: IERC20(IStrategy(_strat).wantAddress()),
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accBCARDPerShare: 0,
                strat: _strat
            })
        );
        strats[_strat] = true;
        resetSingleAllowance(poolInfo.length.sub(1));
        emit AddPool(_strat);
    }

    // Update the given pool's BCARD allocation point. Can only be called by the owner.
    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint = totalAllocPoint.sub(poolInfo[_pid].allocPoint).add(
            _allocPoint
        );
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to)
        public
        view
        returns (uint256)
    {
        if (IERC20(BCARD).balanceOf(address(this)) == 0) {
            return 0;
        }
        return _to.sub(_from);
    }

    // View function to see pending BCARD on frontend.
    function pendingBCARD(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accBCARDPerShare = pool.accBCARDPerShare;
        uint256 sharesTotal = IStrategy(pool.strat).sharesTotal();
        if (block.number > pool.lastRewardBlock && sharesTotal != 0) {
            uint256 multiplier =
                getMultiplier(pool.lastRewardBlock, block.number);
            uint256 BCARDReward =
                multiplier.mul(BCARDPerBlock).mul(pool.allocPoint).div(
                    totalAllocPoint
                );
            accBCARDPerShare = accBCARDPerShare.add(
                BCARDReward.mul(1e12).div(sharesTotal)
            );
        }
        return user.shares.mul(accBCARDPerShare).div(1e12).sub(user.rewardDebt);
    }

    // View function to see staked Want tokens on frontend.
    function stakedWantTokens(uint256 _pid, address _user) external view returns (uint256) {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];

        uint256 sharesTotal = IStrategy(pool.strat).sharesTotal();
        uint256 wantLockedTotal = IStrategy(poolInfo[_pid].strat).wantLockedTotal();
        if (sharesTotal == 0) {
            return 0;
        }
        return user.shares.mul(wantLockedTotal).div(sharesTotal);
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
        uint256 sharesTotal = IStrategy(pool.strat).sharesTotal();
        if (sharesTotal == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = getMultiplier(pool.lastRewardBlock, block.number);
        if (multiplier <= 0) {
            return;
        }
        uint256 BCARDReward =
            multiplier.mul(BCARDPerBlock).mul(pool.allocPoint).div(
                totalAllocPoint
            );

        pool.accBCARDPerShare = pool.accBCARDPerShare.add(
            BCARDReward.mul(1e12).div(sharesTotal)
        );
        pool.lastRewardBlock = block.number;
    }

    // Want tokens moved from user -> this -> Strat (compounding)
    function deposit(uint256 _pid, uint256 _wantAmt) external nonReentrant {
        _deposit(_pid, _wantAmt, msg.sender);
    }

    // For unique contract calls
    function deposit(uint256 _pid, uint256 _wantAmt, address _to) external nonReentrant onlyOperator {
        _deposit(_pid, _wantAmt, _to);
    }
    
    function _deposit(uint256 _pid, uint256 _wantAmt, address _to) internal {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_to];

        if (user.shares > 0) {
            uint256 pending =
                user.shares.mul(pool.accBCARDPerShare).div(1e12).sub(
                    user.rewardDebt
                );
            if (pending > 0) {
                safeBCARDTransfer(msg.sender, pending);
            }
        }
        if (_wantAmt > 0) {
            pool.want.safeTransferFrom(msg.sender, address(this), _wantAmt);

            uint256 sharesAdded = IStrategy(poolInfo[_pid].strat).deposit(_to, _wantAmt);
            user.shares = user.shares.add(sharesAdded);
        }
        user.rewardDebt = user.shares.mul(pool.accBCARDPerShare).div(1e12);
        emit Deposit(_to, _pid, _wantAmt);
    }

    // Withdraw LP tokens from MasterChef.
    function withdraw(uint256 _pid, uint256 _wantAmt) external nonReentrant {
        _withdraw(_pid, _wantAmt, msg.sender);
    }

    // For unique contract calls
    function withdraw(uint256 _pid, uint256 _wantAmt, address _to) external nonReentrant onlyOperator {
        _withdraw(_pid, _wantAmt, _to);
    }

    function _withdraw(uint256 _pid, uint256 _wantAmt, address _to) internal {
        updatePool(_pid);

        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];

        uint256 wantLockedTotal = IStrategy(poolInfo[_pid].strat).wantLockedTotal();
        uint256 sharesTotal = IStrategy(poolInfo[_pid].strat).sharesTotal();

        require(user.shares > 0, "user.shares is 0");
        require(sharesTotal > 0, "sharesTotal is 0");

        // Withdraw pending BCARD
        uint256 pending =
            user.shares.mul(pool.accBCARDPerShare).div(1e12).sub(
                user.rewardDebt
            );
        if (pending > 0) {
            safeBCARDTransfer(msg.sender, pending);
        }
        // Withdraw want tokens
        uint256 amount = user.shares.mul(wantLockedTotal).div(sharesTotal);
        if (_wantAmt > amount) {
            _wantAmt = amount;
        }
        if (_wantAmt > 0) {
            uint256 sharesRemoved = IStrategy(poolInfo[_pid].strat).withdraw(msg.sender, _wantAmt);

            if (sharesRemoved > user.shares) {
                user.shares = 0;
            } else {
                user.shares = user.shares.sub(sharesRemoved);
            }

            uint256 wantBal = IERC20(pool.want).balanceOf(address(this));
            if (wantBal < _wantAmt) {
                _wantAmt = wantBal;
            }
            pool.want.safeTransfer(_to, _wantAmt);
        }
        user.rewardDebt = user.shares.mul(pool.accBCARDPerShare).div(1e12);
        emit Withdraw(msg.sender, _pid, _wantAmt);
    }

    // Withdraw everything from pool for yourself
    function withdrawAll(uint256 _pid) external {
        _withdraw(_pid, uint256(-1), msg.sender);
    }

    // Safe BCARD transfer function, just in case if rounding error causes pool to not have enough
    function safeBCARDTransfer(address _to, uint256 _BCARDAmt) internal {
        uint256 BCARDBal = IERC20(BCARD).balanceOf(address(this));
        if (_BCARDAmt > BCARDBal) {
            IERC20(BCARD).transfer(_to, BCARDBal);
        } else {
            IERC20(BCARD).transfer(_to, _BCARDAmt);
        }
    }

    function resetAllowances() external onlyOwner {
        for (uint256 i=0; i<poolInfo.length; i++) {
            PoolInfo storage pool = poolInfo[i];
            pool.want.safeApprove(pool.strat, uint256(0));
            pool.want.safeIncreaseAllowance(pool.strat, uint256(-1));
        }
    }

    function resetSingleAllowance(uint256 _pid) public onlyOwner {
        PoolInfo storage pool = poolInfo[_pid];
        pool.want.safeApprove(pool.strat, uint256(0));
        pool.want.safeIncreaseAllowance(pool.strat, uint256(-1));
    }
    
    function setBCARDPerBlock(uint256 _BCARDPerBlock) public onlyOwner {
        BCARDPerBlock = _BCARDPerBlock;
    }
    
    function setStartBlock(uint256 _startBlock) public onlyOwner {
        startBlock = _startBlock;
    }
}