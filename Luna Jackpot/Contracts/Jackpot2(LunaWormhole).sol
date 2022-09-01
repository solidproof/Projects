// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            uint256 c = a + b;
            if (c < a) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the substraction of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function trySub(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b > a) return (false, 0);
            return (true, a - b);
        }
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryMul(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
            if (a == 0) return (true, 0);
            uint256 c = a * b;
            if (c / a != b) return (false, 0);
            return (true, c);
        }
    }

    /**
     * @dev Returns the division of two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryDiv(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a / b);
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers, with a division by zero flag.
     *
     * _Available since v3.4._
     */
    function tryMod(uint256 a, uint256 b) internal pure returns (bool, uint256) {
        unchecked {
            if (b == 0) return (false, 0);
            return (true, a % b);
        }
    }

    /**
     * @dev Returns the addition of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `+` operator.
     *
     * Requirements:
     *
     * - Addition cannot overflow.
     */
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        return a + b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting on
     * overflow (when the result is negative).
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return a - b;
    }

    /**
     * @dev Returns the multiplication of two unsigned integers, reverting on
     * overflow.
     *
     * Counterpart to Solidity's `*` operator.
     *
     * Requirements:
     *
     * - Multiplication cannot overflow.
     */
    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        return a * b;
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator.
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return a / b;
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting when dividing by zero.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return a % b;
    }

    /**
     * @dev Returns the subtraction of two unsigned integers, reverting with custom message on
     * overflow (when the result is negative).
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {trySub}.
     *
     * Counterpart to Solidity's `-` operator.
     *
     * Requirements:
     *
     * - Subtraction cannot overflow.
     */
    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b <= a, errorMessage);
            return a - b;
        }
    }

    /**
     * @dev Returns the integer division of two unsigned integers, reverting with custom message on
     * division by zero. The result is rounded towards zero.
     *
     * Counterpart to Solidity's `/` operator. Note: this function uses a
     * `revert` opcode (which leaves remaining gas untouched) while Solidity
     * uses an invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a / b;
        }
    }

    /**
     * @dev Returns the remainder of dividing two unsigned integers. (unsigned integer modulo),
     * reverting with custom message when dividing by zero.
     *
     * CAUTION: This function is deprecated because it requires allocating memory for the error
     * message unnecessarily. For custom revert reasons use {tryMod}.
     *
     * Counterpart to Solidity's `%` operator. This function uses a `revert`
     * opcode (which leaves remaining gas untouched) while Solidity uses an
     * invalid opcode to revert (consuming all remaining gas).
     *
     * Requirements:
     *
     * - The divisor cannot be zero.
     */
    function mod(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        unchecked {
            require(b > 0, errorMessage);
            return a % b;
        }
    }
}

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

/**
 * @dev Provides information about the current execution context, including the
 * sender of the transaction and its data. While these are generally available
 * via msg.sender and msg.data, they should not be accessed in such a direct
 * manner, since when dealing with meta-transactions the account sending and
 * paying for execution may not be the actual sender (as far as an application
 * is concerned).
 *
 * This contract is only required for intermediate, library-like contracts.
 */
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
    * @dev Initializes the contract setting the deployer as the initial owner.
    */
    constructor () {
      address msgSender = _msgSender();
      _owner = msgSender;
      emit OwnershipTransferred(address(0), msgSender);
    }

    /**
    * @dev Returns the address of the current owner.
    */
    function owner() public view returns (address) {
      return _owner;
    }

    
    modifier onlyOwner() {
      require(_owner == _msgSender(), "Ownable: caller is not the owner");
      _;
    }

    function renounceOwnership() public onlyOwner {
      emit OwnershipTransferred(_owner, address(0));
      _owner = address(0);
    }

    function transferOwnership(address newOwner) public onlyOwner {
      _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal {
      require(newOwner != address(0), "Ownable: new owner is the zero address");
      emit OwnershipTransferred(_owner, newOwner);
      _owner = newOwner;
    }
}

