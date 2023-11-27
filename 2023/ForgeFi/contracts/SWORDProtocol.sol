//SPDX-License-Identifier: MIT
//9ecc02a53f8032a599c51cbc7f7c474835c40cb0e92543f7995708cce9e06df9
pragma solidity ^0.8.0;

interface IERC20 {
    
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);


    function transfer(address recipient, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    function getLockedEther() external returns (uint256);

    function replenishProtocol() external;

    
    event Transfer(address indexed from, address indexed to, uint256 value);

    
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

contract SWORDProtocol {

    using SafeMath for uint256;

    struct Position {
        uint256 amount;
        uint256 daily;
        uint256 lockupDays;
        uint256 lockupTime;
        uint256 checkpoint;
        bool isActive;
    }

    struct Partner {
        uint256 referrals;
        uint256 claimableRewards;
        uint256 withdrawnRewards;
        address referrer;
    }

    struct User {
        Position[] positions;
        Partner partners;
        uint256 checkpoint;
        uint256 withdrawnRewards;
    }

    modifier replenishStaking() {
        _;
        token.replenishProtocol();
    }


    uint256 constant public PERCENTS_DIVIDER = 100_000;
    uint256 constant public TIME_STEP = 24 hours;

    uint256 constant public MARKETING_FEE = 4_000; //4%
    uint256 constant public DEV_FEE = 1_000; // 1%

    uint256 constant public MIN_DAYS_LOCKUP = 7;
    uint256 constant public MAX_DAYS_LOCKUP = 50;
    
    uint256 constant public TVL_BONUS_STEP = 10 ether;

    uint256 public totalStaked;
    uint256 public totalPositions;

    IERC20 public token;

    address private marketingFund;
    address private dev; 

    mapping(address => User) public users;

    event onStake(address indexed addr, uint256 amount);
    event onClaim(address indexed addr, uint256 amount);
    event onClaimRef(address indexed addr, uint256 amount);
    event onUnstake(address indexed addr, uint256 amount);



    constructor(address marketingAddr, address devAddr) {
        require(!isContract(marketingAddr));
        require(!isContract(devAddr));

        marketingFund = marketingAddr;
        dev = devAddr;
    }

    function stake(address referrer, uint256 amount, uint256 _days) public replenishStaking {
        require(msg.sender == tx.origin, "not allowed");
        require(amount > 0, "wrong amount");
        require(_days >= 7 && _days <= 50, "wrong lockup period");
        require(address(token) != address(0), "protocol hast`t launched yet");

        User storage user = users[msg.sender];

        token.transferFrom(msg.sender, address(this),amount);

        payFee(amount);
        recordReferral(referrer, msg.sender);
        payRefFee(msg.sender,amount);

        if(user.positions.length == 0) {
            user.checkpoint = block.timestamp;
        }

        (uint256 _dailyPercent, uint256 _lockupTime) = getPositionData(_days);

        user.positions.push(Position(amount,_dailyPercent,_days,_lockupTime,block.timestamp, true));

        totalStaked = totalStaked.add(amount);
        totalPositions = totalPositions.add(1);
        

        emit onStake(msg.sender, amount);
    }

    function claim() public replenishStaking{
        uint256 rewards = getPendingRewards(msg.sender);

        require(rewards > 0, "nothing to claim");

        users[msg.sender].checkpoint = block.timestamp;
        users[msg.sender].withdrawnRewards = users[msg.sender].withdrawnRewards.add(rewards);

        token.transfer(msg.sender,rewards);

        emit onClaim(msg.sender, rewards);
    }

    function claimRef() public replenishStaking {
        uint256 rewards = users[msg.sender].partners.claimableRewards;

        require(rewards > 0, "nothing to claim");

        users[msg.sender].partners.claimableRewards = 0;
        users[msg.sender].partners.withdrawnRewards = users[msg.sender].partners.withdrawnRewards.add(rewards);

        token.transfer(msg.sender, rewards);

        emit onClaimRef(msg.sender,rewards);
    }

    function unstake(uint256 index) public replenishStaking {
        uint256 positionsNum = users[msg.sender].positions.length;

        require(index < positionsNum, "wrong index");
        require(users[msg.sender].positions[index].isActive, "position is not active");
        require(getUnlockTimer(msg.sender,index) == 0, "position is locked");

        uint256 amount = users[msg.sender].positions[index].amount;

        users[msg.sender].positions[index].isActive = false;

        token.transfer(msg.sender,amount);

        emit onUnstake(msg.sender,amount);
    }



    function launchProtocol(IERC20 _token) public {
        require(msg.sender == dev, "not allowed");
        require(address(token) == address(0), "can be updated only once");

        token = _token;
    }

     function payFee(uint256 amount) internal {

        uint256 marketingFee = amount.mul(MARKETING_FEE).div(PERCENTS_DIVIDER);
        uint256 devFee = amount.mul(DEV_FEE).div(PERCENTS_DIVIDER);

        token.transfer(marketingFund,marketingFee);
        token.transfer(dev,devFee);

    }

    function recordReferral(address referrer, address sender) internal {

        if(users[sender].partners.referrer == address(0)) {
            
            if(referrer != address(0) && sender != referrer && users[referrer].positions.length != 0) {
                users[sender].partners.referrer = referrer;
            } 

            address upline = users[sender].partners.referrer;


            for(uint8 i = 0; i < 4; i++) {
                    if(upline != address(0)) {
                        users[upline].partners.referrals = users[upline].partners.referrals.add(1);
                        upline = users[upline].partners.referrer;
                    } else break;
            }
        }
    }

    function payRefFee(address sender, uint256 value) internal {

        if (users[sender].partners.referrer != address(0)) {

			address upline = users[sender].partners.referrer;

			for (uint8 i = 0; i < 4; i++) {  
				if (upline != address(0)) {
				
    				uint256 amount = value.mul(getRefRewards(i)).div(PERCENTS_DIVIDER);
    					
    				users[upline].partners.claimableRewards = users[upline].partners.claimableRewards.add(amount); 
				    
					
					upline = users[upline].partners.referrer;
				} else break;
			}

		}
    }

    function getPositionData(uint256 _days) public returns(uint256 _dailyPercent, uint256 _lockupTime) {
        uint256 baseDailyPercent = getDailyPercent(_days);
        uint256 tvlBonusPercent = getTvlBonus();
        _dailyPercent = baseDailyPercent.add(tvlBonusPercent);
        _lockupTime = block.timestamp.add(_days.mul(24 hours));
    }

    function getUnlockTimer(address addr, uint256 index) public view returns(uint256) {
        return block.timestamp >= users[addr].positions[index].lockupTime ? 0 : users[addr].positions[index].lockupTime.sub(block.timestamp);
    }

   
    function getPendingRewards(address addr) public view returns(uint256) {

        User storage user = users[addr];

        uint256 pendingRewards = 0;

        uint256 holdBonus = getHoldBonus(addr);

        for(uint256 i = 0; i < user.positions.length; i++) {

            

            if(user.positions[i].isActive) {
                
                uint256 share = user.positions[i].amount.mul(user.positions[i].daily.add(holdBonus)).div(PERCENTS_DIVIDER);

                uint256 from = user.positions[i].checkpoint > user.checkpoint ? user.positions[i].checkpoint: user.checkpoint;
                uint256 to = block.timestamp;

                uint256 rewards = share.mul(to.sub(from)).div(TIME_STEP);

                pendingRewards = pendingRewards.add(rewards);


            }

        }

        return pendingRewards;

    }


    function getTvlBonus() public returns(uint256 bonus) {
        uint256 lockedEther = token.getLockedEther();

        bonus = lockedEther.div(TVL_BONUS_STEP).mul(10); // +0.01% each 10 ether 

    }

    function getHoldBonus(address addr) public view returns(uint256 holdBonus) {
        uint256 userCheckpoint = users[addr].checkpoint;

        holdBonus = block.timestamp.sub(userCheckpoint).div(TIME_STEP).mul(50); //+0.05% each day
    }

    function getDailyPercent(uint256 _days) internal pure returns(uint256 _percent) {
        _percent = [500,525,551,579,608,638,670,704,739,776,814,855,898,943,990,1039,1091,1146,1203,1263,1327,1393,1463,1536,1613,1693,1778,1867,1960,2058,2161,2269,2382,2502,2627,2758,2896,3041,3193,3352,3520,3696,3881,4075][_days.sub(7)];
    }

    function getRefRewards(uint256 level) internal pure returns(uint256 _percent) {
        return [4000, 3000, 2000, 1000][level];
    }

    function getContractStats() external view returns(uint256 staked, uint256 positions) {
        staked = totalStaked;
        positions = totalPositions;
    }


    function getUserData(address addr) external view returns(Position[] memory _positions, Partner memory _partners, uint256 _withdrawn) {
        _positions = users[addr].positions;
        _partners = users[addr].partners;
        _withdrawn = users[addr].withdrawnRewards;
    }

    function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }

}

library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;

        return c;
    }
    
     function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b != 0);
        return a % b;
    }
}