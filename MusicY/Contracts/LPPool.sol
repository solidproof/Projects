// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";

contract LPPool is OwnableUpgradeable, ReentrancyGuardUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
    }

    struct PoolInfo {
        IERC20Upgradeable lpToken;
        uint256 allocPoint;
        uint256 lastRewardBlock;
        uint256 accRewardPerShare;
    }

    IERC20Upgradeable public rewardToken;

    uint256 public rewardPerBlock;

    PoolInfo[] public poolInfo;

    mapping(uint256 => mapping(address => UserInfo)) public userInfo;

    mapping(address => mapping(uint256 => uint256)) public userOperateTimestamp;

    uint256 public stakePeriod;
    uint256 public redemptionFeeRate;

    uint256 public totalAllocPoint;

    uint256 public startBlock;

    uint256 public oneYearBlockNum;
    uint256 public maxHalvingYears;

    address public redemptionFeeReceiver;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);
    event rewardUser(address indexed _user, uint256 _amount);

    modifier inPoolTime() {
        require(block.number >= startBlock, "LPPool#inPoolTime: LP not start");
        _;
    }

    modifier updateOperateTime(uint256 _pid) {
        _;
        userOperateTimestamp[msg.sender][_pid] = block.timestamp;
    }

    modifier onlyEOA() {
        require(
            msg.sender == tx.origin,
            "LPPool#onlyEOA: only the EOA address"
        );
        _;
    }

    function initialize(
        address _rewardToken,
        address _redemptionFeeReceiver,
        uint256 _rewardPerBlock,
        uint256 _startBlock,
        uint256 _oneYearBlockNum,
        uint256 _stakePeriod,
        uint256 _maxHalvingYears,
        uint256 _redemptionFeeRate
    ) public initializer {
        __ReentrancyGuard_init();
        __Ownable_init();
        require(_rewardToken != address(0), "_rewardToken is zero address");
        //        require(_startBlock > block.number, "_startBlock should be after now");
        rewardToken = IERC20Upgradeable(_rewardToken);
        rewardPerBlock = _rewardPerBlock;
        startBlock = _startBlock;
        // todo change the limit
        totalAllocPoint = 0;
        oneYearBlockNum = _oneYearBlockNum;
        stakePeriod = _stakePeriod;
        maxHalvingYears = _maxHalvingYears;
        redemptionFeeRate = _redemptionFeeRate;
        redemptionFeeReceiver = _redemptionFeeReceiver;
    }

    /****************************   public onlyOwner function        *******************************/

    function setRewardToken(address _rewardToken) external onlyOwner {
        rewardToken = IERC20Upgradeable(_rewardToken);
    }

    function setRewardPerBlock(uint256 _rewardPerBlock) external onlyOwner {
        rewardPerBlock = _rewardPerBlock;
    }

    function setOneYearBlockNum(uint256 _oneYearBlockNum) external onlyOwner {
        oneYearBlockNum = _oneYearBlockNum;
    }

    function setStakeSetting(
        uint256 _stakePeriod,
        uint256 _redemptionFeeRate,
        address _redemptionFeeReceiver
    ) external onlyOwner {
        stakePeriod = _stakePeriod;
        redemptionFeeRate = _redemptionFeeRate;
        redemptionFeeReceiver = _redemptionFeeReceiver;
    }

    function add(
        uint256 _allocPoint,
        address _lpToken,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        uint256 lastRewardBlock = block.number > startBlock
            ? block.number
            : startBlock;
        totalAllocPoint = totalAllocPoint + _allocPoint;
        poolInfo.push(
            PoolInfo({
                lpToken: IERC20Upgradeable(_lpToken),
                allocPoint: _allocPoint,
                lastRewardBlock: lastRewardBlock,
                accRewardPerShare: 0
            })
        );
    }

    function set(
        uint256 _pid,
        uint256 _allocPoint,
        bool _withUpdate
    ) public onlyOwner {
        if (_withUpdate) {
            massUpdatePools();
        }
        totalAllocPoint =
            totalAllocPoint -
            poolInfo[_pid].allocPoint +
            _allocPoint;
        poolInfo[_pid].allocPoint = _allocPoint;
    }

    function transferToken(
        IERC20Upgradeable tokenAddress,
        address to,
        uint256 amount
    ) external onlyOwner {
        tokenAddress.safeTransfer(to, amount);
    }

    /****************************   public update Pool function        *******************************/

    // Update reward vairables for all pools. Be careful of gas spending!
    function massUpdatePools() public nonReentrant {
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
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (lpSupply == 0) {
            pool.lastRewardBlock = block.number;
            return;
        }
        uint256 multiplier = block.number - pool.lastRewardBlock;
        uint256 reward = (multiplier * getRewardPerBlock() * pool.allocPoint) /
            (totalAllocPoint);

        pool.accRewardPerShare =
            pool.accRewardPerShare +
            ((reward * (1e18)) / (lpSupply));
        pool.lastRewardBlock = block.number;
    }

    /****************************   public user operate function        *******************************/

    function deposit(uint256 _pid, uint256 _amount)
        public
        inPoolTime
        nonReentrant
        onlyEOA
        updateOperateTime(_pid)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);

        if (user.amount > 0) {
            uint256 pending = (user.amount * (pool.accRewardPerShare)) /
                (1e18) -
                (user.rewardDebt);
            safeRewardTransfer(msg.sender, pending);
        }

        pool.lpToken.safeTransferFrom(
            address(msg.sender),
            address(this),
            _amount
        );
        user.amount = user.amount + _amount;
        user.rewardDebt = (user.amount * pool.accRewardPerShare) / (1e18);
        emit Deposit(msg.sender, _pid, _amount);
    }

    function withdraw(uint256 _pid, uint256 _amount)
        public
        inPoolTime
        onlyEOA
        nonReentrant
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        require(
            user.amount >= _amount,
            "LPPool#withdraw: amount is unexpected"
        );
        updatePool(_pid);
        uint256 pending = (user.amount * pool.accRewardPerShare) /
            (1e18) -
            user.rewardDebt;
        safeRewardTransfer(msg.sender, pending);
        user.amount = user.amount - _amount;
        user.rewardDebt = (user.amount * (pool.accRewardPerShare)) / (1e18);
        uint256 redemptionFee = calcRedemptionFee(msg.sender, _pid, _amount);
        if (redemptionFee > 0) {
            pool.lpToken.safeTransfer(redemptionFeeReceiver, redemptionFee);
        }
        uint256 actualAmount = _amount - redemptionFee;
        pool.lpToken.safeTransfer(address(msg.sender), actualAmount);
        emit Withdraw(msg.sender, _pid, _amount);
    }

    function getReward(uint256 _pid) public inPoolTime onlyEOA nonReentrant {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][msg.sender];
        updatePool(_pid);
        uint256 pending = (user.amount * pool.accRewardPerShare) /
            (1e18) -
            user.rewardDebt;
        safeRewardTransfer(msg.sender, pending);
        user.rewardDebt = (user.amount * (pool.accRewardPerShare)) / (1e18);
    }

    /****************************   internal transfer function        *******************************/

    function safeRewardTransfer(address _to, uint256 _amount) internal {
        uint256 rewardBal = rewardToken.balanceOf(address(this));
        if (_amount > rewardBal) {
            rewardToken.safeTransfer(_to, rewardBal);
            emit rewardUser(_to, rewardBal);
        } else {
            rewardToken.safeTransfer(_to, _amount);
            emit rewardUser(_to, _amount);
        }
    }

    /****************************   public view function        *******************************/

    function getRewardPerBlock() public view inPoolTime returns (uint256) {
        if (block.number < startBlock) {
            return 0;
        }
        uint256 spendYears = (block.number - startBlock) / oneYearBlockNum;
        if (spendYears > maxHalvingYears) {
            spendYears = maxHalvingYears;
        }
        return rewardPerBlock / (2**spendYears);
    }

    function pendingReward(uint256 _pid, address _user)
        public
        view
        inPoolTime
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accRewardPerShare = pool.accRewardPerShare;
        uint256 lpSupply = pool.lpToken.balanceOf(address(this));
        if (block.number > pool.lastRewardBlock && lpSupply != 0) {
            uint256 multiplier = block.number - pool.lastRewardBlock;
            uint256 reward = (multiplier *
                getRewardPerBlock() *
                pool.allocPoint) / totalAllocPoint;
            accRewardPerShare =
                accRewardPerShare +
                ((reward * (1e18)) / lpSupply);
        }
        return (user.amount * accRewardPerShare) / (1e18) - user.rewardDebt;
    }

    function calcRedemptionFee(
        address _user,
        uint256 _pid,
        uint256 _amountToWithdraw
    ) public view returns (uint256) {
        uint256 ts = userOperateTimestamp[_user][_pid];
        require(ts > 0, "ts <= 0");
        require(ts <= block.timestamp, "ts <= block.timestamp");

        uint256 delta = block.timestamp - ts;
        uint256 redemptionFee = 0;

        if (delta <= stakePeriod) {
            redemptionFee = (_amountToWithdraw * redemptionFeeRate) / 1000;
        }
        return redemptionFee;
    }

    function poolLength() public view returns (uint256) {
        return poolInfo.length;
    }

    function getLPFarmsInfo()
        public
        view
        returns (
            uint256 lpStakePeriod,
            uint256 lpRedemptionFeeRate,
            uint256 lpTotalAllocPoint,
            uint256 lpStartBlock,
            uint256 lpActualRewardPerBlock,
            uint256 lpOneYearBlockNum,
            uint256 lpInitRewardPerBlock,
            uint256 lpSendRewards,
            address lpRedemptionFeeReceiver,
            address lpRewardToken
        )
    {
        lpActualRewardPerBlock = getRewardPerBlock();

        if (block.number < startBlock) {
            lpSendRewards = 0;
        } else {
            uint256 spendYears = (block.number - startBlock) / oneYearBlockNum;
            if (spendYears > maxHalvingYears) {
                spendYears = maxHalvingYears;
            }
            lpSendRewards =
                (block.number - startBlock) *
                lpActualRewardPerBlock;
            for (uint256 i = spendYears; i > 0; i--) {
                lpSendRewards =
                    lpSendRewards +
                    lpActualRewardPerBlock *
                    (2**i - 1) *
                    oneYearBlockNum;
            }
        }
        return (
            stakePeriod,
            redemptionFeeRate,
            totalAllocPoint,
            startBlock,
            lpActualRewardPerBlock,
            oneYearBlockNum,
            rewardPerBlock,
            lpSendRewards,
            redemptionFeeReceiver,
            address(rewardToken)
        );
    }

    function getUserInfo(address _user)
        public
        view
        returns (uint256[] memory stakeAmounts, uint256[] memory rewardAmounts)
    {
        uint256 length = poolInfo.length;
        stakeAmounts = new uint256[](length);
        rewardAmounts = new uint256[](length);
        for (uint256 pid = 0; pid < length; pid++) {
            UserInfo storage user = userInfo[pid][_user];
            stakeAmounts[pid] = user.amount;
            rewardAmounts[pid] = pendingReward(pid, _user);
        }
        return (stakeAmounts, rewardAmounts);
    }
}