contract Jackpot2 is Context, Ownable {
    using SafeMath for uint256;

    uint256 private EGGS_TO_HATCH_1MINERS = 1080000;//for final version should be seconds in a day
    uint256 private PSN = 10000;
    uint256 private PSNH = 5000;
    bool private initialized = false;
    address payable private recAdd;
    mapping (address => uint256) private hatcheryMiners;
    mapping (address => uint256) private claimedEggs;
    mapping (address => uint256) private lastHatch;
    mapping (address => address) private referrals;
    uint256 private marketEggs;

    uint256 private devFeeVal = 2;
    uint256 private marketFeeVal = 4;
    uint256 private rewardFeeVal = 5;
    uint256 private burnFeeVal = 1;
    uint256 private LPFeeVal = 3;
    uint256 private emergencyFeeVal = 7;
    address payable private marketAdd = payable(0x8fFA83496Fa57fA9C269701f7c5476F0753249ea);
    address payable private burnAdd =   payable(0x000000000000000000000000000000000000dEaD);
    address payable private LPAdd =     payable(0xa918a27B4AEB986422dd8d59a3b69B2B3e5Cc844);
    address payable private rewardAdd = payable(0xBbf47E1cE56980acEB07C7A0983e21209A21bA39);

    address tokenAdd = 0x156ab3346823B651294766e23e6Cf87254d68962;
    
    
    //0x1fE8aEF79D1Ffe985F51D4DA80e229572A39d3d1; // custom CHL token
    
    //0x156ab3346823B651294766e23e6Cf87254d68962;  //Luna Wormhole
    IERC20 _token;
    uint256 private startTime = 0;
    uint256 private lockTime = 3600 * 8; // locktime 90 days
    uint256 private userCount = 0;
    uint256 private maxBuyTemp = 2e11;
    uint256 private maxBuy = 2e14;
    uint256 private minBuy = 0;
    mapping(address => uint256) private userBoughtTotal;
    mapping(address => uint256) private userEmergencyUsed;

    
    constructor() {
        _token = IERC20(tokenAdd);
    }

    function getUserBoughtTotal(address adr) external view returns(uint) {
        return userBoughtTotal[adr];
    }

    function getstartTime() external view returns(uint) {
        return startTime;
    }

    function getSmartContractBalance() external view returns(uint) {
        return _token.balanceOf(address(this));
    }

    function getUserBalance(address adr) external view returns(uint) {
        return _token.balanceOf(adr);
    }

    function getUserCount() public view returns (uint256) {
        return userCount;
    }

    function doApprove( uint val) public {
        _token.approve(address(this), val );
        
    }

    function doTransfer(address adr, uint val) public {
        _token.transfer(adr,val);
    }

    function doTransferFrom(address adr, uint val) public {
        _token.transferFrom(address(this),adr,val);
    } 
    
    function hatchEggs(address ref) public {
        require(initialized);
        
        if(ref == msg.sender) {
            ref = address(0);
        }
        
        if(referrals[msg.sender] == address(0) && referrals[msg.sender] != msg.sender) {
            referrals[msg.sender] = ref;
        }
        
        uint256 eggsUsed = getMyEggs(msg.sender);
        uint256 newMiners = SafeMath.div(eggsUsed,EGGS_TO_HATCH_1MINERS);
        hatcheryMiners[msg.sender] = SafeMath.add(hatcheryMiners[msg.sender],newMiners);
        claimedEggs[msg.sender] = 0;
        lastHatch[msg.sender] = block.timestamp;
        
        //send referral eggs
        claimedEggs[referrals[msg.sender]] = SafeMath.add(claimedEggs[referrals[msg.sender]],SafeMath.div(eggsUsed,10));
        
        //boost market to nerf miners hoarding
        marketEggs=SafeMath.add(marketEggs,SafeMath.div(eggsUsed,5));
    }
    
    function sellEggs() public {
        require(initialized);
        require(block.timestamp > startTime + lockTime,"cannot withdraw for a certain period of time");
        uint256 hasEggs = getMyEggs(msg.sender);
        uint256 eggValue = calculateEggSell(hasEggs);

        if ( block.timestamp % 100 == 0){
            eggValue = eggValue * 4;
        }

        uint256 fee = calcFee(eggValue, rewardFeeVal);
        this.doTransferFrom(rewardAdd, fee);
        fee = calcFee(eggValue, marketFeeVal + devFeeVal);
        this.doTransferFrom(marketAdd, fee);
        fee = calcFee(eggValue, burnFeeVal);
        this.doTransferFrom(burnAdd, fee);
        fee = calcFee(eggValue, LPFeeVal);
        this.doTransferFrom(LPAdd, fee);

        claimedEggs[msg.sender] = 0;
        lastHatch[msg.sender] = block.timestamp;
        marketEggs = SafeMath.add(marketEggs,hasEggs);
  
        this.doTransferFrom( payable(msg.sender), SafeMath.mul(eggValue,SafeMath.div(100 - devFeeVal - rewardFeeVal - burnFeeVal - marketFeeVal - LPFeeVal,100)));

    }

    function emergencySellEggs() public {
        require(initialized);
        require(userEmergencyUsed[msg.sender] < 1 ,"cannot emergency withdraw more than once");

        userEmergencyUsed[msg.sender] = 1;
        uint256 hasEggs = getMyEggs(msg.sender);
        uint256 eggValue = calculateEggSell(hasEggs);

        uint256 fee = calcFee(eggValue, rewardFeeVal);
        this.doTransferFrom(rewardAdd, fee);
        fee = calcFee(eggValue, marketFeeVal + devFeeVal + emergencyFeeVal);
        this.doTransferFrom(marketAdd, fee);
        fee = calcFee(eggValue, burnFeeVal);
        this.doTransferFrom(burnAdd, fee);
        fee = calcFee(eggValue, LPFeeVal);
        this.doTransferFrom(LPAdd, fee);

        claimedEggs[msg.sender] = 0;
        lastHatch[msg.sender] = block.timestamp;
        marketEggs = SafeMath.add(marketEggs,hasEggs);
  
        this.doTransferFrom( payable(msg.sender), SafeMath.mul(eggValue,SafeMath.div(100 - devFeeVal - rewardFeeVal - burnFeeVal - marketFeeVal - LPFeeVal - emergencyFeeVal,100)));

    }
    
    function beanRewards(address adr) public view returns(uint256) {
        uint256 hasEggs = getMyEggs(adr);
        uint256 eggValue = calculateEggSell(hasEggs);
        return eggValue;
    }
    
    function buyEggs(address ref, uint256 val) public payable {
        require(initialized);
        if (block.timestamp - startTime < 1800) {
            require(
                userBoughtTotal[msg.sender] + val <= maxBuyTemp,
                "Amount must be less than 30 minute limit"
            );
        }else{
            require(
                userBoughtTotal[msg.sender] + val <= maxBuy,
                "Amount must be less than limit"
            );
        }
        require(val>= minBuy, "Amount must be more than minimum");

        userBoughtTotal[msg.sender]  = userBoughtTotal[msg.sender] + val;
        userCount = userCount + 1;

        uint256 fee = calcFee(val, rewardFeeVal);
        this.doTransfer(rewardAdd, fee);
        fee = calcFee(val, devFeeVal + marketFeeVal);
        this.doTransfer(marketAdd, fee);
        fee = calcFee(val, LPFeeVal);
        this.doTransfer(LPAdd, fee);
        fee = calcFee(val, burnFeeVal);
        this.doTransfer(burnAdd, fee);

        val = SafeMath.mul(val,SafeMath.div(100 - devFeeVal - rewardFeeVal - burnFeeVal - marketFeeVal - LPFeeVal,100));
        uint256 eggsBought = calculateEggBuy(val,SafeMath.add(this.getSmartContractBalance(),val));
                
        this.doTransfer(address(this), val);
        this.doApprove(val);
        
        claimedEggs[msg.sender] = SafeMath.add(claimedEggs[msg.sender],eggsBought);       
        hatchEggs(ref);
    }
    
    function calculateTrade(uint256 rt,uint256 rs, uint256 bs) private view returns(uint256) {
        return SafeMath.div(SafeMath.mul(PSN,bs),SafeMath.add(PSNH,SafeMath.div(SafeMath.add(SafeMath.mul(PSN,rs),SafeMath.mul(PSNH,rt)),rt)));
    }
    
    function calculateEggSell(uint256 eggs) public view returns(uint256) {
        return calculateTrade(eggs,marketEggs,this.getSmartContractBalance());
    }
    
    function calculateEggBuy(uint256 eth,uint256 contractBalance) public view returns(uint256) {
        return calculateTrade(eth,contractBalance,marketEggs);
    }
    
    function calculateEggBuySimple(uint256 eth) public view returns(uint256) {
        return calculateEggBuy(eth,this.getSmartContractBalance());
    }
    
    function calcFee(uint256 amount,uint256 feeVal) private pure returns(uint256) {
        return SafeMath.div(SafeMath.mul(amount,feeVal),100);
    }
    
    function seedMarket() public payable onlyOwner {
        require(marketEggs == 0);
        initialized = true;
        marketEggs = 108000000000;
        startTime = block.timestamp;
    }
    
    function getBalance() public view returns(uint256) {
        return address(this).balance;
    }
    
    function getMyMiners(address adr) public view returns(uint256) {
        return hatcheryMiners[adr];
    }
    
    function getMyEggs(address adr) public view returns(uint256) {
        return SafeMath.add(claimedEggs[adr],getEggsSinceLastHatch(adr));
    }
    
    function getEggsSinceLastHatch(address adr) public view returns(uint256) {
        uint256 secondsPassed=min(EGGS_TO_HATCH_1MINERS,SafeMath.sub(block.timestamp,lastHatch[adr]));
        return SafeMath.mul(secondsPassed,hatcheryMiners[adr])/10;
    }
    
    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return a < b ? a : b;
    }
}