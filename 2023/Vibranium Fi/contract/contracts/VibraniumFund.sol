// SPDX-License-Identifier: GPL-3.0

pragma solidity 0.8.17;
/**
 * @title VibraniumFund is a derivative version of Synthetix StakingRewards.sol, distributing Protocol revenue to esVIB stakers.
 * Converting esVIB to VIB.
 * Differences from the original contract,
 * - Get `totalStaked` from totalSupply() in contract esVIB.
 * - Get `stakedOf(user)` from balanceOf(user) in contract esVIB.
 * - When an address esVIB balance changes, call the refreshReward method to update rewards to be claimed.
 */
 import "./Ownable.sol";
import "./ERC20.sol";
import "./IVibranium.sol";
import "./IesVIB.sol";
contract VibraniumFund is  Ownable {
    IVibranium public vibranium;
    IesVIB public esVIB;
    IesVIB public VIB;

    // Sum of (reward rate * dt * 1e18 / total supply)
    uint public rewardPerTokenStored;
    // User address => rewardPerTokenStored
    mapping(address => uint) public userRewardPerTokenPaid;
    // User address => rewards to be claimed
    mapping(address => uint) public rewards;
    mapping(address => uint) public time2fullRedemption;
    mapping(address => uint) public unstakeRate;
    mapping(address => uint) public lastWithdrawTime;
    uint256 immutable exitCycle = 30 days;
    uint256 public claimAbleTime;

    constructor(address _vibranium) {
        vibranium = IVibranium(_vibranium);
    }

    function setVibranium(address _vibranium) external onlyOwner {
        vibranium = IVibranium(_vibranium);
    }

    function setTokenAddress(address _esvib, address _vib) external onlyOwner {
        esVIB = IesVIB(_esvib);
        VIB = IesVIB(_vib);
    }

    function setClaimAbleTime(uint256 _time) external onlyOwner {
        claimAbleTime = _time;
    }

    // Total staked
    function totalStaked() internal view returns (uint256) {
        return esVIB.totalSupply();
    }

    // User address => esVIB balance
    function stakedOf(address staker) internal view returns (uint256) {
        return esVIB.balanceOf(staker);
    }

    function stake(uint256 amount) external updateReward(msg.sender) {
        VIB.burn(msg.sender, amount);
        esVIB.mint(msg.sender, amount);
    }

    function unstake(uint256 amount) external updateReward(msg.sender) {
        require(block.timestamp >= claimAbleTime, "It is not yet time to claim.");
        esVIB.burn(msg.sender, amount);
        withdraw(msg.sender);
        uint256 total = amount;
        if(time2fullRedemption[msg.sender] > block.timestamp) {
            total += unstakeRate[msg.sender] * (time2fullRedemption[msg.sender] - block.timestamp);
        }
        unstakeRate[msg.sender] = total / exitCycle;
        time2fullRedemption[msg.sender] = block.timestamp + exitCycle;
    }

    function withdraw(address user) public {
        uint256 amount = getClaimAbleVIB(user);
        if(amount > 0) {
            VIB.mint(user, amount);
        }
        lastWithdrawTime[user] = block.timestamp;
    }

    function reStake() external updateReward(msg.sender) {
        esVIB.mint(msg.sender, getReservedVIBForVesting(msg.sender) + getClaimAbleVIB(msg.sender));
        unstakeRate[msg.sender] = 0;
        time2fullRedemption[msg.sender] = 0;
    }

    function getClaimAbleVIB(address user) public view returns (uint256 amount) {
        if(time2fullRedemption[user] > lastWithdrawTime[user]) {
            amount = block.timestamp > time2fullRedemption[user] ? unstakeRate[user] * (time2fullRedemption[user] - lastWithdrawTime[user]) : unstakeRate[user] * (block.timestamp - lastWithdrawTime[user]);
        }
    }

    function getReservedVIBForVesting(address user) public  view returns (uint256 amount) {
        if(time2fullRedemption[user] > block.timestamp) {
            amount = unstakeRate[user] * (time2fullRedemption[user] - block.timestamp);
        }
    }

    function earned(address _account) public view returns (uint) {
        return
            ((stakedOf(_account) *
                (rewardPerTokenStored - userRewardPerTokenPaid[_account])) /
                1e18) + rewards[_account];
    }

    function getClaimAblvUSD(address user) external view returns (uint256 amount) {
        amount = vibranium.getMintedVUSDByShares(earned(user));
    }

    /**
     * @dev Call this function when deposit or withdraw ETH on Vibranium and update the status of corresponding user.
     */
    modifier updateReward(address account) {
        rewards[account] = earned(account);
        userRewardPerTokenPaid[account] = rewardPerTokenStored;
        _;
    }

    function refreshReward(address _account) external updateReward(_account) {}

    function getReward() external updateReward(msg.sender) {
        uint reward = rewards[msg.sender];
        if (reward > 0) {
            rewards[msg.sender] = 0;
            vibranium.transferShares(msg.sender, reward);
        }
    }

    /**
     * @dev The amount of VUSD acquiered from the sender is euitably distributed to VIB stakers.
     * Calculate share by amount, and calculate the shares could claim by per unit of staked ETH.
     * Add into rewardPerTokenStored.
     */
    function notifyRewardAmount(uint amount) external {
        require(msg.sender == address(vibranium));
        if (totalStaked() == 0) return;
        require(amount > 0, "amount = 0");
        uint256 share = vibranium.getSharesByMintedVUSD(amount);
        rewardPerTokenStored =
            rewardPerTokenStored +
            (share * 1e18) /
            totalStaked();
    }
}