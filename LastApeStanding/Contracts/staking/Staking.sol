// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./Owner.sol";
import "./ReentrancyGuard.sol";
import "./SafeMath.sol";
import "./IBEP20.sol";

/**
###############################################################
###############################################################
##########     ################################################
##########      ###############################################
##########      ###############################################
##########.   #################################################
##########    ###################        ,#####################
##########  * #################,          .####################
##########  #,#################           #####################
##########   #################           ######################
##########  #################            ######################
##########          ,#######            ############.  ########
########            #### #      (       (#######(       #######
########       *#########   *#####      *#####          #######
########################   (#######     ###/        (##########
#######################   .#      #      #       ##############
######################   ####    ###   # #     ################
#####################  ##############   (##          (#########
####################*#################   #########.,   ########
####################################### ##########     ########
##################################################   ##########
############################################## (  # ###########
########################################,     *  ##############
###############################################################
###############################################################

Website: https://www.lastapestanding.com
Twitter: https://twitter.com/the_las_bsc

Staking Contract
*/

contract LastApeStandingStakes is Owner, ReentrancyGuard {
    using SafeMath for uint256;

    uint256 private constant MAX = ~uint256(0);
    uint256 private constant YEAR_SECONDS = 365 * 24 * 60 * 60;

    // Main token
    IBEP20 public mainToken;

    // Stakes history
    struct Record {
        // Date of initial staking
        uint256 from;
        // Amount of LAS tokens staked
        uint256 amount;
        // Gain recorded
        uint256 gain;
        // penalty recorded
        uint256 penalty;
        // End date of this particular staking
        uint256 to;
        // Boolean flag to signify that this staking record has ended
        bool ended;
    }

    // APR
    uint16 public interestRate;
    // Maturity date, any withdraws prior will be penalized
    uint256 public maturity;
    // Penalty in percentage form
    uint8 public penaltyPct;
    // The minimum amount eligible for staking
    uint256 public minStakingAmount;
    // The maximum amount eligible for staking
    uint256 public maxStakingAmount = 0;
    // The maximum amount of staking users (pool capacity)
    uint256 public maxStakingUsers = 0;
    bool stakingEnabled = false;

    uint256 public totalStaked = 0;
    uint256 public activeStakers = 0;

    mapping(address => Record[]) public ledger;
    mapping(address => uint256) public activeStakes;

    event StakeStart(address indexed user, uint256 value, uint256 index);
    event StakeEnd(
        address indexed user,
        uint256 value,
        uint256 penalty,
        uint256 interest,
        uint256 index
    );

    constructor(
        IBEP20 _token,
        address _owner,
        uint16 _rate,
        uint256 _maturity,
        uint8 _penaltyPct,
        uint256 _minStakingAmount,
        uint256 _maxStakingAmount,
        uint256 _maxStakingUsers
    ) Owner(_owner) {
        require(
            _penaltyPct <= 100,
            "Penalty has to be an integer between 0 and 100"
        );
        require(
            _maturity > block.timestamp,
            "Maturiy date needs to be set in the future"
        );
        mainToken = _token;
        interestRate = _rate;
        maturity = _maturity;
        penaltyPct = _penaltyPct;
        minStakingAmount = _minStakingAmount;
        maxStakingAmount = _maxStakingAmount;
        maxStakingUsers = _maxStakingUsers;

        mainToken.approve(address(this), MAX);
    }

    function stake(uint256 stakeAmount) external {
        require(stakingEnabled, "Staking is not yet enabled");
        require(block.timestamp <= maturity, "This staking pool has expired!");
        require(
            stakeAmount >= minStakingAmount,
            "Token amount needs to be higher than the lower limit"
        );
        require(
            stakeAmount <= maxStakingAmount,
            "Staking amount is geater than maximum allowed"
        );
        address staker = msg.sender;
        require(
            stakeAmount.add(activeStakes[staker]) <= maxStakingAmount,
            "Staking amount will increase your staked tokens beyond the maximum allowed"
        );
        if (activeStakes[staker] == 0) {
            require(
                activeStakers.add(1) <= maxStakingUsers,
                "This pool is at fully capacity"
            );
            activeStakers += 1;
        }
        mainToken.transferFrom(staker, address(this), stakeAmount);
        ledger[staker].push(
            Record(block.timestamp, stakeAmount, 0, 0, 0, false)
        );
        activeStakes[staker] += stakeAmount;
        totalStaked += stakeAmount;
        emit StakeStart(staker, stakeAmount, ledger[msg.sender].length - 1);
    }

    function unstake(uint256 recordIndex) external nonReentrant {
        address staker = msg.sender;
        require(recordIndex < ledger[staker].length, "Invalid record index");
        require(
            ledger[staker][recordIndex].ended == false,
            "Invalid stake; this staking record has ended"
        );
        require(
            block.timestamp >= maturity,
            "Pool has not reached maturity date yet"
        );
        // Check if the staker is ending prior to maturity date
        Record memory record = ledger[staker][recordIndex];

        // interest gained
        uint256 _interest = getGains(staker, recordIndex);
        // check that the owner can pay interest before trying to pay
        if (
            mainToken.allowance(getOwner(), address(this)) >= _interest &&
            mainToken.balanceOf(getOwner()) >= _interest
        ) {
            mainToken.transferFrom(getOwner(), staker, _interest);
        } else {
            _interest = 0;
        }
        mainToken.transfer(staker, record.amount);
        ledger[staker][recordIndex].gain = _interest;
        ledger[staker][recordIndex].to = block.timestamp;
        ledger[staker][recordIndex].ended = true;
        emit StakeEnd(staker, record.amount, 0, _interest, recordIndex);

        totalStaked -= record.amount;
        activeStakes[staker] -= record.amount;
        if (activeStakes[staker] == 0) {
            activeStakers -= 1;
        }
    }

    function emergencyWithdraw(uint256 recordIndex) external nonReentrant {
        address staker = msg.sender;
        require(recordIndex < ledger[staker].length, "Invalid index");
        require(
            ledger[staker][recordIndex].ended == false,
            "Invalid stake; this staking record has ended"
        );
        require(
            block.timestamp < maturity,
            "Pool has hit maturity date, please unstake normally."
        );
        Record memory record = ledger[staker][recordIndex];
        uint256 penalty = record.amount.mul(penaltyPct).div(100);
        if (penaltyPct == 0) {
            mainToken.transfer(staker, record.amount);
        } else if (penaltyPct == 100) {
            mainToken.transfer(getOwner(), penalty);
        } else {
            mainToken.transfer(staker, record.amount.sub(penalty));
            mainToken.transfer(getOwner(), penalty);
        }

        ledger[staker][recordIndex].penalty = penalty;
        ledger[staker][recordIndex].to = block.timestamp;
        ledger[staker][recordIndex].ended = true;
        emit StakeEnd(
            staker,
            ledger[msg.sender][recordIndex].amount,
            penalty,
            0,
            recordIndex
        );

        totalStaked -= record.amount;
        activeStakes[staker] -= record.amount;
        if (activeStakes[staker] == 0) {
            activeStakers -= 1;
        }
    }

    function maxPayout(uint256 timespan) public view returns (uint256) {
        return
            maxStakingAmount
                .mul(maxStakingUsers)
                .mul(interestRate)
                .mul(timespan)
                .div(100)
                .div(YEAR_SECONDS);
    }

    function enableStaking() external isOwner {
        require(!stakingEnabled, "Staking is already enabled!");
        require(
            block.timestamp < maturity,
            "This pool has already reached maturity date"
        );
        require(
            mainToken.allowance(msg.sender, address(this)) >
                maxPayout(maturity.sub(block.timestamp)),
            "Approve this contract for token transfers first"
        );
        stakingEnabled = true;
    }

    function disableStaking() external isOwner {
        require(stakingEnabled, "Staking is already disabled!");
        stakingEnabled = false;
    }

    function setFeatures(
        uint16 _rate,
        uint256 _maturity,
        uint8 _penaltyPct
    ) public isOwner {
        require(_penaltyPct <= 100, "Penalty can't be greater than 100%");
        interestRate = _rate;
        maturity = _maturity;
        penaltyPct = _penaltyPct;
    }

    function setMinStakingAmount(uint256 amount) public isOwner {
        minStakingAmount = amount;
    }

    function setMaxStakingAmount(uint256 amount) public isOwner {
        maxStakingAmount = amount;
    }

    function getGains(address staker, uint256 recordIndex)
        public
        view
        returns (uint256)
    {
        require(recordIndex < ledger[staker].length, "Invalid index");
        Record memory record = ledger[staker][recordIndex];
        if (record.ended) {
            return record.gain;
        }

        uint256 baseTime = block.timestamp > maturity
            ? maturity
            : block.timestamp;
        uint256 timeSinceStaked = baseTime.sub(record.from);
        return
            timeSinceStaked.mul(record.amount.mul(interestRate)).div(100).div(
                YEAR_SECONDS
            );
    }

    function getPendingGains() public view returns (uint256) {
        address staker = msg.sender;
        uint256 sum = 0;
        Record[] memory records = ledger[staker];
        for (uint256 i = 0; i < records.length; i++) {
            if (!records[i].ended) {
                sum += getGains(staker, i);
            }
        }
        return sum;
    }

    function getPastGains() public view returns (uint256) {
        address staker = msg.sender;
        uint256 sum = 0;
        Record[] memory records = ledger[staker];
        for (uint256 i = 0; i < records.length; i++) {
            if (records[i].ended) {
                sum += getGains(staker, i);
            }
        }
        return sum;
    }

    function getAllGains() public view returns (uint256) {
        address staker = msg.sender;
        uint256 sum = 0;
        Record[] memory records = ledger[staker];
        for (uint256 i = 0; i < records.length; i++) {
            sum += getGains(staker, i);
        }
        return sum;
    }

    function numberOfStakingRecords(address staker)
        public
        view
        returns (uint256)
    {
        return ledger[staker].length;
    }

    function getTotalStaked(address staker) public view returns (uint256) {
        return activeStakes[staker];
    }

    function hasExpired() public view returns (bool) {
        return block.timestamp >= maturity;
    }
}
