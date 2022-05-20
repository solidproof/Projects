/**
 *Submitted for verification at BscScan.com on 2022-05-10
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(_msgSender());
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract ParamountMiner is Ownable{
    using SafeMath for uint256;

    /** base parameters **/
    uint256 public ORES_TO_HIRE_1CRAFT = 1728000;
    uint256 public REFERRAL = 30;
    uint256 public PERCENTS_DIVIDER = 1000;
    uint256 public TAX = 15;
    uint256 public MKT = 15;
    uint256 public MARKET_ORES_DIVISOR = 2;

    uint256 public MIN_DEPOSIT_LIMIT = 0.01 ether;
    uint256 public WALLET_DEPOSIT_LIMIT = 25 ether;
    uint256[] public ROI_MAP = [1000 ether, 5000 ether, 10000 ether, 50000 ether, 100000 ether];

	uint256 public COMPOUND_BONUS = 20;
	uint256 public COMPOUND_BONUS_MAX_TIMES = 10;
    uint256 public COMPOUND_STEP = 12 * 60 * 60;

    uint256 public WITHDRAWAL_TAX = 800;
    uint256 public COMPOUND_FOR_NO_TAX_WITHDRAWAL = 10;

    uint256 public totalStaked;
    uint256 public totalCrafts;
    uint256 public totalDeposits;
    uint256 public totalCompound;
    uint256 public totalRefBonus;
    uint256 public totalWithdrawn;

    uint256 public marketOres;
    uint256 PSN = 10000;
    uint256 PSNH = 5000;
    bool public contractStarted;

	uint256 public CUTOFF_STEP = 48 * 60 * 60;

    /* addresses */
    address payable public dev;
    address payable public mkt;

    struct User {
        uint256 initialDeposit;
        uint256 userDeposit;
        uint256 crafts;
        uint256 claimedOres;
        uint256 lastHatch;
        address referrer;
        uint256 referralsCount;
        uint256 referralRewards;
        uint256 totalWithdrawn;
        uint256 dailyCompoundBonus;
        uint256 craftsCompoundCount; //added to monitor crafts consecutive compound without cap
        uint256 lastWithdrawTime;
    }

    mapping(address => User) public users;

    constructor(address payable _dev, address payable _mkt) {
		require(!isContract(_dev) && !isContract(_mkt));
        dev = _dev;
        mkt = _mkt;
    }

	function isContract(address addr) internal view returns (bool) {
        uint size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }

    function startJourney(address addr) public payable onlyOwner{
        if (!contractStarted) {
    		    require(marketOres == 0);
    			contractStarted = true;
                marketOres = 144000000000;
                hireSpaceCrafts(addr);
    	}
    }

    //fund contract with BNB before launch.
    function fundContract() external payable {}

    function hireMoreSpaceCrafts(bool isCompound) public {
        User storage user = users[msg.sender];
        require(contractStarted, "Contract not yet Started.");

        uint256 oresUsed = getMyOres();
        uint256 oresForCompound = oresUsed;

        if(isCompound) {
            uint256 dailyCompoundBonus = getDailyCompoundBonus(msg.sender, oresForCompound);
            oresForCompound = oresForCompound.add(dailyCompoundBonus);
            uint256 oresUsedValue = calculateOresSell(oresForCompound);
            user.userDeposit = user.userDeposit.add(oresUsedValue);
            totalCompound = totalCompound.add(oresUsedValue);
        }

        if(block.timestamp.sub(user.lastHatch) >= COMPOUND_STEP) {
            if(user.dailyCompoundBonus < COMPOUND_BONUS_MAX_TIMES) {
                user.dailyCompoundBonus = user.dailyCompoundBonus.add(1);
            }
            //add compoundCount for monitoring purposes.
            user.craftsCompoundCount = user.craftsCompoundCount .add(1);
        }

        user.crafts = user.crafts.add(oresForCompound.div(ORES_TO_HIRE_1CRAFT));
        totalCrafts = totalCrafts.add(oresForCompound.div(ORES_TO_HIRE_1CRAFT));
        user.claimedOres = 0;
        user.lastHatch = block.timestamp;

        marketOres = marketOres.add(oresUsed.div(MARKET_ORES_DIVISOR));
    }

    function sellOres() public{
        require(contractStarted, "Contract not yet Started.");

        User storage user = users[msg.sender];
        uint256 hasOres = getMyOres();
        uint256 oresValue = calculateOresSell(hasOres);

        /**
            if user compound < to mandatory compound days**/
        if(user.dailyCompoundBonus < COMPOUND_FOR_NO_TAX_WITHDRAWAL){
            //daily compound bonus count will not reset and oresValue will be deducted with 60% feedback tax.
            oresValue = oresValue.sub(oresValue.mul(WITHDRAWAL_TAX).div(PERCENTS_DIVIDER));
        }else{
            //set daily compound bonus count to 0 and oresValue will remain without deductions
             user.dailyCompoundBonus = 0;
             user.craftsCompoundCount = 0;
        }

        user.lastWithdrawTime = block.timestamp;
        user.claimedOres = 0;
        user.lastHatch = block.timestamp;
        marketOres = marketOres.add(hasOres.div(MARKET_ORES_DIVISOR));

        if(getBalance() < oresValue) {
            oresValue = getBalance();
        }

        uint256 oresPayout = oresValue.sub(payFees(oresValue));
        payable(address(msg.sender)).transfer(oresPayout);
        user.totalWithdrawn = user.totalWithdrawn.add(oresPayout);
        totalWithdrawn = totalWithdrawn.add(oresPayout);
    }


    /** transfer amount **/
    function hireSpaceCrafts(address ref) public payable{
        require(contractStarted, "Contract not yet Started.");
        require(msg.value >= MIN_DEPOSIT_LIMIT, "Less than min limit");
        User storage user = users[msg.sender];
        require(user.initialDeposit.add(msg.value) <= WALLET_DEPOSIT_LIMIT, "Max deposit limit reached.");
        uint256 oresBought = calculateOresBuy(msg.value, address(this).balance.sub(msg.value));
        user.userDeposit = user.userDeposit.add(msg.value);
        user.initialDeposit = user.initialDeposit.add(msg.value);
        user.claimedOres = user.claimedOres.add(oresBought);

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
            if (upline != address(0)) {
                uint256 refRewards = msg.value.mul(REFERRAL).div(PERCENTS_DIVIDER);
                payable(address(upline)).transfer(refRewards);
                users[upline].referralRewards = users[upline].referralRewards.add(refRewards);
                totalRefBonus = totalRefBonus.add(refRewards);
            }
        }

        uint256 oresPayout = payFees(msg.value);
        totalStaked = totalStaked.add(msg.value.sub(oresPayout));
        totalDeposits = totalDeposits.add(1);
        hireMoreSpaceCrafts(false);

        if(getBalance() < ROI_MAP[0]){
            ORES_TO_HIRE_1CRAFT = 1728000;
        } else if(getBalance() >= ROI_MAP[0] && getBalance() < ROI_MAP[1]){
            ORES_TO_HIRE_1CRAFT = 1584000;
        } else if(getBalance() >= ROI_MAP[1] && getBalance() < ROI_MAP[2]){
            ORES_TO_HIRE_1CRAFT = 1440000;
        } else if(getBalance() >= ROI_MAP[2] && getBalance() < ROI_MAP[3]){
            ORES_TO_HIRE_1CRAFT = 1320000;
        }  else if(getBalance() >= ROI_MAP[3] && getBalance() < ROI_MAP[4]){
            ORES_TO_HIRE_1CRAFT = 1200000;
        }  else if(getBalance() >= ROI_MAP[4]){
            ORES_TO_HIRE_1CRAFT = 1140000;
        }
    }

    function payFees(uint256 oresValue) internal returns(uint256){
        uint256 tax = oresValue.mul(TAX).div(PERCENTS_DIVIDER);
        uint256 mktng = oresValue.mul(MKT).div(PERCENTS_DIVIDER);
        dev.transfer(tax);
        mkt.transfer(mktng);
        return mktng.add(tax);
    }

    function getDailyCompoundBonus(address _adr, uint256 amount) public view returns(uint256){
        if(users[_adr].dailyCompoundBonus == 0) {
            return 0;
        } else {
            uint256 totalBonus = users[_adr].dailyCompoundBonus.mul(COMPOUND_BONUS);
            uint256 result = amount.mul(totalBonus).div(PERCENTS_DIVIDER);
            return result;
        }
    }

    function getUserInfo(address _adr) public view returns(uint256 _initialDeposit, uint256 _userDeposit, uint256 _crafts,
     uint256 _claimedOres, uint256 _lastHatch, address _referrer, uint256 _referrals,
	 uint256 _totalWithdrawn, uint256 _referralRewards, uint256 _dailyCompoundBonus, uint256 _craftsCompoundCount, uint256 _lastWithdrawTime) {
         _initialDeposit = users[_adr].initialDeposit;
         _userDeposit = users[_adr].userDeposit;
         _crafts = users[_adr].crafts;
         _claimedOres = users[_adr].claimedOres;
         _lastHatch = users[_adr].lastHatch;
         _referrer = users[_adr].referrer;
         _referrals = users[_adr].referralsCount;
         _totalWithdrawn = users[_adr].totalWithdrawn;
         _referralRewards = users[_adr].referralRewards;
         _dailyCompoundBonus = users[_adr].dailyCompoundBonus;
         _craftsCompoundCount = users[_adr].craftsCompoundCount;
         _lastWithdrawTime = users[_adr].lastWithdrawTime;
	}

    function getBalance() public view returns(uint256){
        return address(this).balance;
    }

    function getTimeStamp() public view returns (uint256) {
        return block.timestamp;
    }

    function getAvailableEarnings(address _adr) public view returns(uint256) {
        uint256 userOres = users[_adr].claimedOres.add(getOresSinceLastHatch(_adr));
        return calculateOresSell(userOres);
    }

    function calculateTrade(uint256 rt,uint256 rs, uint256 bs) public view returns(uint256){
        return SafeMath.div(
                SafeMath.mul(PSN, bs),
                    SafeMath.add(PSNH,
                        SafeMath.div(
                            SafeMath.add(
                                SafeMath.mul(PSN, rs),
                                    SafeMath.mul(PSNH, rt)),
                                        rt)));
    }

    function calculateOresSell(uint256 ores) public view returns(uint256){
        return calculateTrade(ores, marketOres, getBalance());
    }

    function calculateOresBuy(uint256 eth,uint256 contractBalance) public view returns(uint256){
        return calculateTrade(eth, contractBalance, marketOres);
    }

    function calculateOresBuySimple(uint256 eth) public view returns(uint256){
        return calculateOresBuy(eth, getBalance());
    }

    /** How many crafts and Ores per day user will recieve based on deposit amount **/
    function getOresYield(uint256 amount) public view returns(uint256,uint256) {
        uint256 oresAmount = calculateOresBuy(amount , getBalance().add(amount).sub(amount));
        uint256 crafts = oresAmount.div(ORES_TO_HIRE_1CRAFT);
        uint256 day = 1 days;
        uint256 oresPerDay = day.mul(crafts);
        uint256 earningsPerDay = calculateOresSellForYield(oresPerDay, amount);
        return(crafts, earningsPerDay);
    }

    function calculateOresSellForYield(uint256 ores,uint256 amount) public view returns(uint256){
        return calculateTrade(ores,marketOres, getBalance().add(amount));
    }

    function getSiteInfo() public view returns (uint256 _totalStaked, uint256 _totalCrafts, uint256 _totalDeposits, uint256 _totalCompound, uint256 _totalRefBonus) {
        return (totalStaked, totalCrafts, totalDeposits, totalCompound, totalRefBonus);
    }

    function getMyCrafts() public view returns(uint256){
        return users[msg.sender].crafts;
    }

    function getMyOres() public view returns(uint256){
        return users[msg.sender].claimedOres.add(getOresSinceLastHatch(msg.sender));
    }

    function getOresSinceLastHatch(address adr) public view returns(uint256){
        uint256 secondsSinceLastHatch = block.timestamp.sub(users[adr].lastHatch);
                            /** get min time. **/
        uint256 cutoffTime = min(secondsSinceLastHatch, CUTOFF_STEP);
        uint256 secondsPassed = min(ORES_TO_HIRE_1CRAFT, cutoffTime);
        return secondsPassed.mul(users[adr].crafts);
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }

    /** percentage setters **/

    function PRC_MARKET_ORES_DIVISOR(uint256 value) external onlyOwner {
        require(value <= 50);
        MARKET_ORES_DIVISOR = value;
    }

    function SET_WITHDRAWAL_TAX(uint256 value) external onlyOwner {
        require(value <= 800);
        WITHDRAWAL_TAX = value;
    }

    function BONUS_DAILY_COMPOUND(uint256 value) external onlyOwner {
        require(value >= 10 && value <= 900);
        COMPOUND_BONUS = value;
    }

    function BONUS_DAILY_COMPOUND_BONUS_MAX_TIMES(uint256 value) external onlyOwner {
        require(value <= 30);
        COMPOUND_BONUS_MAX_TIMES = value;
    }

    function BONUS_COMPOUND_STEP(uint256 value) external onlyOwner {
        require(value <= 24);
        COMPOUND_STEP = value * 60 * 60;
    }

    function SET_CUTOFF_STEP(uint256 value) external onlyOwner {
        require(value >= 24);
        CUTOFF_STEP = value * 60 * 60;
    }

    function SET_WALLET_DEPOSIT_LIMIT(uint256 value) external onlyOwner {
        require(value >= 10);
        WALLET_DEPOSIT_LIMIT = value * 1 ether;
    }

    function SET_COMPOUND_FOR_NO_TAX_WITHDRAWAL(uint256 value) external onlyOwner {
        require(value <= 12);
        COMPOUND_FOR_NO_TAX_WITHDRAWAL = value;
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