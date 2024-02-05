/**
 *Submitted for verification at BscScan.com on 2022-03-18
*/

// SPDX-License-Identifier: MIT




//   (((,                                                                     *///
//    ((((#**                                                               **/////
//    ((((####///                                                       ***(///////
//     (((#######///                                                 ***((((//////
//     (((##########////                                         ****(((((((//////
//     (((############/////                                   ****/(((((((((//////
//     (((###############////////////////////////////////////***((((((((((((//////
//     (((##################/////////////////////////////////###((((((((((((//////
//      ((#####################///////////////////////////######((((((((((((/////
//      ((######################/////////////////////////#######((((((((((((/////
//      ((######################%///////////////////////########((((((((((((/////
//      ((######################%///////////////////////########((((((((((((/////
//      ((######################%%/////////////////////#########((((((((((((////*
//     **(######################%%%///////////////////##########((((((((((((////**
//     **(######################%%%///////////////////##########((((((((((((////**
//    ****#############@@@@@####%%%%/////////////////#######@@@@@((((((((((///***,              ██╗    ██╗███████╗███╗   ██╗
//    ****##############@@@@@@@@@%%%////////////////####@@@@@@@@@(((((((((((///***,             ██║    ██║██╔════╝████╗  ██║
//   .****################@@@@&#%%%%%///////////////######&@@@@@((((((((((((///***,             ██║ █╗ ██║█████╗  ██╔██╗ ██║
//   ******#####################%%%%%%/////////////#############((((((((((((//****,,            ██║███╗██║██╔══╝  ██║╚██╗██║
//   ******#####################%%%%%%/////////////#############((((((((((((//****,,            ╚███╔███╔╝███████╗██║ ╚████║
//    *******###################%%%%%%%///////////%#############((((((((((((******,              ╚══╝╚══╝ ╚══════╝╚═╝  ╚═══╝
//       *****///###############%%%%%%%%/////////%%#############((((((((********
//          **//////############%%%%%%%%/////////%%#############(((((********
//             /////////########%%%%%%%%%///////%%%#############(********,
//                *///////######%%%%%%%%%///////%%%############*******
//                   ////######%%%%%%%%%%/////%%%%###########(****
//                        //#####%%%%%%%%%%%///%%%%%###########**
//                         #####%%%%%%%%%%%///%%%%%##########/
//                          ####%%%%%%%%%%%%/%%%%%%##########
//                          /###%%%%%%%%@&%%(%%&&%%#########/
//                           //#%%%%%%@@@@@@@@@@@@@#######//
//                           ///%%%%%%%@@@@@@@@@@@%######///
//                            ////%%%%%%%%@@@@@@%%%####////
//                              ///%%%%%%%%///%%%%%###///
//                                ///%%%%///////%%%#///
//                                   /%%/////////%%/






//      ███████╗███████╗███████╗███████╗
//      ██╔════╝██╔════╝██╔════╝██╔════╝
//      █████╗  █████╗  █████╗  ███████╗
//      ██╔══╝  ██╔══╝  ██╔══╝  ╚════██║
//      ██║     ███████╗███████╗███████║
//      ╚═╝     ╚══════╝╚══════╝╚══════╝
//----------------------------------------------
// Energetic     1%: Marketing
// Intelligent   1%: Development
// Independend   1%: Liquidity
// Social        1%: Future Operations
// Loyal         1%: Buyback-Burn
//----------------------------------------------
// Sell/Transfer 2%: Reflection
// Whale Sell    5%: Reflection
//----------------------------------------------


pragma solidity ^0.8.9;

// IERC20 interface taken from: https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/IERC20.sol
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

//Interface for our Distribution Tokens
interface IDistributionHolder {
    function returnHolder() external view returns (Holder[] memory);
}

//Holder struct for Distribution Tokens
struct Holder{
    address holderAddress;
    uint256 holderBalance;
}

// Context abstract contract taken from https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Context.sol
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

// SafeMath library taken from https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/math/SafeMath.sol
library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b <= a, errorMessage);
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
        return div(a, b, "SafeMath: division by zero");
    }

    function div(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        // assert(a == b * c + a % b); // There is no case in which this doesn't hold

        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero");
    }

    function mod(uint256 a, uint256 b, string memory errorMessage) internal pure returns (uint256) {
        require(b != 0, errorMessage);
        return a % b;
    }
}

