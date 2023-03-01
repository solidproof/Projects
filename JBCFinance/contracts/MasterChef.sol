pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

interface IReward {
    function getReward(address user, uint256 amount) external;
}

contract MasterChef is Ownable {

    struct UserInfo {
        uint256 amount; 
        uint256 rewardDebt; 
        uint256 pending;
    }

    struct PoolInfo {
        address lpToken;
        uint256 balance;
        uint256 allocPoint; 
        uint256 lastRewardTimestamp; 
        uint256 accRewardPerShare; 
    }
    
    PoolInfo[] public poolInfo;
    mapping(uint256 => mapping(address => UserInfo)) public userInfo;
    uint256 public totalAllocPoint = 0;

    uint256 public curRewardRate;
    uint256 public immutable MAX_DAILY_REWARD_RATE = 200000e18;

    event Deposit(address indexed user, uint256 indexed pid, uint256 amount);
    event Withdraw(address indexed user, uint256 indexed pid, uint256 amount);


    function add(
        address _lpToken,
        uint256 _point
    ) public onlyOwner {
        massUpdatePools();
        totalAllocPoint += _point;
        poolInfo.push(
            PoolInfo({
                lpToken: _lpToken,
                balance: 0,
                allocPoint: _point,
                lastRewardTimestamp: block.timestamp,
                accRewardPerShare: 0
            })
        );
    }

    function set(
        uint256[] memory _pids,
        uint256[] memory _allocPoints
    ) public onlyOwner {        
        massUpdatePools();
        uint totalPoint = totalAllocPoint;
        for (uint i = 0; i < _pids.length; i++) {
            totalPoint = totalPoint - poolInfo[_pids[i]].allocPoint + _allocPoints[i];
            poolInfo[_pids[i]].allocPoint = _allocPoints[i];
        }
        totalAllocPoint = totalPoint;
    }


    function setRewardRate(uint256 _rate) public onlyOwner {
        require(_rate * 3600 * 24 < MAX_DAILY_REWARD_RATE, "invalid");
        massUpdatePools();
        curRewardRate = _rate;
    }

    function getRewardRate(uint256 _from, uint256 _to)
        public
        view
        returns (uint256) 
    {
        return curRewardRate * (_to - _from);
    }

    function pendingReward(uint256 _pid, address _user)
        external
        view
        returns (uint256)
    {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_user];
        uint256 accRewardPerShare = pool.accRewardPerShare;
        uint256 lpSupply = pool.balance;
        if (block.timestamp > pool.lastRewardTimestamp && lpSupply != 0) {
            uint256 rewardReward =
                getRewardRate(pool.lastRewardTimestamp, block.timestamp) * pool.allocPoint / totalAllocPoint;
            accRewardPerShare = accRewardPerShare + rewardReward * 1e12 / lpSupply;
        }
        return user.amount * accRewardPerShare / 1e12 - user.rewardDebt + user.pending;
    }

    function massUpdatePools() public {
        uint256 length = poolInfo.length;
        for (uint256 pid = 0; pid < length; ++pid) {
            updatePool(pid);
        }
    }

    function updatePool(uint256 _pid) public {
        PoolInfo storage pool = poolInfo[_pid];
        if (block.timestamp <= pool.lastRewardTimestamp) {
            return;
        }
        uint256 lpSupply = pool.balance;
        if (lpSupply == 0) {
            pool.lastRewardTimestamp = block.timestamp;
            return;
        }
        uint256 rewardReward =
                getRewardRate(pool.lastRewardTimestamp, block.timestamp) * pool.allocPoint / totalAllocPoint;
        
        pool.accRewardPerShare += rewardReward * 1e12 / lpSupply;
        pool.lastRewardTimestamp = block.timestamp;
    }

    function deposit(uint256 _pid, uint256 _amount, address _for) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_for];
        require(pool.lpToken == msg.sender, "deposit");
        updatePool(_pid);
        if (user.amount > 0) {
            uint256 pending = user.amount * pool.accRewardPerShare / 1e12 - user.rewardDebt;
            user.pending += pending;
        }
        
        pool.balance += _amount;
        user.amount += _amount;
        user.rewardDebt = user.amount * pool.accRewardPerShare / 1e12;
        
        emit Deposit(_for, _pid, _amount);
    }

    function withdraw(uint256 _pid, uint256 _amount, address _for) public {
        PoolInfo storage pool = poolInfo[_pid];
        UserInfo storage user = userInfo[_pid][_for];
        require(pool.lpToken == msg.sender, "withdraw");
        
        uint256 amount = _amount;
        if (amount > user.amount) {
            amount = user.amount;
        }

        updatePool(_pid);
        
        uint256 pending = user.amount * pool.accRewardPerShare / 1e12 - user.rewardDebt;
        user.pending += pending;

        user.amount -= amount;
        user.rewardDebt = user.amount * pool.accRewardPerShare / 1e12;

        pool.balance -= amount;
        emit Withdraw(_for, _pid, amount);
    }
    

}
