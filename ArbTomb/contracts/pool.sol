// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "./interfaces/IUniswapV2Pair.sol";
import "./interfaces/IUniswapV2Factory.sol";

// Note that this pool has no minter key of PARB (rewards).
// Instead, the governance will call PARB distributeReward method and send reward to this pool at the beginning.
contract ParbRewardPool is ReentrancyGuard {
  using SafeMath for uint256;
  using SafeERC20 for IERC20;

  // governance
  address public operator;

  // Info of each user.
  struct UserInfo {
    uint256 amount; // How many tokens the user has provided.
    uint256 rewardDebt; // Deposit debt. See explanation below.
    address referrer; // Referrer address
  }

  struct ReferrerInfo {
    uint256 amount; // How many tokens the user has referred.
  }

  // Info of each pool.
  struct PoolInfo {
    IERC20 token; // Address of LP token contract.
    uint256 allocPoint; // How many allocation points assigned to this pool. PARB to distribute.
    uint256 lastRewardTime; // Last time that PARB distribution occurs.
    uint256 accPARBPerShare; // Accumulated PARB per share, times 1e18. See below.
    bool isStarted; // if lastRewardBlock has passed
    uint256 depositFeeBP; // Deposit fee. 10000 = 100%
  }

  IERC20 public parb;
  IERC20 public xarb;

  // Info of each pool.
  PoolInfo[] public poolInfo;

  // Info of each user that stakes tokens.
  mapping(uint256 => mapping(address => UserInfo)) public userInfo;
  mapping(uint256 => mapping(address => ReferrerInfo)) public referrerInfo;

  // Total allocation points. Must be the sum of all allocation points in all pools.
  uint256 public totalAllocPoint = 0;

  // The time when PARB mining starts.
  uint256 public poolStartTime;

  // The time when PARB mining ends.
  uint256 public poolEndTime;

  // Meerkat factory address
  address public MeerkatFactory = 0xfe3699303D3Eb460638e8aDA2bf1cFf092C33F22;
  address public arb = 0x912CE59144191C1204E64559FE8253a0e49E6548;
  address public usdc = 0xFF970A61A04b1cA14834A43f5dE4533eBDDB5CC8;

  uint256 public parbPerSecond = 0.11574 ether; // 70000 PARB / (7days * 24h * 60min * 60s)
  uint256 public runningTime = 7 days;
  uint256 public constant TOTAL_REWARDS = 70000 ether;

  event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
  event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
  event EmergencyWithdraw(address indexed user, uint256 indexed pid, uint256 amount);
  event RewardPaid(address indexed user, uint256 amount);

  constructor(address _parb, address _xarb, uint256 _poolStartTime) {
    require(block.timestamp < _poolStartTime, "late");
    if (_parb != address(0)) parb = IERC20(_parb);
    if (_xarb != address(0)) xarb = IERC20(_xarb);

    poolStartTime = _poolStartTime;
    poolEndTime = poolStartTime + runningTime;
    operator = msg.sender;
  }

  modifier onlyOperator() {
    require(operator == msg.sender, "ParbRewardPool: caller is not the operator");
    _;
  }

  function checkPoolDuplicate(IERC20 _token) internal view {
    uint256 length = poolInfo.length;
    for (uint256 pid = 0; pid < length; ++pid) {
      require(poolInfo[pid].token != _token, "ParbRewardPool: existing pool?");
    }
  }

  // Add a new pool. Can only be called by the owner.
  // @ _allocPoint - amount of parb this pool will emit
  // @ _token - token that can be deposited into this pool
  function add(
    uint256 _allocPoint,
    IERC20 _token,
    bool _withUpdate,
    uint256 _lastRewardTime,
    uint256 _depositFeeBP
  ) public onlyOperator {
    require(_depositFeeBP <= 100, "ParbRewardPool: deposit fee cap is 1%");
    checkPoolDuplicate(_token);
    if (_withUpdate) {
      massUpdatePools();
    }
    if (block.timestamp < poolStartTime) {
      // chef is sleeping
      if (_lastRewardTime == 0) {
        _lastRewardTime = poolStartTime;
      } else {
        if (_lastRewardTime < poolStartTime) {
          _lastRewardTime = poolStartTime;
        }
      }
    } else {
      // chef is cooking
      if (_lastRewardTime == 0 || _lastRewardTime < block.timestamp) {
        _lastRewardTime = block.timestamp;
      }
    }
    bool _isStarted = (_lastRewardTime <= poolStartTime) || (_lastRewardTime <= block.timestamp);
    poolInfo.push(
      PoolInfo({
        token: _token,
        allocPoint: _allocPoint,
        lastRewardTime: _lastRewardTime,
        accPARBPerShare: 0,
        isStarted: _isStarted,
        depositFeeBP: _depositFeeBP
      })
    );
    if (_isStarted) {
      totalAllocPoint = totalAllocPoint.add(_allocPoint);
    }
  }

  // Update the given pool's PARB allocation point. Can only be called by the owner.
  function set(uint256 _pid, uint256 _allocPoint) public onlyOperator {
    massUpdatePools();
    PoolInfo storage pool = poolInfo[_pid];
    if (pool.isStarted) {
      totalAllocPoint = totalAllocPoint.sub(pool.allocPoint).add(_allocPoint);
    }
    pool.allocPoint = _allocPoint;
  }

  // Return asset value in USDC
  function getAssetValue(
    address _token,
    uint256 _amount,
    bool _isLP
  ) public view returns (uint256) {
    require(_token != address(0), "ParbRewardPool: Invalid token address");

    if (_isLP) {
      // LP token value
      uint256 totalSupply = IUniswapV2Pair(_token).totalSupply();
      uint256 arbBalanceInLP = IERC20(arb).balanceOf(_token);
      uint256 priceOfOneArb = getAssetValue(arb, 1e18, false);
      return _amount.mul(arbBalanceInLP).mul(priceOfOneArb).mul(2).div(totalSupply).div(1e18);
    } 
    
    if (_token == usdc) {
      return _amount;
    } else if(_token == address(xarb)) {
      address arbParbLP = IUniswapV2Factory(MeerkatFactory).getPair(address(parb), arb);
      uint256 parbBalanceInLP = IERC20(address(parb)).balanceOf(arbParbLP);
      uint256 arbBalanceInLP = IERC20(arb).balanceOf(arbParbLP);
      uint256 priceOfOneArb = getAssetValue(arb, 1e18, false);
      return _amount.mul(arbBalanceInLP).mul(priceOfOneArb).div(parbBalanceInLP).div(1e18);
    } else {
      address usdcTokenLP = IUniswapV2Factory(MeerkatFactory).getPair(usdc, _token);
      uint256 tokenBalanceInLP = IERC20(_token).balanceOf(usdcTokenLP);
      uint256 usdcBalanceInLP = IERC20(usdc).balanceOf(usdcTokenLP);
      return _amount.mul(usdcBalanceInLP).div(tokenBalanceInLP);
    }
  }

  // Return accumulate rewards over the given _from to _to block.
  function getGeneratedReward(uint256 _fromTime, uint256 _toTime) public view returns (uint256) {
    if (_fromTime >= _toTime) return 0;
    if (_toTime >= poolEndTime) {
      if (_fromTime >= poolEndTime) return 0;
      if (_fromTime <= poolStartTime) return poolEndTime.sub(poolStartTime).mul(parbPerSecond);
      return poolEndTime.sub(_fromTime).mul(parbPerSecond);
    } else {
      if (_toTime <= poolStartTime) return 0;
      if (_fromTime <= poolStartTime) return _toTime.sub(poolStartTime).mul(parbPerSecond);
      return _toTime.sub(_fromTime).mul(parbPerSecond);
    }
  }

  // View function to see pending PARB on frontend.
  function pendingPARB(uint256 _pid, address _user) external view returns (uint256) {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][_user];
    uint256 accPARBPerShare = pool.accPARBPerShare;
    uint256 tokenSupply = pool.token.balanceOf(address(this));
    if (block.timestamp > pool.lastRewardTime && tokenSupply != 0) {
      uint256 _generatedReward = getGeneratedReward(pool.lastRewardTime, block.timestamp);
      uint256 _parbReward = _generatedReward.mul(pool.allocPoint).div(totalAllocPoint);
      accPARBPerShare = accPARBPerShare.add(_parbReward.mul(1e18).div(tokenSupply));
    }
    // ok so all multiplication can go first and then all divisions go last....same 1 line like before
    return user.amount.mul(accPARBPerShare).div(1e18).sub(user.rewardDebt);
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
    if (block.timestamp <= pool.lastRewardTime) {
      return;
    }
    uint256 tokenSupply = pool.token.balanceOf(address(this));
    if (tokenSupply == 0) {
      pool.lastRewardTime = block.timestamp;
      return;
    }
    if (!pool.isStarted) {
      pool.isStarted = true;
      totalAllocPoint = totalAllocPoint.add(pool.allocPoint);
    }
    if (totalAllocPoint > 0) {
      uint256 _generatedReward = getGeneratedReward(pool.lastRewardTime, block.timestamp);
      uint256 _parbReward = _generatedReward.mul(pool.allocPoint).div(totalAllocPoint);
      pool.accPARBPerShare = pool.accPARBPerShare.add(_parbReward.mul(1e18).div(tokenSupply));
    }
    pool.lastRewardTime = block.timestamp;
  }

  // Deposit tokens.

  function deposit(uint256 _pid, uint256 _amount, address _referrer) public nonReentrant {
    address _sender = msg.sender;
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][_sender];
    
    updatePool(_pid);
    if (_amount > 0 && user.referrer == address(0) && _referrer != msg.sender) {
      user.referrer = _referrer;
    }
    if (user.amount > 0) {
      // transfer rewards to user if any pending rewards
      uint256 _pending = user.amount.mul(pool.accPARBPerShare).div(1e18).sub(user.rewardDebt);
      if (_pending > 0) {
        // send pending reward to user, if rewards accumulating in _pending
        safePARBTransfer(_sender, _pending);
        emit RewardPaid(_sender, _pending);
      }
    }
    if (_amount > 0) {
      pool.token.safeTransferFrom(_sender, address(this), _amount);
      ReferrerInfo storage referrer = referrerInfo[_pid][_referrer];
      uint256 depositDebt = _amount.mul(pool.depositFeeBP).div(10000);
      _amount = _amount.sub(depositDebt);
      user.amount = user.amount.add(_amount);
      referrer.amount = referrer.amount.add(_amount);
      // Calculate the total value locked on the genesis pools, referral value
      uint256 totalValueLocked = 0;
      uint256 referralValue = 0;
      for (uint256 pid = 0; pid < poolInfo.length; pid ++) {
        bool isLP = pid == 0;
        address token = address(poolInfo[pid].token);
        uint256 amount = poolInfo[pid].token.balanceOf(address(this));
        totalValueLocked = totalValueLocked.add(getAssetValue(token, amount, isLP));
        referralValue = referralValue.add(getAssetValue(token, referrerInfo[pid][user.referrer].amount, isLP));
      }
      // transfer reward to the referrer
      if (depositDebt != 0 && totalValueLocked != 0) {
        uint256 referralReward = depositDebt.mul(referralValue).div(totalValueLocked);
        pool.token.safeTransfer(_referrer, referralReward);
      }
    }
    user.rewardDebt = user.amount.mul(pool.accPARBPerShare).div(1e18);
    emit Deposit(_sender, _pid, _amount);
  }

  // Withdraw tokens.
  function withdraw(uint256 _pid, uint256 _amount) public nonReentrant {
    address _sender = msg.sender;
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][_sender];
    ReferrerInfo storage referrer = referrerInfo[_pid][user.referrer];
    require(user.amount >= _amount, "ParbRewardPool: withdraw not good");
    updatePool(_pid);
    uint256 _pending = user.amount.mul(pool.accPARBPerShare).div(1e18).sub(user.rewardDebt);
    if (_pending > 0) {
      safePARBTransfer(_sender, _pending);
      emit RewardPaid(_sender, _pending);
    }
    if (_amount > 0) {
      user.amount = user.amount.sub(_amount);
      referrer.amount = referrer.amount.sub(_amount);
      pool.token.safeTransfer(_sender, _amount);
    }
    user.rewardDebt = user.amount.mul(pool.accPARBPerShare).div(1e18);
    emit Withdraw(_sender, _pid, _amount);
  }

  // Withdraw without caring about rewards. EMERGENCY ONLY.
  function emergencyWithdraw(uint256 _pid) public {
    PoolInfo storage pool = poolInfo[_pid];
    UserInfo storage user = userInfo[_pid][msg.sender];
    ReferrerInfo storage referrer = referrerInfo[_pid][user.referrer];
    uint256 _amount = user.amount;
    user.amount = 0;
    user.rewardDebt = 0;
    referrer.amount = referrer.amount.sub(_amount);
    pool.token.safeTransfer(msg.sender, _amount);
    emit EmergencyWithdraw(msg.sender, _pid, _amount);
  }

  // Safe PARB transfer function, in case if rounding error causes pool to not have enough PARBs.
  function safePARBTransfer(address _to, uint256 _amount) internal {
    uint256 _parbBalance = parb.balanceOf(address(this));
    if (_parbBalance > 0) {
      if (_amount > _parbBalance) {
        parb.safeTransfer(_to, _parbBalance);
      } else {
        parb.safeTransfer(_to, _amount);
      }
    }
  }

  function setOperator(address _operator) external onlyOperator {
    operator = _operator;
  }

  function governanceRecoverUnsupported(
    IERC20 _token,
    uint256 amount,
    address to
  ) external onlyOperator {
    if (block.timestamp < poolEndTime + 30 days) {
      // do not allow to drain core token (gov or lps) if less than 90 days after pool ends
      require(_token != parb, "parb");
      uint256 length = poolInfo.length;
      for (uint256 pid = 0; pid < length; ++pid) {
        PoolInfo storage pool = poolInfo[pid];
        require(_token != pool.token, "pool.token");
      }
    }
    _token.safeTransfer(to, amount);
  }
}

