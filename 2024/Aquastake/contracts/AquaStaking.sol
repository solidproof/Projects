/**
 *Submitted for verification at Etherscan.io on 2024-05-09
*/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
}

abstract contract Context {
    function _msgSender() internal view returns (address) {
        return msg.sender;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        _transferOwnership(_msgSender());
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    function _checkOwner() private view {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    function renounceOwnership() external onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) external onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract ReentrancyGuard {
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");

        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        _status = _NOT_ENTERED;
    }

    function _reentrancyGuardEntered() private view returns (bool) {
        return _status == _ENTERED;
    }
}

contract AQUAStaking is Ownable, ReentrancyGuard {
    struct PoolInfo {
        uint256 lockupDuration;
        uint256 returnPer;
    }
    struct OrderInfo {
        address beneficiary;
        uint256 amount;
        uint256 lockupDuration;
        uint256 returnPer;
        uint256 starttime;
        uint256 endtime;
        uint256 claimedReward;
        bool claimed;
    }
    uint256 private constant _1Year =  7 days ; 
    uint256 private constant _days365 = 365 days; 
    IERC20 public AQUA;
    IERC20 public sAQUA;

    bool private started = true;
    uint256 private latestOrderId = 0;
    uint256 public totalStakers;
    uint256 public totalStaked;
    uint256 public currentStaked;

    mapping(uint256 => PoolInfo) public pooldata;
    mapping(address => uint256) public balanceOf;
    mapping(address => uint256) public totalRewardEarn;
    mapping(uint256 => OrderInfo) public orders;
    mapping(address => uint256[]) private orderIds;
    mapping(address => mapping(uint256 => bool)) public hasStaked;
    mapping(uint256 => uint256) public stakeOnPool;
    mapping(uint256 => uint256) public rewardOnPool;
    mapping(uint256 => uint256) public stakersPlan;

    event Deposit(
        address indexed user,
        uint256 indexed lockupDuration,
        uint256 amount,
        uint256 returnPer
    );
    event Withdraw(
        address indexed user,
        uint256 amount,
        uint256 reward,
        uint256 total
    );
    event WithdrawAll(address indexed user, uint256 amount);
    event RewardClaimed(address indexed user, uint256 reward);

    constructor(
        address _aquaAddress,
        address _saquaAddress,
        uint256 _apy
    ) {
        AQUA = IERC20(_aquaAddress);
        sAQUA = IERC20(_saquaAddress);
        pooldata[1].lockupDuration = _1Year;
        pooldata[1].returnPer = _apy;
    }

    function stake(uint256 _amount, uint256 _lockupDuration) external {
        PoolInfo storage pool = pooldata[_lockupDuration];
        require(
            pool.lockupDuration > 0,
            "AQUAStaking: asked pool does not exist"
        );
        require(started, "AQUAStaking: staking not yet started");
        require(_amount > 0, "AQUAStaking: stake amount must be non zero");
        require(
            AQUA.transferFrom(_msgSender(), address(this), _amount),
            "AQUAStaking: AQUA transferFrom via deposit not succeeded"
        );

        orders[++latestOrderId] = OrderInfo(
            _msgSender(),
            _amount,
            pool.lockupDuration,
            pool.returnPer,
            block.timestamp,
            block.timestamp + pool.lockupDuration,
            0,
            false
        );

        if (!hasStaked[msg.sender][_lockupDuration]) {
            stakersPlan[_lockupDuration] = stakersPlan[_lockupDuration] + 1;
            totalStakers = totalStakers + 1;
        }

        //updating staking status

        hasStaked[msg.sender][_lockupDuration] = true;
        stakeOnPool[_lockupDuration] = stakeOnPool[_lockupDuration] + _amount;
        totalStaked = totalStaked + _amount;
        currentStaked = currentStaked + _amount;
        balanceOf[_msgSender()] += _amount;
        orderIds[_msgSender()].push(latestOrderId);
        emit Deposit(
            _msgSender(),
            pool.lockupDuration,
            _amount,
            pool.returnPer
        );
    }

    function unStake(uint256 orderId) external nonReentrant {
        require(
            orderId <= latestOrderId,
            "AQUAStaking: INVALID orderId, orderId greater than latestOrderId"
        );

        OrderInfo storage orderInfo = orders[orderId];
        require(
            _msgSender() == orderInfo.beneficiary,
            "AQUAStaking: caller is not the beneficiary"
        );
        require(!orderInfo.claimed, "AQUAStaking: order already unstaked");
        require(
            block.timestamp >= orderInfo.endtime,
            "AQUAStaking: stake locked until lock duration completion"
        );
        uint256 total = orderInfo.amount;
        balanceOf[_msgSender()] -= orderInfo.amount;
        currentStaked = currentStaked - orderInfo.amount ;
        orderInfo.claimed = true;

        require(
            AQUA.transfer(address(_msgSender()), total),
            "AQUAStaking: AQUA transfer via withdraw not succeeded"
        );
        emit Withdraw(_msgSender(), orderInfo.amount, total, total);
    }

    function claimRewards(uint256 orderId) external nonReentrant {
        require(
            orderId <= latestOrderId,
            "AQUAStaking: INVALID orderId, orderId greater than latestOrderId"
        );

        OrderInfo storage orderInfo = orders[orderId];
        require(
            _msgSender() == orderInfo.beneficiary,
            "AQUAStaking: caller is not the beneficiary"
        );
        require(!orderInfo.claimed, "AQUAStaking: order already unstaked");

        uint256 claimAvailable = pendingRewards(orderId);
        totalRewardEarn[_msgSender()] += claimAvailable;

        orderInfo.claimedReward += claimAvailable;

        require(
            sAQUA.transfer(address(_msgSender()), claimAvailable),
            "AQUAStaking: sAQUA transfer via claim rewards not succeeded"
        );
        rewardOnPool[orderInfo.lockupDuration] =
            rewardOnPool[orderInfo.lockupDuration] +
            claimAvailable;
        emit RewardClaimed(address(_msgSender()), claimAvailable);
    }

    function pendingRewards(uint256 orderId) public view returns (uint256) {
        require(
            orderId <= latestOrderId,
            "AQUAStaking: INVALID orderId, orderId greater than latestOrderId"
        );

        OrderInfo storage orderInfo = orders[orderId];
        if (!orderInfo.claimed) {
            if (block.timestamp >= orderInfo.endtime) {
                uint256 APY = (orderInfo.amount * orderInfo.returnPer) / 100;
                uint256 reward = (APY * orderInfo.lockupDuration) / _days365;
                uint256 claimAvailable = reward - orderInfo.claimedReward;
                return claimAvailable;
            } else {
                uint256 stakeTime = block.timestamp - orderInfo.starttime;
                uint256 APY = (orderInfo.amount * orderInfo.returnPer) / 100;
                uint256 reward = (APY * stakeTime) / _days365;
                uint256 claimAvailableNow = reward - orderInfo.claimedReward;
                return claimAvailableNow;
            }
        } else {
            return 0;
        }
    }

    function setPlansApy(uint256 plan1Apy) external onlyOwner {
        pooldata[1].returnPer = plan1Apy;
    }

    function toggleStaking(bool _start) external onlyOwner returns (bool) {
        started = _start;
        return true;
    }

    function investorOrderIds(address investor)
        external
        view
        returns (uint256[] memory ids)
    {
        uint256[] memory arr = orderIds[investor];
        return arr;
    }

    function withdrawERC20(address _token) external onlyOwner {
        IERC20 withdraw_token = IERC20(_token);
        uint256 balance = withdraw_token.balanceOf(address(this));
        uint256 withdrawToken = balance - currentStaked ;
        require(
            withdraw_token.transfer(msg.sender, withdrawToken),
            "withdraw_token transfer failed"
        );
    }


   function withdrawAllTokens() external nonReentrant {
    uint256[] storage userOrderIds = orderIds[_msgSender()];
    uint256 totalStakedAmount;

    for (uint256 i = 0; i < userOrderIds.length; i++) {
        uint256 orderId = userOrderIds[i];
        OrderInfo storage orderInfo = orders[orderId];

        // Ensure order is not already unstaked
        require(!orderInfo.claimed, "AQUAStaking: order already unstaked");

       
        
        totalStakedAmount += orderInfo.amount;

        // Mark order as claimed
        orderInfo.claimed = true;

        // Emit event for tokens withdrawn
        emit Withdraw(_msgSender(), orderInfo.amount, orderInfo.amount, orderInfo.amount);
    }

    // Transfer total staked amount back to user
      
    require(
        AQUA.transfer(_msgSender(), totalStakedAmount),
        "AQUAStaking: AQUA transfer via withdraw not succeeded"
    );

    currentStaked = currentStaked - totalStakedAmount;
    balanceOf[_msgSender()] -= totalStakedAmount;

    // Emit event for successful withdrawal
    emit WithdrawAll(_msgSender(), totalStakedAmount);
}

  function claimAllRemainingRewards() external nonReentrant {
    uint256[] storage userOrderIds = orderIds[_msgSender()];
    uint256 totalRewards;

    for (uint256 i = 0; i < userOrderIds.length; i++) {
        uint256 orderId = userOrderIds[i];
        OrderInfo storage orderInfo = orders[orderId];

        // Ensure order is not already claimed
        require(!orderInfo.claimed, "AQUAStaking: order already claimed");

        // Calculate and accumulate remaining rewards
        uint256 claimAvailable = pendingRewards(orderId);
        totalRewards += claimAvailable;
        orderInfo.claimedReward += claimAvailable;
        rewardOnPool[orderInfo.lockupDuration] += claimAvailable;

        // Emit event for reward claimed
        emit RewardClaimed(_msgSender(), claimAvailable);
    }

    // Transfer total rewards to user
    require(
        sAQUA.transfer(_msgSender(), totalRewards),
        "AQUAStaking: sAQUA transfer via claim rewards not succeeded"
    );

    // Emit event for successful reward claim
    emit RewardClaimed(_msgSender(), totalRewards);
}

function viewTotalPendingRewards(address user) external view returns (uint256) {
    uint256[] storage userOrderIds = orderIds[user];
    uint256 totalPendingRewards;

    for (uint256 i = 0; i < userOrderIds.length; i++) {
        uint256 orderId = userOrderIds[i];
        totalPendingRewards += pendingRewards(orderId);
    }

    return totalPendingRewards;
}


}