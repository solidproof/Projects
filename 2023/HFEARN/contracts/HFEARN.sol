//SPDX-License-Identifier: MIT
//02a5

pragma solidity ^0.8.0;

interface IBEP20 {

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(address from, address to, uint256 value) external returns (bool);
}

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

    
    error OwnableUnauthorizedAccount(address account);

    
    error OwnableInvalidOwner(address owner);

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(_msgSender());
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        if (owner() != _msgSender()) {
            revert OwnableUnauthorizedAccount(_msgSender());
        }
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert OwnableInvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

abstract contract ReentrancyGuard {
   
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;

    uint256 private _status;

   
    error ReentrancyGuardReentrantCall();

    constructor() {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        _nonReentrantBefore();
        _;
        _nonReentrantAfter();
    }

    function _nonReentrantBefore() private {

        if (_status == _ENTERED) {
            revert ReentrancyGuardReentrantCall();
        }

    
        _status = _ENTERED;
    }

    function _nonReentrantAfter() private {
        _status = _NOT_ENTERED;
    }

    function _reentrancyGuardEntered() internal view returns (bool) {
        return _status == _ENTERED;
    }
}

contract HFEARN is Ownable, ReentrancyGuard{
    using SafeMath for uint256;

    struct Deposit {
        uint256 amount;
        uint256 paidAmount;
        uint256 depositTime;
        uint256 paymentTime;
        address userAddr;
    }

    struct Jackpot {
        uint256 currentPot;
        uint256 startTime;
        address currentWinner;
        address lastWinner;
    }

    modifier notContract {
        require(!isContract(msg.sender), "caller is a contract");
        _;
    }

    uint256 constant public TOTAL_PROFIT = 130; //130%
    uint256 constant public PERCENTS_DIVIDER = 100; //100%

    uint256 constant public MIN_DEPOSIT = 250_000_000 * 10 ** 9;
    uint256 constant public MAX_DEPOSIT = 10_000_000_000 * 10 ** 9;

    uint256 constant public DEV_FEE = 3; //3%
    uint256 constant public MARKETING_FEE = 2; //2%

    uint256 constant public JACKPOT_FEE = 1; //1%
    uint256 public JACKPOT_STEP = 30 minutes;

    IBEP20 constant public TOKEN = IBEP20(0x759Bd4ed07A34b9ea761F8F2ED9f0e102675a29C);

    uint256 public currentIndex = 0;
    uint256 public depositId = 0;

    Jackpot public jackpot;

    address private devWallet;
    address private marketingWallet;

    mapping(uint256 => Deposit) public queue;

    event onDeposit(address indexed userAddr, uint256 amount, uint256 time);
    event onDistribution(address indexed userAddr, uint256 amount, uint256 time);
    event onDrawJackpot(address indexed userAddr, uint256 amount, uint256 time);

    constructor(address _dev, address _marketing) {
        require(!isContract(_dev));
        require(!isContract(_marketing));

        devWallet = _dev;
        marketingWallet = _marketing;
    }

    function deposit(uint256 amount) public payable notContract nonReentrant { // @audit Issue Medium- Contract lock Ether, no need of payable
        require(amount >= MIN_DEPOSIT, "min. deposit is 250 000 000 HF");
        require(amount <= MAX_DEPOSIT, "max. deposit is 10 000 000 000 HF");

        uint256 balanceBefore = getContractBalance();

        TOKEN.transferFrom(msg.sender, address(this), amount);

        uint256 balanceAfter = getContractBalance();

        uint256 depositedAmount = balanceAfter.sub(balanceBefore);

        enterQueue(msg.sender,depositedAmount);

        uint256 teamFee = payFee(depositedAmount);
        uint256 jackpotFee = depositedAmount.mul(JACKPOT_FEE).div(PERCENTS_DIVIDER);

        uint256 amountToDistribute = depositedAmount.sub(teamFee).sub(jackpotFee);

        
        distribute(amountToDistribute);
        enterJackpot(msg.sender,jackpotFee);

    }

    function distribute(uint256 amountToDistribute) internal {

        uint256 numUsersPaid = 0;

        for(uint256 i = currentIndex; i < depositId; i++) {
            Deposit storage userDeposit = queue[i];
            uint256 amountToPay = userDeposit.amount.mul(TOTAL_PROFIT).div(PERCENTS_DIVIDER).sub(userDeposit.paidAmount);
            address userToPay = userDeposit.userAddr;

            if(amountToPay > amountToDistribute) {

                userDeposit.paidAmount = userDeposit.paidAmount.add(amountToDistribute);

                TOKEN.transfer(userToPay,amountToDistribute);

                emit onDistribution(userToPay, amountToDistribute,block.timestamp);

                break;

            } else if(amountToPay == amountToDistribute) {
                userDeposit.paidAmount = userDeposit.paidAmount.add(amountToDistribute);
                userDeposit.paymentTime = block.timestamp;
                numUsersPaid = numUsersPaid.add(1);

                TOKEN.transfer(userToPay,amountToDistribute);

                emit onDistribution(userToPay, amountToDistribute,block.timestamp);

                break;

            } else {
                userDeposit.paidAmount = userDeposit.paidAmount.add(amountToPay);
                userDeposit.paymentTime = block.timestamp;
                numUsersPaid = numUsersPaid.add(1);

                amountToDistribute = amountToDistribute.sub(amountToPay);

                TOKEN.transfer(userToPay,amountToPay);

                emit onDistribution(userToPay, amountToPay,block.timestamp);
            }

        }

        currentIndex = currentIndex.add(numUsersPaid);
    }

    function enterQueue(address sender, uint256 amount) internal {
        Deposit storage newDeposit = queue[depositId];

        newDeposit.amount = amount;
        newDeposit.depositTime = block.timestamp;
        newDeposit.userAddr = sender;

        depositId = depositId.add(1);

        emit onDeposit(sender,amount,block.timestamp);
        
    }

    function enterJackpot(address userAddr, uint256 amount) internal {
        if(isDrawJackpot()) {
            drawJackpot(userAddr,amount);
        } else {

            jackpot.currentPot = jackpot.currentPot.add(amount);

            if(jackpot.currentWinner != userAddr) {
                jackpot.startTime = block.timestamp;
                jackpot.currentWinner = userAddr;
            }
        }
    }

    function drawJackpot(address userAddr, uint256 amount) internal {
        uint256 pot = jackpot.currentPot;
        address winner = jackpot.currentWinner;

        jackpot.currentPot = amount;
        jackpot.startTime = block.timestamp;
        jackpot.currentWinner = userAddr;
        jackpot.lastWinner = winner;

        TOKEN.transfer(winner,pot);

        emit onDrawJackpot(winner,pot,block.timestamp);
        

    }


    function payFee(uint256 amount) internal returns(uint256 feePaid) {

        uint256 marketingFee = amount.mul(MARKETING_FEE).div(PERCENTS_DIVIDER);
        uint256 devFee = amount.mul(DEV_FEE).div(PERCENTS_DIVIDER);

        TOKEN.transfer(marketingWallet,marketingFee);
        TOKEN.transfer(devWallet,devFee);

        feePaid = marketingFee.add(devFee);
    }

    function setJackpotStep(uint256 _minutes) public onlyOwner {
        JACKPOT_STEP = _minutes.mul(60);
    } 

    function getQueueData(uint256 startIndex) public view returns(Deposit[] memory) {

        uint256 length = depositId.sub(startIndex);

        Deposit[] memory data = new Deposit[](length);

        for(uint256 i = startIndex; i < depositId; i++) {
            data[i.sub(startIndex)] = queue[i];
        }

        return data;
    }

    function getJackpotData() public view returns(uint256 pot, uint256 timer, address currentWinner, address lastWinner) {
        pot = jackpot.currentPot;
        timer = block.timestamp.sub(jackpot.startTime);
        currentWinner = jackpot.currentWinner;
        lastWinner = jackpot.lastWinner;
    }


    function isDrawJackpot() internal view returns(bool) {
        if(jackpot.startTime == 0) {
            return false;
        }

        return block.timestamp.sub(jackpot.startTime) >= JACKPOT_STEP;
    } 

    function getContractBalance() public view returns(uint256) {
        return TOKEN.balanceOf(address(this));
    }

    function getUserBalance(address addr) public view returns(uint256) {
        return TOKEN.balanceOf(addr);
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