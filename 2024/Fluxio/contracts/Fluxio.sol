/**
 *Submitted for verification at BscScan.com on 2021-12-27
*/

// SPDX-License-Identifier: MIT

pragma solidity =0.8.19;


library SafeMath {
    
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            
            
            
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    
    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    
    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    
    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        this; 
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    
    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    
    function owner() public view virtual returns (address) {
        return _owner;
    }

    
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

contract FluxioContract is Ownable {
    using SafeMath for uint256;

    uint256 constant public DEPOSITS_MAX = 100;
    uint256 constant public INVEST_MIN_AMOUNT = 0.01 ether;
    uint256[] public REFERRAL_LEVELS_PERCENTS = [500, 700, 900, 1100, 1400, 1600, 1800, 2000];
    uint256[] public REFERRAL_LEVELS_MILESTONES = [0, 30 ether, 120 ether, 500 ether, 1000 ether, 3000 ether, 10000 ether, 20000 ether];
    uint8 constant public REFERRAL_DEPTH = 10;
    uint8 constant public REFERRAL_TURNOVER_DEPTH = 5;

    address payable constant public DEFAULT_REFERRER_ADDRESS = payable(0xD128abF7fE87244C636F448248D90420e1e0a6FF);

    
    address payable constant public MARKETING_ADDRESS = payable(0x1a52588EE9484E1d6591e602f86C44b7b23E28C1);
    uint256 constant public MARKETING_FEE = 750;
    address payable constant public PROMOTION_ADDRESS = payable(0x824248687F2729241e968b7887Ca81dDFe61b2b7);
    uint256 constant public PROMOTION_FEE = 500;
    address payable constant public ADVERTISING_ADDRESS = payable(0xcA59B23A69F9B6AF7962a00645f1bffDcb07e012);
    uint256 constant public ADVERTISING_FEE = 250;

    uint256 constant public BASE_PERCENT = 150; 

    
    uint256 constant public MAX_HOLD_PERCENT = 10000; 
    uint256 constant public HOLD_BONUS_PERCENT = 10; 

    
    uint256 constant public MAX_CONTRACT_PERCENT = 10000; 
    uint256 constant public CONTRACT_BALANCE_STEP = 0.1 ether; 
    uint256 constant public CONTRACT_HOLD_BONUS_PERCENT = 10; 

    
    uint256 constant public MAX_DEPOSIT_PERCENT = 10000; 
    uint256 constant public USER_DEPOSITS_STEP = 0.1 ether; 
    uint256 constant public VIP_BONUS_PERCENT = 10; 

    uint256 constant public TIME_STEP = 1 days;
    uint256 constant public PERCENTS_DIVIDER = 10000;

    uint256 public totalDeposits;
    uint256 public totalInvested;
    uint256 public totalWithdrawn;

    uint256 public contractPercent;

    address private contractOwner;

    struct Deposit {
        uint256 amount;
        uint256 withdrawn;
        uint256 refback;
        uint32 start;
        bool partner;
        uint256 partnerTime;
    }

    struct User {
        Deposit[] deposits;
        uint32 checkpoint;
        address referrer;
        address[] referrals;
        uint256 bonus;
        uint256[REFERRAL_DEPTH] refs;
        uint256[REFERRAL_DEPTH] refsNumber;
        uint16 rbackPercent;
        uint8 refLevel;
        uint256 refTurnover;
    }

    mapping (address => User) public users;

    event Newbie(address user);
    event NewDeposit(address indexed user, uint256 amount);
    event Withdrawn(address indexed user, uint256 amount);
    event RefBonus(address indexed referrer, address indexed referral, uint256 indexed level, uint256 amount);
    event RefBack(address indexed referrer, address indexed referral, uint256 amount);
    event FeePayed(address indexed user, uint256 totalAmount);

    constructor(address _contractOwner) {
        contractPercent = getContractBalanceRate();
        contractOwner = _contractOwner;
    }

    function invest(address referrer, uint256 _amount, address _to, bool _partner) public payable {
        require(!isContract(msg.sender) && msg.sender == tx.origin);

        uint256 investAmount = _partner ? _amount : msg.value;
        address _addressTo = _partner ? _to : msg.sender;

        if(!_partner) {
            require(msg.value >= INVEST_MIN_AMOUNT, "Minimum deposit amount 0.01 BNB");

            uint256 marketingFee = investAmount.mul(MARKETING_FEE).div(PERCENTS_DIVIDER);
            uint256 promotionFee = investAmount.mul(PROMOTION_FEE).div(PERCENTS_DIVIDER);
            uint256 advertisingFee = investAmount.mul(ADVERTISING_FEE).div(PERCENTS_DIVIDER);

            MARKETING_ADDRESS.transfer(marketingFee);
            PROMOTION_ADDRESS.transfer(promotionFee);
            ADVERTISING_ADDRESS.transfer(advertisingFee);

            emit FeePayed(_addressTo, marketingFee.add(promotionFee));
        } else require(contractOwner == msg.sender,  'You are not the owner of contract');


        User storage user = users[_addressTo];

        require(user.deposits.length < DEPOSITS_MAX, "Maximum 100 deposits from address");

        bool isNewUser = false;
        if (user.referrer == address(0)) {
            isNewUser = true;
            if (isActive(referrer) && referrer != _addressTo) {
              user.referrer = referrer;
              users[referrer].referrals.push(_addressTo);
            } else {
              user.referrer = DEFAULT_REFERRER_ADDRESS;
            }
        }

        uint256 refbackAmount;
        if (user.referrer != address(0)) {
            bool[] memory distributedLevels = new bool[](REFERRAL_LEVELS_PERCENTS.length);

            address current = _addressTo;
            address upline = user.referrer;
            uint8 maxRefLevel = 0;
            for (uint256 i = 0; i < REFERRAL_DEPTH; i++) {
                if (upline == address(0)) {
                  break;
                }

                uint256 refPercent = 0;
                if (i == 0) {
                  refPercent = REFERRAL_LEVELS_PERCENTS[users[upline].refLevel];

                  maxRefLevel = users[upline].refLevel;
                  for (uint8 j = users[upline].refLevel; j >= 0; j--) {
                    distributedLevels[j] = true;

                    if (j == 0) {
                      break;
                    }
                  }
                } else if (users[upline].refLevel > maxRefLevel && !distributedLevels[users[upline].refLevel]) {
                  refPercent = REFERRAL_LEVELS_PERCENTS[users[upline].refLevel]
                          .sub(REFERRAL_LEVELS_PERCENTS[maxRefLevel], "Ref percent calculation error");

                  maxRefLevel = users[upline].refLevel;
                  for (uint8 j = users[upline].refLevel; j >= 0; j--) {
                    distributedLevels[j] = true;

                    if (j == 0) {
                      break;
                    }
                  }
                }
                if(!_partner){
                    uint256 amount = msg.value.mul(refPercent).div(PERCENTS_DIVIDER);

                    if (i == 0 && users[upline].rbackPercent > 0 && amount > 0) {
                        refbackAmount = amount.mul(uint256(users[upline].rbackPercent)).div(PERCENTS_DIVIDER);
                        payable(_addressTo).transfer(refbackAmount);

                        emit RefBack(upline, _addressTo, refbackAmount);

                        amount = amount.sub(refbackAmount);
                    }

                    if (amount > 0) {
                        payable(upline).transfer(amount);
                        users[upline].bonus = uint256(users[upline].bonus).add(amount);

                        emit RefBonus(upline, _addressTo, i, amount);
                    }
                }
                

                users[upline].refs[i]++;
                if (isNewUser) {
                  users[upline].refsNumber[i]++;
                }

                current = upline;
                upline = users[upline].referrer;
            }

            upline = user.referrer;
            for (uint256 i = 0; i < REFERRAL_TURNOVER_DEPTH; i++) {
                if (upline == address(0)) {
                  break;
                }

                updateReferralLevel(upline, investAmount);

                upline = users[upline].referrer;
            }

        }

        if (user.deposits.length == 0) {
            user.checkpoint = uint32(block.timestamp);
            emit Newbie(_addressTo);
        }

        user.deposits.push(Deposit(investAmount, 0, refbackAmount, uint32(block.timestamp), _partner, 0));

        totalInvested = totalInvested.add(investAmount);
        totalDeposits++;
        checkPartners(_addressTo);
        if (contractPercent < BASE_PERCENT.add(MAX_CONTRACT_PERCENT)) {
            uint256 contractPercentNew = getContractBalanceRate();
            if (contractPercentNew > contractPercent) {
                contractPercent = contractPercentNew;
            }
        }

        emit NewDeposit(_addressTo, investAmount);
    }

    function withdraw() public {
        User storage user = users[msg.sender];

        uint256 userPercentRate = getUserPercentRate(msg.sender);

        uint256 totalAmount;
        uint256 dividends;

        for (uint8 i = 0; i < user.deposits.length; i++) {

            if (uint256(user.deposits[i].withdrawn) < uint256(user.deposits[i].amount).mul(2)) {

                if(user.deposits[i].partner){
                  if(user.refTurnover <= user.deposits[i].amount * 10) continue;
                  else {
                    if (user.deposits[i].partnerTime > user.checkpoint) {
                        dividends = (uint256(user.deposits[i].amount).mul(userPercentRate).div(PERCENTS_DIVIDER))
                            .mul(block.timestamp.sub(uint256(user.deposits[i].partnerTime)))
                            .div(TIME_STEP);

                    } else {
                        dividends = (uint256(user.deposits[i].amount).mul(userPercentRate).div(PERCENTS_DIVIDER))
                            .mul(block.timestamp.sub(uint256(user.checkpoint)))
                            .div(TIME_STEP);
                    }
                    if (uint256(user.deposits[i].withdrawn).add(dividends) > uint256(user.deposits[i].amount).mul(2)) {
                        dividends = (uint256(user.deposits[i].amount).mul(2)).sub(uint256(user.deposits[i].withdrawn));
                    }

                    user.deposits[i].withdrawn = uint256(user.deposits[i].withdrawn).add(dividends); 
                    totalAmount = totalAmount.add(dividends);
                    continue;
                  }
                }

                if (user.deposits[i].start > user.checkpoint) {
                    dividends = (uint256(user.deposits[i].amount).mul(userPercentRate).div(PERCENTS_DIVIDER))
                        .mul(block.timestamp.sub(uint256(user.deposits[i].start)))
                        .div(TIME_STEP);

                } else {

                    dividends = (uint256(user.deposits[i].amount).mul(userPercentRate).div(PERCENTS_DIVIDER))
                        .mul(block.timestamp.sub(uint256(user.checkpoint)))
                        .div(TIME_STEP);

                }

                if (uint256(user.deposits[i].withdrawn).add(dividends) > uint256(user.deposits[i].amount).mul(2)) {
                    dividends = (uint256(user.deposits[i].amount).mul(2)).sub(uint256(user.deposits[i].withdrawn));
                }

                user.deposits[i].withdrawn = uint256(user.deposits[i].withdrawn).add(dividends); 
                totalAmount = totalAmount.add(dividends);

            }
        }

        require(totalAmount > 0, "User has no dividends");

        uint256 contractBalance = address(this).balance;
        if (contractBalance < totalAmount) {
            totalAmount = contractBalance;
        }

        user.checkpoint = uint32(block.timestamp);

        payable(msg.sender).transfer(totalAmount);

        totalWithdrawn = totalWithdrawn.add(totalAmount);

        emit Withdrawn(msg.sender, totalAmount);
    }

    function setRefback(uint16 rbackPercent) public {
        require(rbackPercent <= 10000);

        User storage user = users[msg.sender];

        if (user.deposits.length > 0) {
            user.rbackPercent = rbackPercent; }
    }

    function getContractBalance() public view returns (uint256) {
        return address(this).balance;
    }

    function getContractBalanceRate() public view returns (uint256) {
        uint256 contractBalance = address(this).balance;
        uint256 contractBalancePercent = BASE_PERCENT.add(
          contractBalance
            .div(CONTRACT_BALANCE_STEP)
            .mul(CONTRACT_HOLD_BONUS_PERCENT)
        );

        if (contractBalancePercent < BASE_PERCENT.add(MAX_CONTRACT_PERCENT)) {
            return contractBalancePercent;
        } else {
            return BASE_PERCENT.add(MAX_CONTRACT_PERCENT);
        }
    }

    function getUserDepositRate(address userAddress) public view returns (uint256) {
        uint256 userDepositRate;

        if (getUserAmountOfDeposits(userAddress) > 0) {
            userDepositRate = getUserTotalDeposits(userAddress).div(USER_DEPOSITS_STEP).mul(VIP_BONUS_PERCENT);

            if (userDepositRate > MAX_DEPOSIT_PERCENT) {
                userDepositRate = MAX_DEPOSIT_PERCENT;
            }
        }

        return userDepositRate;
    }

    function getUserPercentRate(address userAddress) public view returns (uint256) {
        User storage user = users[userAddress];

        if (isActive(userAddress)) {
            uint256 userDepositRate = getUserDepositRate(userAddress);

            uint256 timeMultiplier = (block.timestamp.sub(uint256(user.checkpoint))).div(TIME_STEP).mul(HOLD_BONUS_PERCENT);
            if (timeMultiplier > MAX_HOLD_PERCENT) {
                timeMultiplier = MAX_HOLD_PERCENT;
            }

            return contractPercent.add(timeMultiplier).add(userDepositRate);
        } else {
            return contractPercent;
        }
    }

    function getUserAvailable(address userAddress) public view returns (uint256) {
        User memory user = users[userAddress];

        uint256 userPercentRate = getUserPercentRate(userAddress);

        uint256 totalDividends;
        uint256 dividends;

        for (uint8 i = 0; i < user.deposits.length; i++) {

            if (uint256(user.deposits[i].withdrawn) < uint256(user.deposits[i].amount).mul(2)) {

                  if(user.deposits[i].partner){
                    if(user.refTurnover <= user.deposits[i].amount * 10) continue;
                    else {
                      if (user.deposits[i].partnerTime > user.checkpoint) {
                          dividends = (uint256(user.deposits[i].amount).mul(userPercentRate).div(PERCENTS_DIVIDER))
                              .mul(block.timestamp.sub(uint256(user.deposits[i].partnerTime)))
                              .div(TIME_STEP);

                      } else {
                          dividends = (uint256(user.deposits[i].amount).mul(userPercentRate).div(PERCENTS_DIVIDER))
                              .mul(block.timestamp.sub(uint256(user.checkpoint)))
                              .div(TIME_STEP);
                      }

                      if (uint256(user.deposits[i].withdrawn).add(dividends) > uint256(user.deposits[i].amount).mul(2)) {
                          dividends = (uint256(user.deposits[i].amount).mul(2)).sub(uint256(user.deposits[i].withdrawn));
                      }

                      totalDividends = totalDividends.add(dividends);

                      continue;
                    }
                  }

                 

                if (user.deposits[i].start > user.checkpoint) {

                    dividends = (uint256(user.deposits[i].amount).mul(userPercentRate).div(PERCENTS_DIVIDER))
                        .mul(block.timestamp.sub(uint256(user.deposits[i].start)))
                        .div(TIME_STEP);

                } else {

                    dividends = (uint256(user.deposits[i].amount).mul(userPercentRate).div(PERCENTS_DIVIDER))
                        .mul(block.timestamp.sub(uint256(user.checkpoint)))
                        .div(TIME_STEP);

                }

                if (uint256(user.deposits[i].withdrawn).add(dividends) > uint256(user.deposits[i].amount).mul(2)) {
                    dividends = (uint256(user.deposits[i].amount).mul(2)).sub(uint256(user.deposits[i].withdrawn));
                }

                totalDividends = totalDividends.add(dividends);
            }

        }

        return totalDividends;
    }

    function checkPartners(address _referral) private {

      address[] memory uplinersList = new address[](REFERRAL_DEPTH);

      address currentReferrer = users[_referral].referrer;

      for (uint i = 0; i < REFERRAL_DEPTH; i++) {
          uplinersList[i] = currentReferrer;
          currentReferrer = users[currentReferrer].referrer;
      }

      for(uint i = 0; i < REFERRAL_DEPTH; i++){

        if(uplinersList[i] == address(0x0) || uplinersList[i] == DEFAULT_REFERRER_ADDRESS) return;
        User storage currentUpliner = users[uplinersList[i]];

        for(uint j = 0; j < currentUpliner.deposits.length; j++){

          if(currentUpliner.deposits[j].partner){

            if(currentUpliner.refTurnover * 10 >= currentUpliner.deposits[j].amount){
              currentUpliner.deposits[j].partnerTime = block.timestamp;
            }
          }
        }
      }
    }

    function isActive(address userAddress) public view returns (bool) {
        User storage user = users[userAddress];

        return (user.deposits.length > 0) && uint256(user.deposits[user.deposits.length-1].withdrawn) < uint256(user.deposits[user.deposits.length-1].amount).mul(2);
    }

    function getUserAmountOfDeposits(address userAddress) public view returns (uint256) {
        return users[userAddress].deposits.length;
    }

    function getUserTotalDeposits(address userAddress) public view returns (uint256) {
        User storage user = users[userAddress];

        uint256 amount;

        for (uint256 i = 0; i < user.deposits.length; i++) {
            amount = amount.add(user.deposits[i].amount);
        }

        return amount;
    }

    function getUserTotalWithdrawn(address userAddress) public view returns (uint256) {
        User storage user = users[userAddress];

        uint256 amount = user.bonus;

        for (uint256 i = 0; i < user.deposits.length; i++) {
            amount = amount.add(user.deposits[i].withdrawn).add(user.deposits[i].refback);
        }

        return amount;
    }

    function getContractPercent() public view returns(uint256 _contractPercent) {
        return contractPercent;
    }

    function getUserDeposits(address userAddress, uint256 last, uint256 first) public view
      returns (uint256[] memory, uint256[] memory, uint256[] memory, uint256[] memory) {
        User storage user = users[userAddress];

        uint256 count = first.sub(last);
        if (count > user.deposits.length) {
            count = user.deposits.length;
        }

        uint256[] memory amount = new uint256[](count);
        uint256[] memory withdrawn = new uint256[](count);
        uint256[] memory refback = new uint256[](count);
        uint256[] memory start = new uint256[](count);

        uint256 index = 0;
        for (uint256 i = first; i > last; i--) {
            amount[index] = user.deposits[i-1].amount;
            withdrawn[index] = user.deposits[i-1].withdrawn;
            refback[index] = user.deposits[i-1].refback;
            start[index] = uint256(user.deposits[i-1].start);
            index++;
        }

        return (amount, withdrawn, refback, start);
    }

    function getSiteStats() public view returns (uint256, uint256, uint256, uint256) {
        return (totalInvested, totalDeposits, address(this).balance, contractPercent);
    }

    function getUserStats(address userAddress) public view returns (uint256, uint256, uint256, uint256, uint256, uint256) {
        uint256 userPerc = getUserPercentRate(userAddress);
        uint256 userAvailable = getUserAvailable(userAddress);
        uint256 userDepsTotal = getUserTotalDeposits(userAddress);
        uint256 userDeposits = getUserAmountOfDeposits(userAddress);
        uint256 userWithdrawn = getUserTotalWithdrawn(userAddress);
        uint256 userDepositRate = getUserDepositRate(userAddress);

        return (userPerc, userAvailable, userDepsTotal, userDeposits, userWithdrawn, userDepositRate);
    }

    function getDepositsRates(address userAddress) public view returns (uint256, uint256, uint256, uint256) {
      User memory user = users[userAddress];

      uint256 holdBonusPercent = (block.timestamp.sub(uint256(user.checkpoint))).div(TIME_STEP).mul(HOLD_BONUS_PERCENT);
      if (holdBonusPercent > MAX_HOLD_PERCENT) {
          holdBonusPercent = MAX_HOLD_PERCENT;
      }

      return (
        BASE_PERCENT, 
        !isActive(userAddress) ? 0 : holdBonusPercent, 
        address(this).balance.div(CONTRACT_BALANCE_STEP).mul(CONTRACT_HOLD_BONUS_PERCENT), 
        !isActive(userAddress) ? 0 : getUserDepositRate(userAddress) 
      );
    }

    function getUserReferralsStats(address userAddress) public view
      returns (address, uint16, uint16, uint256, uint256[REFERRAL_DEPTH] memory, uint256[REFERRAL_DEPTH] memory, uint256, uint256) {
        User storage user = users[userAddress];

        return (
          user.referrer,
          user.rbackPercent,
          users[user.referrer].rbackPercent,
          user.bonus,
          user.refs,
          user.refsNumber,
          user.refLevel,
          user.refTurnover
        );
    }

    function isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }

    function updateReferralLevel(address _userAddress, uint256 _amount) private {
      users[_userAddress].refTurnover = users[_userAddress].refTurnover.add(_amount);

      for (uint8 level = uint8(REFERRAL_LEVELS_MILESTONES.length - 1); level > 0; level--) {
        if (users[_userAddress].refTurnover >= REFERRAL_LEVELS_MILESTONES[level]) {
          users[_userAddress].refLevel = level;

          break;
        }
      }
    }

    function referrals(address user) external view returns(address[] memory) {
      return users[user].referrals;
    }

    function withdrawBnb() external payable {
        require(contractOwner == msg.sender, 'You are not owner of contract');
        payable(msg.sender).transfer(msg.value);
    }
}