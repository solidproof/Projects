pragma solidity ^0.8.0;

import '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
interface token is IERC20 {
    function mint(address recipient, uint256 _amount) external;
    function burn(address _from, uint256 _amount) external;
}

contract LPstaking is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    modifier onlyLPEngine() {
        require(lpEngines[msg.sender] || msg.sender == owner(), "You cant");
        _;
    }

    // Info of each user.
    struct UserInfo {
        uint256 totalReward;
        uint256 amount; // How many LP tokens the user has provided.
        uint256 rewardDebt; // Pending ETH rewards.
        uint256 rewardDebtToRealize; // Pending ETH rewards to be realized.
        uint256 rewardToBeRealized; // ETH rewards to be realized.
        uint256 toRealizedCycle;
        address referrer;
    }

    // Info of the stake.
    struct StakeInfo {
        uint256 lastRewardTime; // Last block time that ETHs distribution occurs.
        uint256 accETHPerShare; // Accumulated ETHs per share, times 1e12. See below.
        uint256 accETHPerShareToBeRealized; // Accumulated ETHs per share to be realized, times 1e12. See below.
        uint256 startRewardTime; // Block time when ETH rewards start for this stake.
    }

    // Dev address.
    address public devaddr;
    address public stakepool;

    uint256 public totalETHdistributed = 0;
    uint256 public lpBalance = 0;

    // Set a max ETH per second, which can never be higher than 1 per second.
    uint256 public constant maxETHPerSecond = 1e18;

    // Info of the stake.
    StakeInfo public stakeInfo;
    // Info of each user that stakes LP tokens.
    mapping(address => UserInfo) public userInfo;
    // The block time when ETH mining starts.
    address public immutable ZERO = 0x0000000000000000000000000000000000000000;
    // Global variables
    uint256 public currentCycle;
    uint256 public lastRewardUpdateTime;
    uint256 public referrerP = 50;
    mapping(address => uint256) public referrerTotalReward;
    mapping(address => uint256) public referrerWithdrawReward;

    mapping(uint256 => uint256) public cycleToRatio;
    mapping(address => bool) public lpEngines;

    event Deposit(address indexed user, uint256 amount, address referrer);
    event Withdraw(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);

    constructor(address lpEngine) {
        lpEngines[lpEngine] = true;
    }

    receive() payable external {
        uint256 rewardPerSecond =  msg.value.div(block.timestamp.sub(lastRewardUpdateTime));
        if(rewardPerSecond == 0)  rewardPerSecond = 1;
        updateStake(true,rewardPerSecond);
        lastRewardUpdateTime = block.timestamp;
        totalETHdistributed = totalETHdistributed.add(msg.value);
    } 

    // Return reward multiplier over the given _from to _to block.
    function getMultiplier(uint256 _from, uint256 _to) public view returns (uint256) {
        _from = _from >  stakeInfo.startRewardTime ? _from :  stakeInfo.startRewardTime;
        return _to - _from;
    }
    

    function getPendingRewardAndPendingToRealizeReward(address sender) public view returns (uint256, uint256) {
        uint256 newAccETHPerShareToBeRealized = stakeInfo.accETHPerShareToBeRealized
        .add(getMultiplier(stakeInfo.lastRewardTime, block.timestamp).mul(1e18).mul(1e12).div(lpBalance));

        uint256 pending = userInfo[sender].amount.mul(stakeInfo.accETHPerShare).div(1e12).sub(userInfo[sender].rewardDebt);

        if (cycleToRatio[userInfo[sender].toRealizedCycle] != 0)
        {
            uint256 ratio = cycleToRatio[userInfo[sender].toRealizedCycle];
            pending = pending.add(userInfo[sender].rewardToBeRealized.mul(ratio).div(1e18)).sub((userInfo[sender].rewardDebtToRealize).mul(ratio).div(1e18));
        }
        return (pending, userInfo[sender].amount.mul(newAccETHPerShareToBeRealized).div(1e12).sub(userInfo[sender].rewardDebtToRealize));

    }
    // Update reward variables of the stake to be up-to-date.
    function updateStake(bool _isSupplyingReward, uint256 reward) internal {
        if(reward == 0 && _isSupplyingReward)
        {
            return;
        }
        if (block.timestamp <= stakeInfo.lastRewardTime || block.timestamp < stakeInfo.startRewardTime) {
            return;
        }
        uint256 lpSupply = lpBalance;
        if(_isSupplyingReward && lpSupply == 0 )
        {
            stakeInfo.accETHPerShare = 0;
            stakeInfo.accETHPerShareToBeRealized = 0;
            cycleToRatio[currentCycle] = reward;
            currentCycle = currentCycle + 1;
        }
        if (lpSupply == 0) {
            stakeInfo.lastRewardTime = block.timestamp;
            return;
        }
        uint256 multiplier = getMultiplier(stakeInfo.lastRewardTime, block.timestamp);
        uint256 TokenedEarnedPlaceHolder = multiplier.mul(1e18);
        if(_isSupplyingReward)
        {
            stakeInfo.accETHPerShareToBeRealized = stakeInfo.accETHPerShareToBeRealized.add(TokenedEarnedPlaceHolder.mul(1e12).div(lpSupply));
            stakeInfo.accETHPerShare = stakeInfo.accETHPerShare.add(stakeInfo.accETHPerShareToBeRealized.mul(reward).div(1e18));
            stakeInfo.accETHPerShareToBeRealized = 0;
            cycleToRatio[currentCycle] = reward;
            currentCycle = currentCycle+1;
        }   
        else
        {
            stakeInfo.accETHPerShareToBeRealized = stakeInfo.accETHPerShareToBeRealized.add(TokenedEarnedPlaceHolder.mul(1e12).div(lpSupply));
        } 

        stakeInfo.lastRewardTime = block.timestamp;
    }

    function userPreUpdate(uint256 amount, bool isAdding, address sender, address referrer) internal
    {
        UserInfo storage user = userInfo[sender];
        updateStake(false,0); // Set isSupplyingReward to false

        uint256 pending = user.amount.mul(stakeInfo.accETHPerShare).div(1e12).sub(user.rewardDebt);

        if (cycleToRatio[user.toRealizedCycle] != 0)
        {
            uint256 ratio = cycleToRatio[user.toRealizedCycle];
            pending = pending.add(user.rewardToBeRealized.mul(ratio).div(1e18)).sub((user.rewardDebtToRealize).mul(ratio).div(1e18));
            user.rewardToBeRealized = 0;
            user.rewardDebtToRealize = 0;
        }
        uint256 pendingToRealize = user.amount.mul(stakeInfo.accETHPerShareToBeRealized).div(1e12).sub(user.rewardDebtToRealize);
        
        if(isAdding)
        {
            user.amount = user.amount.add(amount);
        }
        else
        {
            user.amount = user.amount.sub(amount);
        }

        user.rewardDebt = user.amount.mul(stakeInfo.accETHPerShare).div(1e12);
        user.rewardDebtToRealize = user.amount.mul(stakeInfo.accETHPerShareToBeRealized).div(1e12);

        
        user.rewardToBeRealized = user.rewardToBeRealized.add(pendingToRealize);
        user.toRealizedCycle = currentCycle; // Update toRealizedCycle
        if (pending > 0 && user.referrer != ZERO) {
            sendEth(sender, pending*(10000-referrerP)/10000);
            user.totalReward = user.totalReward + pending*(10000-referrerP)/10000;
            referrerTotalReward[user.referrer] = referrerTotalReward[user.referrer]  + pending*(referrerP)/10000;
            user.referrer = ZERO;
        }
        else if (pending > 0) {
            sendEth(sender, pending);
            user.totalReward = user.totalReward + pending;
        }

        if(isAdding)
        {
            lpBalance = lpBalance + amount;
        }
        else
        {
            lpBalance = lpBalance - amount;
        }

        if(referrer != ZERO)
        {
            user.referrer = referrer;
        }

    }
    // Deposit LP tokens to the stake for ETH allocation.
    function deposit(uint256 _amount, address sender, address _referrer) public  onlyLPEngine nonReentrant {
        userPreUpdate( _amount, true, sender, _referrer);
        emit Deposit(sender, _amount, _referrer);
    }

    function referrerWithdraw(uint256 _amount) public
    {
        require(referrerTotalReward[msg.sender] - referrerWithdrawReward[msg.sender] >= _amount, "You withdrawed more than ur balance");
        referrerWithdrawReward[msg.sender] = referrerWithdrawReward[msg.sender] + _amount; 
        sendEth(msg.sender, _amount);
    }

    // Withdraw LP tokens from the stake.
    function withdraw(uint256 _amount, address sender) public onlyLPEngine nonReentrant {
        userPreUpdate(_amount, false, sender, ZERO);
        emit Withdraw(sender, _amount);
    }

    function updateStakePool(address _pool) external onlyOwner {
        stakepool = _pool;
    }

    function updateReferrer(uint256 shareAmount) external onlyOwner {
        referrerP = shareAmount;
    }

    function updatelpEngines(address a, bool b) external onlyOwner {
        lpEngines[a] = b;
    }

    function sendEth(address _address, uint256 _value) internal {
        (bool success, ) = _address.call{value: _value}("");
        require(success, "ETH Transfer failed.");
    }

    function recoverEth() external onlyOwner {
        payable(msg.sender).transfer(address(this).balance);
    }

    function recoverTokens(address tokenAddress) external onlyOwner {
        IERC20 token = IERC20(tokenAddress);
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }
}