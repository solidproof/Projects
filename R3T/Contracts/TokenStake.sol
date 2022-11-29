// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./Ownable.sol";
import "./IERC20.sol";
import "./ReentrancyGuard.sol";
import "./Pausable.sol";

// Inheritance
import "./ITokenStake.sol";

contract TokenStake is Ownable, ReentrancyGuard, Pausable, ITokenStake {
    /* ========== STATE VARIABLES ========== */
    mapping(address => uint256[]) private stakingBalances;
    mapping(address => uint256[]) private startStakingTimes;
    mapping(address => uint256[]) private exitTimes;
    mapping(address => uint256[][]) private rewards;
    mapping(address => uint256) private totalStakedTokens;
    mapping(address => uint256) private totalEarnedTokens;

    address[] private stakers;

    IERC20 private rewardToken;
    IERC20 private stakedToken;

    uint256 private rewardRateOnePart;
    uint256 private atLeastStakingDuration;
    uint8 private amountPartsOfOneDuration;

    uint256 private totalContractSupply;
    uint256 private totalStakingBalance;
    uint256 private totalRewards;

    /* ========== STRUCT ========== */
    struct StakingSession {
        uint256 order;
        uint256 balance;
        uint256 reward;
        uint256 startStakingTime;
        uint256 requiredDuration;
        uint256 exitTime;
        uint8 currentPart;
        uint256 remainReward;
        bool isClosed;
    }

    struct StakerData {
        uint256 balance;
        address account;
        uint256 totalStakedTokens;
        uint256 totalEarnedTokens;
    }

    /* ========== CONSTRUCTOR ========== */
    constructor(
        address _rewardToken,
        address _stakedToken,
        uint256 _rewardRateOnePart,
        uint256 _atLeastStakingDuration,
        uint8 _amountPartsOfOneDuration
    ) {
        rewardToken = IERC20(_rewardToken);
        stakedToken = IERC20(_stakedToken);
        rewardRateOnePart = _rewardRateOnePart;
        atLeastStakingDuration = _atLeastStakingDuration;
        amountPartsOfOneDuration = _amountPartsOfOneDuration;
    }

    /* ========== VIEWS ========== */
    function totalSupply() external view override returns (uint256) {
        return totalContractSupply;
    }

    function getAllStakesrWithStakingBalance()
        external
        view
        returns (StakerData[] memory)
    {
        uint256 totalStakers = stakers.length;

        StakerData[] memory data = new StakerData[](totalStakers);

        for (uint256 index = 0; index < totalStakers; index++) {
            address stakerAddress = stakers[index];

            uint256 totalBalance = 0;

            for (
                uint256 x = 0;
                x < stakingBalances[stakerAddress].length;
                x++
            ) {
                totalBalance = totalBalance + stakingBalances[stakerAddress][x];
            }

            StakerData memory eachStaker = StakerData(
                totalBalance,
                stakerAddress,
                totalStakedTokens[stakerAddress],
                totalEarnedTokens[stakerAddress]
            );

            data[index] = eachStaker;
        }

        return data;
    }

    function getTotalStakingBalance() external view returns (uint256) {
        return totalStakingBalance;
    }

    function getTotalRewards() external view returns (uint256) {
        return totalRewards;
    }

    function getTotalContractSupply() external view returns (uint256) {
        return totalContractSupply;
    }

    function getStakingHistory(address _account)
        external
        view
        returns (StakingSession[] memory)
    {
        uint256 amountOfSession = stakingBalances[_account].length;
        StakingSession[] memory history = new StakingSession[](amountOfSession);

        for (uint256 index = 0; index < amountOfSession; index++) {
            bool isClosed = false;

            uint256 exitTime = 0;

            if (exitTimes[_account].length >= index + 1)
                exitTime = exitTimes[_account][index];

            if (stakingBalances[_account][index] == 0) isClosed = true;

            uint8 currentPart = getCurrentRewardPart(_account, index) + 1;

            uint256 remainReward = 0;
            uint256 totalReward = 0;
            for (uint256 x = 0; x < rewards[_account][index].length; x++) {
                if (x <= currentPart)
                    remainReward = remainReward + rewards[_account][index][x];

                totalReward = totalReward + rewards[_account][index][x];
            }

            StakingSession memory session = StakingSession(
                index,
                stakingBalances[_account][index],
                totalReward,
                startStakingTimes[_account][index],
                atLeastStakingDuration,
                exitTime,
                currentPart,
                remainReward,
                isClosed
            );
            history[index] = session;
        }
        return history;
    }

    function balanceOf(address _account)
        external
        view
        override
        returns (uint256[] memory)
    {
        return stakingBalances[_account];
    }

    function isStaking(address _account) external view override returns (bool) {
        uint256[] memory balances = stakingBalances[_account];

        for (uint256 index = 0; index < balances.length; index++) {
            if (balances[index] > 0) return true;
        }

        return false;
    }

    function getRemainStakingDuration(address _account, uint256 stakingOrder)
        public
        view
        override
        returns (uint256)
    {
        if (startStakingTimes[_account][stakingOrder] == 0) return 0;

        uint256 stakingDuration = block.timestamp -
            startStakingTimes[_account][stakingOrder];

        if (stakingDuration > atLeastStakingDuration)
            return atLeastStakingDuration;
        else return stakingDuration;
    }

    function getCurrentRewardPart(address _account, uint256 stakingOrder)
        public
        view
        returns (uint8)
    {
        require(
            startStakingTimes[_account][stakingOrder] > 0,
            "The staking section is over"
        );

        uint256 stakingDuration = block.timestamp -
            startStakingTimes[_account][stakingOrder];

        for (uint8 index = 1; index <= amountPartsOfOneDuration; index++) {
            if (
                stakingDuration <
                (atLeastStakingDuration / amountPartsOfOneDuration) * index
            ) return index - 1;
        }

        return amountPartsOfOneDuration - 1;
    }

    function totalEarnOnePart(address _account, uint256 stakingOrder)
        public
        view
        override
        returns (uint256)
    {
        uint256[] memory balances = stakingBalances[_account];
        for (uint256 index = 0; index < balances.length; index++) {
            if (index == stakingOrder) {
                return uint256(((balances[index] * rewardRateOnePart) / 1000));
            }
        }
        return 0;
    }

    function getTotalStakedTokens(address _account)
        public
        view
        returns (uint256)
    {
        return totalStakedTokens[_account];
    }

    function getExitTimes(address _account)
        public
        view
        returns (uint256[] memory)
    {
        return exitTimes[_account];
    }

    function getTotalEarnedTokens(address _account)
        public
        view
        returns (uint256)
    {
        return totalEarnedTokens[_account];
    }

    /* ========== MUTATIVE FUNCTIONS ========== */
    function stake(uint256 _amount) public override nonReentrant whenNotPaused {
        require(_amount > 0, "Amount must be more than 0");
        totalContractSupply = totalContractSupply + _amount;
        totalStakingBalance = totalStakingBalance + _amount;
        createNewStakingSession(_amount);
        stakedToken.transferFrom(msg.sender, address(this), _amount);

        emit Staked(msg.sender, _amount, block.timestamp);
    }

    function getReward(uint256 stakingOrder)
        public
        override
        nonReentrant
        whenNotPaused
    {
        uint8 whichRewardPart = getCurrentRewardPart(msg.sender, stakingOrder);

        require(
            whichRewardPart > 0,
            "Must wait for enough required time duration"
        );

        uint256 reward = 0;

        for (uint256 index = 0; index <= whichRewardPart; index++) {
            reward = reward + rewards[msg.sender][stakingOrder][index];
            rewards[msg.sender][stakingOrder][index] = 0;
        }

        require(reward > 0, "Insufficient reward");
        require(reward <= totalContractSupply, "Insufficient contract balance");

        totalContractSupply = totalContractSupply - reward;
        totalEarnedTokens[msg.sender] = totalEarnedTokens[msg.sender] + reward;

        rewardToken.transfer(msg.sender, reward);

        // Withdraw all balance of session
        if (whichRewardPart == amountPartsOfOneDuration - 1) {
            exitTimes[msg.sender].push(block.timestamp);
            withdraw(stakingBalances[msg.sender][stakingOrder], stakingOrder);
        }

        emit RewardPaid(
            msg.sender,
            reward,
            stakingOrder,
            atLeastStakingDuration,
            block.timestamp,
            amountPartsOfOneDuration,
            whichRewardPart + 1,
            startStakingTimes[msg.sender][stakingOrder],
            block.timestamp
        );
    }

    function exit(uint256 stakingOrder) external override whenNotPaused {
        getReward(stakingOrder);
    }

    /* ========== OWNER FUNCTIONS ========== */
    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function fundContractBalance(uint256 _amount) external onlyOwner {
        require(_amount > 0, "Invalid fund");

        totalContractSupply = totalContractSupply + _amount;
        rewardToken.transferFrom(msg.sender, address(this), _amount);
    }

    function checkRemainContractBalance()
        external
        view
        onlyOwner
        returns (uint256)
    {
        uint256 remain = totalContractSupply -
            (totalRewards + totalStakingBalance);

        return remain;
    }

    /* ========== INTERNAL FUNCTIONS ========== */
    function createNewStakingSession(uint256 _amount) internal {
        stakingBalances[msg.sender].push(_amount);
        startStakingTimes[msg.sender].push(block.timestamp);
        totalStakedTokens[msg.sender] = totalStakedTokens[msg.sender] + _amount;

        bool existingStaker = checkExistingStaker(msg.sender);

        if (!existingStaker) stakers.push(msg.sender);

        updateReward(msg.sender, stakingBalances[msg.sender].length - 1, true);
    }

    function checkExistingStaker(address _account)
        internal
        view
        returns (bool)
    {
        for (uint256 index = 0; index < stakers.length; index++) {
            if (stakers[index] == _account) return true;
        }

        return false;
    }

    function withdraw(uint256 _amount, uint256 stakingOrder) internal {
        require(_amount > 0, "Cannot withdraw 0");

        uint8 whichRewardPart = getCurrentRewardPart(msg.sender, stakingOrder);

        require(
            whichRewardPart > 0,
            "Must wait for enough required time duration"
        );

        uint256 accountBalance = stakingBalances[msg.sender][stakingOrder];

        require(_amount <= accountBalance, "Insufficient balance");

        totalContractSupply = totalContractSupply - _amount;
        totalStakingBalance = totalStakingBalance - _amount;
        stakingBalances[msg.sender][stakingOrder] = accountBalance - _amount;

        stakedToken.transfer(msg.sender, _amount);
    }

    function updateReward(
        address _account,
        uint256 stakingOrder,
        bool newSession
    ) internal {
        if (_account != address(0)) {
            uint256 rewardEachRate = totalEarnOnePart(_account, stakingOrder);

            if (newSession) {
                uint256[] memory rewardEachRates = new uint256[](
                    amountPartsOfOneDuration
                );

                for (uint256 x = 0; x < amountPartsOfOneDuration; x++) {
                    rewardEachRates[x] = rewardEachRate;
                    totalRewards = totalRewards + rewardEachRate;
                }

                rewards[_account].push(rewardEachRates);
            }
        }
    }

    /* ========== EVENTS ========== */

    event Staked(address indexed user, uint256 amount, uint256 blockTime);
    event WithdrawImmediately(address indexed user, uint256 amount);
    event RewardRate(uint256 rate);
    event RewardPaid(
        address indexed user,
        uint256 reward,
        uint256 order,
        uint256 requiredDuration,
        uint256 exitTime,
        uint256 defaultPartsOfOneDuration,
        uint256 currentPart,
        uint256 startTime,
        uint256 blockTime
    );
    event AtLeastStakingDuration(uint256 newDuration);
}