// Address library taken from https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/utils/Address.sol
library Address {
    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance");

        (bool success, ) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted");
    }

    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCall(target, data, "Address: low-level call failed");
    }

    function functionCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, errorMessage);
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value
    ) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    function functionCallWithValue(
        address target,
        bytes memory data,
        uint256 value,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        require(isContract(target), "Address: call to non-contract");

        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function functionStaticCall(address target, bytes memory data) internal view returns (bytes memory) {
        return functionStaticCall(target, data, "Address: low-level static call failed");
    }

    function functionStaticCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal view returns (bytes memory) {
        require(isContract(target), "Address: static call to non-contract");

        (bool success, bytes memory returndata) = target.staticcall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function functionDelegateCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionDelegateCall(target, data, "Address: low-level delegate call failed");
    }

    function functionDelegateCall(
        address target,
        bytes memory data,
        string memory errorMessage
    ) internal returns (bytes memory) {
        require(isContract(target), "Address: delegate call to non-contract");

        (bool success, bytes memory returndata) = target.delegatecall(data);
        return _verifyCallResult(success, returndata, errorMessage);
    }

    function _verifyCallResult(
        bool success,
        bytes memory returndata,
        string memory errorMessage
    ) private pure returns (bytes memory) {
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errorMessage);
            }
        }
    }
}

// Ownable abstract contract taken from https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol
abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

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
    function renounceOwnership() public virtual onlyOwner {
        _setOwner(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _setOwner(newOwner);
    }

    function _setOwner(address newOwner) private {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

// IUniswapV2Factory interface taken from: https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/interfaces/IUniswapV2Factory.sol
interface IUniswapV2Factory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

// IUniswapV2Pair interface taken from: https://github.com/Uniswap/uniswap-v2-core/blob/master/contracts/interfaces/IUniswapV2Pair.sol
interface IUniswapV2Pair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

// IUniswapV2Router01 interface taken from: https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/interfaces/IUniswapV2Router01.sol
interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
}

// IUniswapV2Router02 interface taken from: https://github.com/Uniswap/uniswap-v2-periphery/blob/master/contracts/interfaces/IUniswapV2Router02.sol
interface IUniswapV2Router02 is IUniswapV2Router01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}


/**
 * @dev The official WenToken Smart Contract
 */
