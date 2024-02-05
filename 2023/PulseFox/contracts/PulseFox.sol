// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

contract PulseFox {
    using SafeMath for uint256;

    bool private locked;

    /** base parameters **/
    uint256 public EGGS_TO_HIRE_1MINERS = 1080000; // 8% 
    uint256 public REFERRAL = 80;  // 8%
    bool private contractStarted;                
    uint256 public PERCENTS_DIVIDER = 1000;    
    uint256 public FEE = 5;                        // 0.5%
    uint256 public MARKET_EGGS_DIVISOR = 20;

	bool public LOTTERY_ACTIVATED;
    bool public TOP_DEPOSIT_ACTIVATED;
    bool public started;
    uint256 public LOTTERY_START_TIME;
    uint256 public TOP_DEPOSIT_START_TIME;
    uint256 public TOP_DEPOSIT_PERCENT = 10;
    uint256 public LOTTERY_PERCENT = 10;
    uint256 public LOTTERY_STEP = 86400; // 24 hrs
    uint256 public TOP_DEPOSIT_STEP = 86400; // 24 hrs
    uint256 public LOTTERY_TICKET_PRICE = 100000 ether; // 100,000 PLS
    uint256 public MAX_LOTTERY_TICKET = 20;
    uint256 public MAX_LOTTERY_PARTICIPANTS = 100;
    uint256 public MAX_LOTTERY_POOL_PER_ROUND = 4000000 ether; /**  4,000,000 PLS **/
    uint256 public lotteryRound = 0; //round will be same as index
    uint256 public currentPot = 0;
    uint256 public participants = 0;
    uint256 public totalTickets = 0;

    /* statistics */
    uint256 public totalStaked;
    uint256 public totalDeposits;
    uint256 public totalCompound;
    uint256 public totalRefBonus;
    uint256 public totalWithdrawn;
    uint256 public totalLotteryMinerBonus;
    uint256 public totalTopDepositMinerBonus;

    /* miner parameters */
    uint256 public marketEggs = 108000000000;
    uint256 PSN = 10000;
    uint256 PSNH = 5000;

    /** whale control features **/
	uint256 public CUTOFF_STEP = 172800; /** 48 hours  **/
    uint256 public MIN_INVEST = 100000 ether;  /** 100,000 PLS  **/
	uint256 public ACTION_COOLDOWN = 172800; /** 48 hours  **/    
    uint256 public WALLET_DEPOSIT_LIMIT = 100000000 ether; /** 100,000,000 PLS  **/

    /* biggest deposit per day. */
    uint8[] public pool_bonuses;
    uint256 public pool_cycle = 1;
    uint256 public pool_balance;
    uint256 public max_pool_balance = 8000000 ether; /**  8,000,000 PLS **/

    /* addresses */
    address private owner;
    address payable private admin;
    address payable private marketing;    
    

    struct User {
        uint256 initialDeposit;
        uint256 userDeposit;
        uint256 miners;
        uint256 claimedEggs;
        uint256 lottery_bonus_as_miners;
        uint256 lastHatch;
        address referrer;
        uint256 referralsCount;
        uint256 referralEggRewards;
        uint256 referralMinerRewards;
        uint256 totalWithdrawn;
        uint256 pool_bonus_as_miners;
    }

    struct LotteryHistory {
        uint256 round;
        address winnerAddress;
        uint256 pot;
        uint256 miners;
        uint256 totalLotteryParticipants;
        uint256 totalLotteryTickets;
    }

    LotteryHistory[] internal lotteryHistory;

    mapping(address => uint256) private buyCount;
    mapping(uint8 => address) public pool_top; 
    mapping(address => User) public users;
    mapping(uint256 => mapping(address => uint256)) public ticketOwners; /** round => address => amount of owned points **/
    mapping(uint256 => mapping(uint256 => address)) public participantAdresses; /** round => id => address **/
    mapping(uint256 => mapping(address => uint256)) public pool_users_deposits_sum; 
    event LotteryWinner(address indexed investor, uint256 pot, uint256 miner, uint256 indexed round);
    event PoolPayout(address indexed addr, uint256 amount);
    event eggsBoughtEvent(address indexed _from, uint _value, uint _contractBalance, uint _minersBought);

    constructor(address payable _admin, address payable _marketing) {
		require(!isContract(_admin) && !isContract(_marketing));
        owner = msg.sender;
        admin = _admin;
        marketing = _marketing;

        pool_bonuses.push(30);
        pool_bonuses.push(25);
        pool_bonuses.push(20);
        pool_bonuses.push(15);
        pool_bonuses.push(10);
    }

	function isContract(address addr) internal view returns (bool) {
        uint size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }

    modifier nonReentrant {
        require(!locked, "No re-entrancy.");
        locked = true;
        _;
        locked = false;
    }

    function activateLaunch() external {
        require(msg.sender == owner);
	    contractStarted = true;
	    TOP_DEPOSIT_ACTIVATED = true;
        LOTTERY_ACTIVATED = true;
	    TOP_DEPOSIT_START_TIME = block.timestamp;
        LOTTERY_START_TIME = block.timestamp;
    }

    //will need to be triggered if no user action triggered the events.
    function runEvents() external {
        if (LOTTERY_ACTIVATED) {
            if(getTimeStamp().sub(LOTTERY_START_TIME) >= LOTTERY_STEP || participants >= MAX_LOTTERY_PARTICIPANTS || currentPot >= MAX_LOTTERY_POOL_PER_ROUND){
                chooseWinner();
            }
		}

        if (TOP_DEPOSIT_ACTIVATED) {
            if(getTimeStamp().sub(TOP_DEPOSIT_START_TIME) >=  TOP_DEPOSIT_STEP) {
                _drawPool();
            }
		}    
    }
    
    //set referral boost to true before changing the value
    function SET_REF_PERCENTAGE(uint256 value) external {
        require(msg.sender == owner, "Admin use only.");
        require(value >= 50 && value <= 120); /** between 5% max 12%**/
        REFERRAL = value;
    }

  
 
    function buyEggs(address ref) public payable nonReentrant {

            if (!started) {
			    if (msg.sender == admin) {
				    started = true;
			    } else revert("Not started yet");
		    }
            User storage user = users[msg.sender]; 
  
   
            require(msg.value >= MIN_INVEST, "Mininum investment not met.");
            require(user.initialDeposit.add(msg.value) <= WALLET_DEPOSIT_LIMIT, "Max deposit limit reached.");
            

            if(user.initialDeposit < 1){ //new user! add count for new deposits only for precise record of data.
                totalDeposits++; 
            }
            else{ //existing user - add the current yield to the total compound before adding new deposits for precise record of data.
                uint256 currEggsValue = calculateEggSell(getEggsSinceLastHatch(msg.sender));
                user.userDeposit = user.userDeposit.add(currEggsValue);
                totalCompound = totalCompound.add(currEggsValue);
            }
            
            uint256 eggsBought = calculateEggBuy(msg.value, getBalance().sub(msg.value));
            user.userDeposit = user.userDeposit.add(msg.value);
            user.initialDeposit = user.initialDeposit.add(msg.value);
            user.claimedEggs = user.claimedEggs.add(eggsBought);
        emit eggsBoughtEvent(msg.sender, msg.value, address(this).balance, SafeMath.div(eggsBought,EGGS_TO_HIRE_1MINERS));

            if (LOTTERY_ACTIVATED) {
                if(getTimeStamp().sub(LOTTERY_START_TIME) >= LOTTERY_STEP || participants >= MAX_LOTTERY_PARTICIPANTS || currentPot >= MAX_LOTTERY_POOL_PER_ROUND) {
                    chooseWinner();
                }
                _buyTickets(msg.sender, msg.value);
            }

            if (TOP_DEPOSIT_ACTIVATED) {
                if(getTimeStamp().sub(TOP_DEPOSIT_START_TIME) >=  TOP_DEPOSIT_STEP) {
                    _drawPool();
                }
                _topDeposits(msg.sender, msg.value);
            }
            
                if (user.referrer == address(0)) {
                    if (ref != msg.sender) {
                        user.referrer = ref;
                    }

                    address upline1 = user.referrer;
                    if (upline1 != address(0)) {
                        users[upline1].referralsCount = users[upline1].referralsCount.add(1);
                    }
                }
                        
                if (user.referrer != address(0)) {
                    address upline = user.referrer;
                    if (upline != address(0) && users[upline].miners > 0) {
                        uint256 refRewards = msg.value.mul(REFERRAL).div(PERCENTS_DIVIDER);
                        uint256 eggsReward = calculateEggBuy(refRewards, getBalance().sub(refRewards));
                        uint256 minerRewards = eggsReward.div(EGGS_TO_HIRE_1MINERS);
                        users[upline].miners = users[upline].miners.add(minerRewards);
                        marketEggs = marketEggs.add(eggsReward.div(MARKET_EGGS_DIVISOR)); //fix inflation
                        users[upline].referralMinerRewards = users[upline].referralMinerRewards.add(minerRewards); //miner amount.
                        users[upline].referralEggRewards = users[upline].referralEggRewards.add(refRewards); //ether amount.
                        totalRefBonus = totalRefBonus.add(refRewards); //ether amount.
                    }
                }
            

            uint256 eggsPayout = payFees(msg.value);
            totalStaked = totalStaked.add(msg.value.sub(eggsPayout));
            hatchEggs(false);
        // }

    }

    function hatchEggs(bool isCompound) public {
        User storage user = users[msg.sender];
        require(contractStarted || msg.sender == admin);

        uint256 eggsUsed = getMyEggs();
        uint256 eggsForCompound = eggsUsed;
        if(isCompound) {
            if(user.lastHatch.add(ACTION_COOLDOWN) > block.timestamp) revert("Can only compound after action cooldown.");
            uint256 eggsUsedValue = calculateEggSell(eggsForCompound);
            user.userDeposit = user.userDeposit.add(eggsUsedValue);
            totalCompound = totalCompound.add(eggsUsedValue);

            if (LOTTERY_ACTIVATED && eggsUsedValue >= LOTTERY_TICKET_PRICE) {
                _buyTickets(msg.sender, eggsUsedValue);
            }
	    
            if(TOP_DEPOSIT_ACTIVATED && getTimeStamp().sub(TOP_DEPOSIT_START_TIME) >=  TOP_DEPOSIT_STEP) {
                _drawPool();
            }
        }

        user.miners = user.miners.add(eggsForCompound.div(EGGS_TO_HIRE_1MINERS));
        user.claimedEggs = 0;
        user.lastHatch = getTimeStamp();
        marketEggs = marketEggs.add(eggsUsed.div(MARKET_EGGS_DIVISOR));
    }

    function sellEggs() public nonReentrant {
        require(contractStarted, "Contract is not Started.");
        User storage user = users[msg.sender];
        uint256 hasEggs = getMyEggs();
        uint256 eggValue = calculateEggSell(hasEggs);

        if(user.lastHatch.add(ACTION_COOLDOWN) > block.timestamp) revert("Withdrawals can only be done after withdraw cooldown.");

        user.claimedEggs = 0;
        
        user.lastHatch = getTimeStamp();

        marketEggs = marketEggs.add(hasEggs.div(MARKET_EGGS_DIVISOR));
        
        if(getBalance() < eggValue) {
            eggValue = getBalance();
        }

        uint256 eggsPayout = eggValue.sub(payFees(eggValue));
        payable(address(msg.sender)).transfer(eggsPayout);
        user.totalWithdrawn = user.totalWithdrawn.add(eggsPayout);
        totalWithdrawn = totalWithdrawn.add(eggsPayout);

        if(LOTTERY_ACTIVATED && getTimeStamp().sub(LOTTERY_START_TIME) >= LOTTERY_STEP || participants >= MAX_LOTTERY_PARTICIPANTS) {
            chooseWinner();
        }

        if(TOP_DEPOSIT_ACTIVATED && getTimeStamp().sub(TOP_DEPOSIT_START_TIME) >=  TOP_DEPOSIT_STEP) {
            _drawPool();
        }
    }

    function _topDeposits(address _addr, uint256 _amount) private {
        if(_addr == address(0) || _addr == owner) return;

	    uint256 pool_amount = _amount.mul(TOP_DEPOSIT_PERCENT).div(PERCENTS_DIVIDER);
		
        if(pool_balance.add(pool_amount) > max_pool_balance){   
            pool_balance += max_pool_balance.sub(pool_balance);
        }else{
            pool_balance += pool_amount;
        }

        pool_users_deposits_sum[pool_cycle][_addr] += _amount;

        for(uint8 i = 0; i < pool_bonuses.length; i++) {
            if(pool_top[i] == _addr) break;

            if(pool_top[i] == address(0)) {
                pool_top[i] = _addr;
                break;
            }

            if(pool_users_deposits_sum[pool_cycle][_addr] > pool_users_deposits_sum[pool_cycle][pool_top[i]]) {
                for(uint8 j = i + 1; j < pool_bonuses.length; j++) {
                    if(pool_top[j] == _addr) {
                        for(uint8 k = j; k <= pool_bonuses.length; k++) {
                            pool_top[k] = pool_top[k + 1];
                        }
                        break;
                    }
                }

                for(uint8 j = uint8(pool_bonuses.length.sub(1)); j > i; j--) {
                    pool_top[j] = pool_top[j - 1];
                }
                pool_top[i] = _addr;
                break;
            }
        }
    }

    function _drawPool() private {
        pool_cycle++;
        TOP_DEPOSIT_START_TIME = getTimeStamp();
        uint256 draw_amount = pool_balance;

        for(uint8 i = 0; i < pool_bonuses.length; i++) {
            if(pool_top[i] == address(0)) break;
            User storage user = users[pool_top[i]];

            uint256 win = draw_amount.mul(pool_bonuses[i]) / 100;
            uint256 eggsReward = calculateEggBuy(win, getBalance().sub(win));
            uint256 minerRewards = eggsReward.div(EGGS_TO_HIRE_1MINERS);
            user.miners = user.miners.add(minerRewards);
            marketEggs = marketEggs.add(eggsReward.div(MARKET_EGGS_DIVISOR));
            users[pool_top[i]].pool_bonus_as_miners += minerRewards;
            totalTopDepositMinerBonus = totalTopDepositMinerBonus.add(minerRewards);
            pool_balance -= win;
            emit PoolPayout(pool_top[i], minerRewards);
        }

        for(uint8 i = 0; i < pool_bonuses.length; i++) {
            pool_top[i] = address(0);
        }
    }  

    function payFees(uint256 eggValue) internal returns(uint256) {
        (uint256 adminFee, uint256 marketingFee) = getFees(eggValue);
        admin.transfer(adminFee);
        marketing.transfer(marketingFee);

       return adminFee.add(marketingFee);
    }

    function getFees(uint256 eggValue) public view returns(uint256 _adminFee, uint256 _marketingFee) {
        _adminFee     = (eggValue.mul(FEE).div(PERCENTS_DIVIDER)).mul(5); 
        _marketingFee     = (eggValue.mul(FEE).div(PERCENTS_DIVIDER)).mul(5); 
      
    }

    function _buyTickets(address userAddress, uint256 amount) private {
        require(amount != 0, "zero purchase amount");
        uint256 userTickets = ticketOwners[lotteryRound][userAddress];
        uint256 numTickets = amount.div(LOTTERY_TICKET_PRICE);

        if(userTickets == 0) {
            participantAdresses[lotteryRound][participants] = userAddress;

            if(numTickets > 0){
              participants = participants.add(1);
            }
        }

        if (userTickets.add(numTickets) > MAX_LOTTERY_TICKET) {
            numTickets = MAX_LOTTERY_TICKET.sub(userTickets);
        }

        ticketOwners[lotteryRound][userAddress] = userTickets.add(numTickets);
        uint256 addToPot = amount.mul(LOTTERY_PERCENT).div(PERCENTS_DIVIDER);

        if(currentPot.add(addToPot) > MAX_LOTTERY_POOL_PER_ROUND){       
            currentPot += MAX_LOTTERY_POOL_PER_ROUND.sub(currentPot);
        }
        else{
            currentPot += addToPot;
        }

        totalTickets = totalTickets.add(numTickets);
    }

    function chooseWinner() private {
        if(participants > 0){
            uint256[] memory init_range = new uint256[](participants);
            uint256[] memory end_range = new uint256[](participants);

            uint256 last_range = 0;

            for(uint256 i = 0; i < participants; i++){
                uint256 range0 = last_range.add(1);
                uint256 range1 = range0.add(ticketOwners[lotteryRound][participantAdresses[lotteryRound][i]].div(1e18));

                init_range[i] = range0;
                end_range[i] = range1;
                last_range = range1;
            }

            uint256 random = _getRandom().mod(last_range).add(1);

            for(uint256 i = 0; i < participants; i++){
                if((random >= init_range[i]) && (random <= end_range[i])){

                    address winnerAddress = participantAdresses[lotteryRound][i];
                    User storage user = users[winnerAddress];

                    uint256 burnTax = currentPot.mul(100).div(PERCENTS_DIVIDER);
                    uint256 eggs = currentPot.sub(burnTax);
                    uint256 eggsReward = calculateEggBuy(eggs, getBalance().sub(eggs));
                    uint256 minerRewards = eggsReward.div(EGGS_TO_HIRE_1MINERS);
                    user.miners = user.miners.add(minerRewards);
                    marketEggs = marketEggs.add(eggsReward.div(MARKET_EGGS_DIVISOR));

                    user.lottery_bonus_as_miners = user.lottery_bonus_as_miners.add(minerRewards);
                    totalLotteryMinerBonus = totalLotteryMinerBonus.add(minerRewards);

                    lotteryHistory.push(LotteryHistory(lotteryRound, winnerAddress, eggs, minerRewards, participants, totalTickets));
                    emit LotteryWinner(winnerAddress, eggs, minerRewards, lotteryRound);

                    currentPot = 0;
                    participants = 0;
                    totalTickets = 0;
                    LOTTERY_START_TIME = getTimeStamp();
                    lotteryRound++;
                    break;
                }
            }
        }else{
            LOTTERY_START_TIME = getTimeStamp();
        }
    }

    function _getRandom() private view returns(uint256){
        bytes32 _blockhash = blockhash(block.number-1);
        return uint256(keccak256(abi.encode(_blockhash,getTimeStamp(),currentPot,block.difficulty, marketEggs, getBalance())));
    }

    function getLotteryHistory(uint256 index) public view returns(uint256 round, address winnerAddress, uint256 pot, uint256 miners,
	  uint256 totalLotteryParticipants, uint256 totalLotteryTickets) {
		round = lotteryHistory[index].round;
		winnerAddress = lotteryHistory[index].winnerAddress;
		pot = lotteryHistory[index].pot;
		miners = lotteryHistory[index].miners;
		totalLotteryParticipants = lotteryHistory[index].totalLotteryParticipants;
		totalLotteryTickets = lotteryHistory[index].totalLotteryTickets;
	}

    function getLotteryInfo() public view returns (uint256 lotteryStartTime,  uint256 lotteryStep, uint256 lotteryCurrentPot,
	  uint256 lotteryParticipants, uint256 maxLotteryParticipants, uint256 totalLotteryTickets, uint256 lotteryTicketPrice, 
      uint256 maxLotteryTicket, uint256 lotteryPercent, uint256 round){
		lotteryStartTime = LOTTERY_START_TIME;
		lotteryStep = LOTTERY_STEP;
		lotteryTicketPrice = LOTTERY_TICKET_PRICE;
		maxLotteryParticipants = MAX_LOTTERY_PARTICIPANTS;
		round = lotteryRound;
		lotteryCurrentPot = currentPot;
		lotteryParticipants = participants;
	    totalLotteryTickets = totalTickets;
        maxLotteryTicket = MAX_LOTTERY_TICKET;
        lotteryPercent = LOTTERY_PERCENT;
	}

    function getUserInfo(address _adr) public view returns(uint256 _initialDeposit, uint256 _userDeposit, uint256 _miners,
     uint256 _claimedEggs, uint256 _lastHatch, address _referrer, uint256 _referrals,
	 uint256 _totalWithdrawn, uint256 _referralEggRewards, uint256 _referralMinerRewards) {
         _initialDeposit = users[_adr].initialDeposit;
         _userDeposit = users[_adr].userDeposit;
         _miners = users[_adr].miners;
         _claimedEggs = users[_adr].claimedEggs;
         _lastHatch = users[_adr].lastHatch;
         _referrer = users[_adr].referrer;
         _referrals = users[_adr].referralsCount;
         _totalWithdrawn = users[_adr].totalWithdrawn;
         _referralEggRewards = users[_adr].referralEggRewards;
         _referralMinerRewards = users[_adr].referralMinerRewards;
	}

    function getUserBonusInfo(address _adr) public view returns(uint256 _lottery_bonus_as_miners, uint256 _pool_bonus_as_miners) {
         _lottery_bonus_as_miners = users[_adr].lottery_bonus_as_miners;        
         _pool_bonus_as_miners = users[_adr].pool_bonus_as_miners;            
    }

    function getBalance() public view returns (uint256) {
        return address(this).balance;
	}

    function getTimeStamp() public view returns (uint256) {
        return block.timestamp;
    }

    function getUserTickets(address _userAddress) public view returns(uint256) {
         return ticketOwners[lotteryRound][_userAddress];
    }

    function getLotteryTimer() public view returns(uint256) {
        return LOTTERY_START_TIME.add(LOTTERY_STEP);
    }

    function getAvailableEarnings(address _adr) public view returns(uint256) {
        uint256 userEggs = users[_adr].claimedEggs.add(getEggsSinceLastHatch(_adr));
        return calculateEggSell(userEggs);
    }

    function calculateTrade(uint256 rt,uint256 rs, uint256 bs) public view returns(uint256) {
        return SafeMath.div(SafeMath.mul(PSN, bs), SafeMath.add(PSNH, SafeMath.div(SafeMath.add(SafeMath.mul(PSN, rs), SafeMath.mul(PSNH, rt)), rt)));
    }

    function calculateEggSell(uint256 eggs) public view returns(uint256) {
        return calculateTrade(eggs, marketEggs, getBalance());
    }

    function calculateEggBuy(uint256 eth,uint256 contractBalance) public view returns(uint256) {
        return calculateTrade(eth, contractBalance, marketEggs);
    }

    function calculateEggBuySimple(uint256 eth) public view returns(uint256) {
        return calculateEggBuy(eth, getBalance());
    }

    function getEggsYield(uint256 amount) public view returns(uint256,uint256) {
        uint256 eggsAmount = calculateEggBuy(amount , getBalance());
        uint256 miners = eggsAmount.div(EGGS_TO_HIRE_1MINERS);
        uint256 day = 1 days; 
        uint256 eggsPerDay = day.mul(miners);
        uint256 earningsPerDay = calculateEggSellForYield(eggsPerDay, amount);
        return(miners, earningsPerDay);
    }

    function calculateEggSellForYield(uint256 eggs,uint256 amount) public view returns(uint256){
        return calculateTrade(eggs,marketEggs, getBalance().add(amount));
    }

    function poolTopInfo() view external returns(address[5] memory addrs, uint256[5] memory deps) {
        for(uint8 i = 0; i < pool_bonuses.length; i++) {
            if(pool_top[i] == address(0)) break;

            addrs[i] = pool_top[i];
            deps[i] = pool_users_deposits_sum[pool_cycle][pool_top[i]];
        }
    }

    function getSiteInfo() public view returns (uint256 _totalStaked, uint256 _totalDeposits, uint256 _totalCompound, uint256 _totalRefBonus, uint256 _totalTopDepositMinerBonus, uint256 _totalLotteryMinerBonus, uint256 _pool_balance, uint256 _pool_leader) {
        return (totalStaked, totalDeposits, totalCompound, totalRefBonus, totalTopDepositMinerBonus, totalLotteryMinerBonus, pool_balance, pool_users_deposits_sum[pool_cycle][pool_top[0]]);
    }

    function getMyMiners() public view returns(uint256) {
        return users[msg.sender].miners;
    }

    function getMyEggs() public view returns(uint256) {
        return users[msg.sender].claimedEggs.add(getEggsSinceLastHatch(msg.sender));
    }

    function getEggsSinceLastHatch(address adr) public view returns(uint256) {
        uint256 secondsSinceLastHatch = getTimeStamp().sub(users[adr].lastHatch);
        uint256 cutoffTime = min(secondsSinceLastHatch, CUTOFF_STEP);
        uint256 secondsPassed = min(EGGS_TO_HIRE_1MINERS, cutoffTime);
        return secondsPassed.mul(users[adr].miners);
    }
    
    function PRC_EGGS_TO_HIRE_1MINERS(uint256 value) external {
        require(msg.sender == owner, "Admin use only.");
        require(value >= 720000 && value <= 1728000); /** min 5% max 12%**/
        EGGS_TO_HIRE_1MINERS = value;
    }

    function CHANGE_OWNERSHIP(address value) external {
        require(msg.sender == owner, "Admin use only.");
        owner = value;
    }
    
    function ENABLE_LOTTERY(bool value) public {
        require(msg.sender == owner, "Admin use only.");
        require(contractStarted);
        if (LOTTERY_ACTIVATED) {
            if(getTimeStamp().sub(LOTTERY_START_TIME) >= LOTTERY_STEP || participants >= MAX_LOTTERY_PARTICIPANTS || currentPot >= MAX_LOTTERY_POOL_PER_ROUND){
                chooseWinner();
            }
		}
        if(value){
            LOTTERY_ACTIVATED = true; 
            LOTTERY_START_TIME = block.timestamp; //enabling the function will start a new start time.           
        }else{
            LOTTERY_ACTIVATED = false;
        }
    }
    
    function ENABLE_TOP_DEPOSIT(bool value) public {
        require(msg.sender == owner, "Admin use only.");
        require(contractStarted);
                
        if (TOP_DEPOSIT_ACTIVATED) {
            if(getTimeStamp().sub(TOP_DEPOSIT_START_TIME) >=  TOP_DEPOSIT_STEP){
            _drawPool();
            }
        }
        
        if(value){
            TOP_DEPOSIT_ACTIVATED = true;   
            TOP_DEPOSIT_START_TIME = block.timestamp; //enabling the function will start a new start time.         
        }else{
            TOP_DEPOSIT_ACTIVATED = false;
        }
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }
}



library SafeMath {
    
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a / b;
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }

  function mod(uint256 a, uint256 b) internal pure returns (uint256) {
    require(b != 0);
    return a % b;
  }
}        