contract WenToken is Context, IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    // General Info
    string private _name     = "WenToken";
    string private _symbol   = "WEN";
    uint8  private _decimals = 9;

    // Liquidity Settings
    IUniswapV2Router02 public _pancakeswapV2Router; // The address of the PancakeSwap V2 Router
    address public _pancakeswapV2LiquidityPair;     // The address of the PancakeSwap V2 liquidity pairing for WEN/WBNB

    bool currentlySwapping;

    modifier lockSwapping {
        currentlySwapping = true;
        _;
        currentlySwapping = false;
    }

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 bnbReceived,
        uint256 tokensIntoLiqudity
    );

    // Addresses
    address payable public _marketingAddress = payable(0xb2ed81bB20E04E98Ab238B98C94E0dC82A99dc6e); // Marketing address used to pay for marketing
    address payable public _burnAddress      = payable(0x000000000000000000000000000000000000dEaD); // Burn address used to burn a portion of tokens

    address public _lastFrom;

    // Balances
    mapping (address => uint256) private _rOwned;
    mapping (address => uint256) private _tOwned;
    mapping (address => mapping (address => uint256)) private _allowances;

    // Exclusions
    mapping (address => bool) private _isExcludedFromFees;
    mapping (address => bool) private _isExcluded;
    address[] private _excluded;

    // Supply
    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal = 1 * 10**9 * 10**9; // 1 Billion
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _totalReflections; // Total reflections
    bool private _reflectionEnabled = false; // Is Reflection enabled: initial false

    //Distribution Variables
    address payable public _distributionTokenContractAddress = payable(0x56cf3526DbE2ec162D0Ad3bF4bb5535980A9Fd1A); //Contract for our WenDistributionToken
    uint256 private _distributionWalletChangedTime = 0;
    bool private _distributionWalletChanged = false;
    address private _newDistributionWallet;
    address payable public _wenTokenDistributionLockWallet = payable(0x23Fd8376d37a29E497C3E08f88B6143a747987e1); //Locked Wallet with WenToken that get distributed

    // Token Tax Settings
    uint256 public  _taxFee                      = 5;  // 5% tax
    uint256 public  _sellAndTransferTaxFee       = 7;  // 7% tax
    uint256 public  _whaleSellAndTransferTaxFee  = 10; // 10% tax
    uint256 private _previousTaxFee;

    // Token Limits
    uint256 public _maxTxAmount        = 1 * 10**9 * 10**9;  // 1 Billion
    uint256 public _tokenSwapThreshold = 500 * 10**3 * 10**9; // 500 Thousand

    // Timer Constants
    uint private constant DAY = 86400; // How many seconds in a day

    // Anti-Whale Settings
    uint256 public _whaleSellThreshold = 25 * 10**5 * 10**9;   // 2.5 Million
    uint    public _whaleSellTimer     = DAY;                 // 24 hours
    mapping (address => uint256) private _amountSold;
    mapping (address => uint) private _timeSinceFirstSell;


    // LIQUIDITY
    bool public _enableLiquidity = false; // Controls whether the contract will swap tokens


    constructor () {
        // Mint the total reflection balance to the deployer of this contract
        _rOwned[_msgSender()] = _rTotal;

        // Exclude the owner and the contract from paying fees
        _isExcludedFromFees[owner()] = true;
        _isExcludedFromFees[address(this)] = true;
        _isExcludedFromFees[_wenTokenDistributionLockWallet] = true;

        //Set up the pancakeswap V2 router
        IUniswapV2Router02 pancakeswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        _pancakeswapV2LiquidityPair = IUniswapV2Factory(pancakeswapV2Router.factory())
            .createPair(address(this), pancakeswapV2Router.WETH());
        _pancakeswapV2Router = pancakeswapV2Router;

        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    /**
     * @notice Required to recieve BNB from PancakeSwap V2 Router when swaping
     */
    receive() external payable {}

    /**
     * @notice Withdraws BNB from the contract
     */
    function withdrawBNB(uint256 amount) public onlyOwner() {
        if(amount == 0) payable(owner()).transfer(address(this).balance);
        else payable(owner()).transfer(amount);
    }

    /**
     * @notice Withdraws non-WEN tokens that are stuck as to not interfere with the liquidity
     */
    function withdrawForeignToken(address token) public onlyOwner() {
        require(address(this) != address(token), "Cannot withdraw native token");
        IERC20(address(token)).transfer(msg.sender, IERC20(token).balanceOf(address(this)));
    }

    /**
     * @notice Transfers BNB to an address
     */
    function transferBNBToAddress(address payable recipient, uint256 amount) private {
        recipient.transfer(amount);
    }

    /**
     * @notice Allows the contract to change the router, in the instance when PancakeSwap upgrades making the contract future proof
     */
    function setRouterAddress(address router) public onlyOwner() {
        // Connect to the new router
        IUniswapV2Router02 newPancakeSwapRouter = IUniswapV2Router02(router);

        // Grab an existing pair, or create one if it doesnt exist
        address newPair = IUniswapV2Factory(newPancakeSwapRouter.factory()).getPair(address(this), newPancakeSwapRouter.WETH());
        if(newPair == address(0)){
            newPair = IUniswapV2Factory(newPancakeSwapRouter.factory()).createPair(address(this), newPancakeSwapRouter.WETH());
        }
        _pancakeswapV2LiquidityPair = newPair;

        _pancakeswapV2Router = newPancakeSwapRouter;
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function totalSupply() external view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) external view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) external virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) external virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function _approve(address owner, address spender, uint256 amount) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function getTotalReflections() external view returns (uint256) {
        return _totalReflections;
    }

    function isExcludedFromFee(address account) external view returns(bool) {
        return _isExcludedFromFees[account];
    }

    function isExcludedFromReflection(address account) external view returns(bool) {
        return _isExcluded[account];
    }

    function amountSold(address account) external view returns (uint256) {
        return _amountSold[account];
    }

    function getTimeSinceFirstSell(address account) external view returns (uint) {
        return _timeSinceFirstSell[account];
    }

    function isReflectionEnabled() external view returns (bool) {
        return _reflectionEnabled;
    }

    function getLastFrom() external view returns (address) {
        return _lastFrom;
    }

    function getDistributionWalletChanged() external view returns (bool) {
        return _distributionWalletChanged;
    }

    function getDistributionHolderListLenth() external view returns(uint256){
        return IDistributionHolder(_distributionTokenContractAddress).returnHolder().length;
    }

    function excludeFromFee(address account) external onlyOwner() {
        _isExcludedFromFees[account] = true;
    }

    function includeInFee(address account) external onlyOwner() {
        _isExcludedFromFees[account] = false;
    }

    function setTaxFeePercent(uint256 taxFee) external onlyOwner() {
        _taxFee = taxFee;
    }

    function setSellTaxFeePerecent(uint256 taxFee) external onlyOwner() {
        _sellAndTransferTaxFee = taxFee;
    }

    function setWhaleSellTaxFeePerecent(uint256 taxFee) external onlyOwner() {
        _whaleSellAndTransferTaxFee = taxFee;
    }

    function setMaxTxAmount(uint256 maxTxAmount) external onlyOwner() {
        _maxTxAmount = maxTxAmount;
    }

    function setTokenSwapThreshold(uint256 tokenSwapThreshold) external onlyOwner() {
        _tokenSwapThreshold = tokenSwapThreshold;
    }

    function setMarketingAddress(address marketingAddress) external onlyOwner() {
        _marketingAddress = payable(marketingAddress);
    }

    function setLiquidity(bool b) external onlyOwner() {
        _enableLiquidity = b;
    }

    function setWhaleSellThreshold(uint256 amount) external onlyOwner() {
        _whaleSellThreshold = amount;
    }

    function setWhaleSellTimer(uint time) external onlyOwner() {
        _whaleSellTimer = time;
    }

    function setReflectionEnabled(bool isEnabled) external onlyOwner() {
        _reflectionEnabled = isEnabled;
    }

    function setDistributionContract(address distriContract) external onlyOwner() {
        _distributionWalletChangedTime = block.timestamp;
        _newDistributionWallet = payable(distriContract);
        _distributionWalletChanged = true;
    }

    function setDistributionContract() private {
        _distributionTokenContractAddress = payable(_newDistributionWallet);
    }

    /**
     * @notice Converts a token value to a reflection value
     */
    function reflectionFromToken(uint256 tAmount, bool deductTransferFee) public view returns(uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount,,,,) = _getValues(tAmount);
            return rAmount;
        } else {
            (,uint256 rTransferAmount,,,) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    /**
     * @notice Converts a reflection value to a token value
     */
    function tokenFromReflection(uint256 rAmount) public view returns(uint256) {
        require(rAmount <= _rTotal, "Amount must be less than total reflections");
        uint256 currentRate =  _getRate();
        return rAmount.div(currentRate);
    }

    /**
     * @notice Removes all fees and stores their previous values to be later restored
     */
    function removeAllFees() private {
        if(_taxFee == 0) return;

        _previousTaxFee = _taxFee;
        _taxFee = 0;
    }

    /**
     * @notice Restores the fees
     */
    function restoreAllFees() private {
        _taxFee = _previousTaxFee;
    }


    /**
     * @notice Collects all the necessary transfer values
     */
    function _getValues(uint256 tAmount) private view returns (uint256, uint256, uint256, uint256, uint256) {
        (uint256 tTransferAmount, uint256 tFee) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(tAmount, tFee, _getRate());
        return (rAmount, rTransferAmount, rFee, tTransferAmount, tFee);
    }

    /**
     * @notice Calculates transfer token values
     */
    function _getTValues(uint256 tAmount) private view returns (uint256, uint256) {
        uint256 tFee = tAmount.mul(_taxFee).div(100);
        uint256 tTransferAmount = tAmount.sub(tFee);
        return (tTransferAmount, tFee);
    }

    /**
     * @notice Calculates transfer reflection values
     */
    function _getRValues(uint256 tAmount, uint256 tFee, uint256 currentRate) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee);
        return (rAmount, rTransferAmount, rFee);
    }

    /**
     * @notice Calculates the rate of reflections to tokens
     */
    function _getRate() private view returns(uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    /**
     * @notice Gets the current supply values
     */
    function _getCurrentSupply() private view returns(uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_rOwned[_excluded[i]] > rSupply || _tOwned[_excluded[i]] > tSupply) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    /**
     * @notice Excludes an address from receiving reflections
     */
    function excludeFromReward(address account) external onlyOwner() {
        require(!_isExcluded[account], "Account is already excluded");
        if(_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    /**
     * @notice Includes an address back into the reflection system
     */
    function includeInReward(address account) external onlyOwner() {
        require(_isExcluded[account], "Account is already included");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account] = 0;
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

     /**
     * @notice Checks if destination wallet has Distribution tokens
     */
    function _checkDistributionTransaction(address to, uint256 amount) private view returns (bool){
        Holder[] memory holders = IDistributionHolder(_distributionTokenContractAddress).returnHolder();
        for (uint256 i = 0; i < holders.length; i++) {
            if(holders[i].holderAddress == to && amount <= holders[i].holderBalance){
                return true;
            }
        }
        return false;
    }

    /**
     * @notice Handles the before and after of a token transfer, such as taking fees and firing off a swap and liquify event
     */
    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        _lastFrom = from;

        //If the Distribution Address got changed, set it after 24h
        if(_distributionWalletChanged && (block.timestamp - _distributionWalletChangedTime) > DAY){
            _distributionTokenContractAddress = payable(_newDistributionWallet);
            _distributionWalletChanged = false;
        }

        //If transaction comes from Distribution Wallet, the receiver must have Distribution Tokens
        if(from == _wenTokenDistributionLockWallet){
            require(_checkDistributionTransaction(to, amount), "Wallet does not hold any Distribution Tokens");
        }

        // Only the owner of this contract can bypass the max transfer amount
        if(from != owner() && to != owner()) {
            require(amount <= _maxTxAmount, "Transfer amount exceeds the maxTxAmount.");
        }

        // Gets the contracts WEN balance for buybacks, development, liquidity and marketing
        uint256 tokenBalance = balanceOf(address(this));
        if(tokenBalance >= _maxTxAmount)
        {
            tokenBalance = _maxTxAmount;
        }

        // AUTO-LIQUIDITY MECHANISM
        // Check that the contract balance has reached the threshold required to execute a swap and liquify event
        // Do not execute the swap and liquify if there is already a swap happening
        // Do not allow the adding of liquidity if the sender is the PancakeSwap V2 liquidity pool
        if (_enableLiquidity && tokenBalance >= _tokenSwapThreshold && !currentlySwapping && from != _pancakeswapV2LiquidityPair) {
            tokenBalance = _tokenSwapThreshold;
            swapAndLiquify(tokenBalance);
        }

        // If any account belongs to _isExcludedFromFee account then remove the fee
        bool takeFee = !(_isExcludedFromFees[from] || _isExcludedFromFees[to]);

        // ANTI-WHALE TAX MECHANISM
        // If we are taking fees and sending tokens to the liquidity pool (i.e. a sell), check for anti-whale tax
        if (takeFee && from != _pancakeswapV2LiquidityPair) {

            // We will assume that the normal sell tax rate will apply
            uint256 fee = _sellAndTransferTaxFee;

            // Get the time difference in seconds between now and the first sell
            uint delta = block.timestamp.sub(_timeSinceFirstSell[from]);

            // Get the new total to see if it has spilled over the threshold
            uint256 newTotal = _amountSold[from].add(amount);

            // If a known wallet started their selling within the whale sell timer window, check if they're trying to spill over the threshold
            // If they are then increase the tax amount
            if (delta > 0 && delta < _whaleSellTimer && _timeSinceFirstSell[from] != 0) {
                if (newTotal > _whaleSellThreshold) {
                    fee = _whaleSellAndTransferTaxFee;
                }
                _amountSold[from] = newTotal;
            } else if (_timeSinceFirstSell[from] == 0 && newTotal > _whaleSellThreshold) {
                fee = _whaleSellAndTransferTaxFee;
                _amountSold[from] = newTotal;
            } else {
                // Otherwise we reset their sold amount and timer
                _timeSinceFirstSell[from] = block.timestamp;
                _amountSold[from] = amount;
            }

            // Set the tax rate to the sell tax rate, if the whale sell tax rate applies then we set that
            _previousTaxFee = _taxFee;
            _taxFee = fee;
        }

        // Remove fees completely from the transfer if either wallet are excluded
        if (!takeFee) {
            removeAllFees();
        }

        // Transfer the token amount from sender to receipient.
        _tokenTransfer(from, to, amount);

        // If we removed the fees for this transaction, then restore them for future transactions
        if (!takeFee) {
            restoreAllFees();
        }

        // If this transaction was a sell, and we took a fee, restore the fee amount back to the original buy amount
        if (takeFee && from != _pancakeswapV2LiquidityPair) {
            _taxFee = _previousTaxFee;
        }

    }

    /**
     * @notice Handles the actual token transfer
     */
    function _tokenTransfer(address sender, address recipient, uint256 tAmount) private {
        // Calculate the values required to execute a transfer
        (uint256 tTransferAmount, uint256 tFee) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount,) = _getRValues(tAmount, tFee, _getRate());

        // Transfer from sender to recipient
		if (_isExcluded[sender]) {
		    _tOwned[sender] = _tOwned[sender].sub(tAmount);
		}
		_rOwned[sender] = _rOwned[sender].sub(rAmount);

		if (_isExcluded[recipient]) {
            _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
		}
		_rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);

		// Reflect the fees or move it to the contract
		if (tFee > 0 ) {
            if(_reflectionEnabled && (_taxFee == _sellAndTransferTaxFee || _taxFee == _whaleSellAndTransferTaxFee)){
                uint256 tPortion = tFee.div(_taxFee);

                if(_taxFee == _sellAndTransferTaxFee){
                    //If Sell or Transfer - reflect 2%
                    tPortion = tPortion*2;
                }else{
                    //If Whale Sell or Transfer - reflect 5%
                    tPortion = tPortion*5;
                }

                if(tPortion > 0){
                    _reflectTokens(tPortion);
                    tFee = tFee - tPortion;
                }
            }
            // Take the rest of the taxed tokens for the other functions
            _takeTokens(tFee);
		}

        // Emit an event
        emit Transfer(sender, recipient, tTransferAmount);
    }


    /**
     * @notice Increases the rate of how many reflections each token is worth
     */
    function _reflectTokens(uint256 tFee) private {
        uint256 rFee = tFee.mul(_getRate());
        _rTotal = _rTotal.sub(rFee);
        _totalReflections = _totalReflections.add(tFee);
    }

    /**
     * @notice The contract takes a portion of tokens from taxed transactions
     */
    function _takeTokens(uint256 tTakeAmount) private {
        uint256 currentRate = _getRate();
        uint256 rTakeAmount = tTakeAmount.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rTakeAmount);
        if(_isExcluded[address(this)]) {
            _tOwned[address(this)] = _tOwned[address(this)].add(tTakeAmount);
        }
    }


    /**
     * @notice Generates BNB by selling tokens and pairs some of the received BNB with tokens to add and grow the liquidity pool
     */
    function swapAndLiquify(uint256 tokenAmount) private lockSwapping {
        // Split the contract balance into the swap portion and the liquidity portion
        uint256 tenth      = tokenAmount.div(10);     // 1/10 of the tokens, used for liquidity
        uint256 swapAmount = tokenAmount.sub(tenth); // 9/10 of the tokens, used to swap for BNB

        // Capture the contract's current BNB balance so that we know exactly the amount of BNB that the
        // swap creates. This way the liquidity event wont include any BNB that has been collected by other means.
        uint256 initialBalance = address(this).balance;

        // Swap 9/10s of WenToken for BNB
        swapTokensForBNB(swapAmount);

        // How much BNB did we just receive
        uint256 receivedBNB = address(this).balance.sub(initialBalance);

        // A nineth of the received BNB will be paired with the tenth of tokens left behind
        uint256 liquidityBNB = receivedBNB.div(9);

        // Add liquidity via the PancakeSwap V2 Router
        addLiquidity(tenth, liquidityBNB);

        // Send the remaining BNB to the marketing wallet
        transferBNBToAddress(_marketingAddress, receivedBNB.div(9).mul(8));

        emit SwapAndLiquify(swapAmount, liquidityBNB, tenth);
    }

    /**
     * @notice Swap tokens for BNB storing the resulting BNB in the contract
     */
    function swapTokensForBNB(uint256 tokenAmount) private {
        // Generate the Pancakeswap pair for DHT/WBNB
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _pancakeswapV2Router.WETH(); // WETH = WBNB on BSC

        _approve(address(this), address(_pancakeswapV2Router), tokenAmount);

        // Execute the swap
        _pancakeswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // Accept any amount of BNB
            path,
            address(this),
            block.timestamp.add(300)
        );
    }

    /**
     * @notice Adds liquidity to the PancakeSwap V2 LP
     */
    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
        // Approve token transfer to cover all possible scenarios
        _approve(address(this), address(_pancakeswapV2Router), tokenAmount);

        // Adds the liquidity and gives the LP tokens to the owner of this contract
        // The LP tokens need to be manually locked
        _pancakeswapV2Router.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0, // Take any amount of tokens (ratio varies)
            0, // Take any amount of BNB (ratio varies)
            owner(),
            block.timestamp.add(300)
        );
    }

    /**
     * @notice Allows a user to voluntarily reflect their tokens to everyone else
     */
    function reflect(uint256 tAmount) public {
        require(!_isExcluded[_msgSender()], "Excluded addresses cannot call this function");
        (uint256 rAmount,,,,) = _getValues(tAmount);
        _rOwned[_msgSender()] = _rOwned[_msgSender()].sub(rAmount);
        _rTotal = _rTotal.sub(rAmount);
        _totalReflections = _totalReflections.add(tAmount);
    }
}