/**
 *Submitted for verification at Etherscan.io on 2023-08-05
*/

// ██████  ███████ ██    ██  ██████  ██      ██    ██ ███████ ██  ██████  ███    ██                   
// ██   ██ ██      ██    ██ ██    ██ ██      ██    ██     ██  ██ ██    ██ ████   ██                  
// ██████  █████   ██    ██ ██    ██ ██      ██    ██   ██    ██ ██    ██ ██ ██  ██                   
// ██   ██ ██       ██  ██  ██    ██ ██      ██    ██  ██     ██ ██    ██ ██  ██ ██                   
// ██   ██ ███████   ████    ██████  ███████  ██████  ███████ ██  ██████  ██   ████    

// SAFU CONTRACT DEVELOPED BY REVOLUZION

//Revoluzion Ecosystem
//WEB: https://revoluzion.io
//DAPP: https://revoluzion.app

// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

/********************************************************************************************
  LIBRARY
********************************************************************************************/

library Address {
    
    // ERROR

    error AddressInsufficientBalance(address account);

    error AddressEmptyCode(address target);

    error FailedInnerCall();

    // FUNCTION
    
    function functionCall(address target, bytes memory data) internal returns (bytes memory) {
        return functionCallWithValue(target, data, 0, defaultRevert);
    }

    function functionCallWithValue(address target, bytes memory data, uint256 value, function() internal view customRevert) internal returns (bytes memory) {
        if (address(this).balance < value) {
            revert AddressInsufficientBalance(address(this));
        }
        (bool success, bytes memory returndata) = target.call{value: value}(data);
        return verifyCallResultFromTarget(target, success, returndata, customRevert);
    }

    function verifyCallResultFromTarget(address target, bool success, bytes memory returndata, function() internal view customRevert) internal view returns (bytes memory) {
        if (success) {
            if (returndata.length == 0) {
                if (target.code.length == 0) {
                    revert AddressEmptyCode(target);
                }
            }
            return returndata;
        } else {
            _revert(returndata, customRevert);
        }
    }

    function defaultRevert() internal pure {
        revert FailedInnerCall();
    }

    function _revert(bytes memory returndata, function() internal view customRevert) private view {
        if (returndata.length > 0) {
            assembly {
                let returndata_size := mload(returndata)
                revert(add(32, returndata), returndata_size)
            }
        } else {
            customRevert();
            revert FailedInnerCall();
        }
    }
}

library SafeERC20 {

    // LIBRARY

    using Address for address;

    // ERROR

    error SafeERC20FailedOperation(address token);

    error SafeERC20FailedDecreaseAllowance(address spender, uint256 currentAllowance, uint256 requestedDecrease);

    // FUNCTION

    function safeTransfer(IERC20 token, address to, uint256 value) internal {
        _callOptionalReturn(token, abi.encodeCall(token.transfer, (to, value)));
    }
    
    function _callOptionalReturn(IERC20 token, bytes memory data) private {
        bytes memory returndata = address(token).functionCall(data);
        if (returndata.length != 0 && !abi.decode(returndata, (bool))) {
            revert SafeERC20FailedOperation(address(token));
        }
    }
}

/********************************************************************************************
  INTERFACE
********************************************************************************************/

interface IERC20 {
    
    // EVENT 

    event Transfer(address indexed from, address indexed to, uint256 value);
    
    event Approval(address indexed owner, address indexed spender, uint256 value);

    // FUNCTION

    function name() external view returns (string memory);
    
    function symbol() external view returns (string memory);
    
    function decimals() external view returns (uint8);
    
    function totalSupply() external view returns (uint256);
    
    function balanceOf(address account) external view returns (uint256);
    
    function transfer(address to, uint256 amount) external returns (bool);
    
    function allowance(address owner, address spender) external view returns (uint256);
    
    function approve(address spender, uint256 amount) external returns (bool);
    
    function transferFrom(address from, address to, uint256 amount) external returns (bool);
}

interface IERC20Permit {
    
    // FUNCTION
    
    function permit(address owner, address spender, uint256 value, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external;

    function nonces(address owner) external view returns (uint256);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
}

interface IPair {

    // FUNCTION

    function token0() external view returns (address);

    function token1() external view returns (address);
}

interface IFactory {

    // FUNCTION

    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IRouter {

    // FUNCTION

    function WETH() external pure returns (address);
        
    function factory() external pure returns (address);
}

interface ICommonError {

    // ERROR

    error CannotUseCurrentAddress(address current);

    error CannotUseCurrentValue(uint256 current);

    error CannotUseCurrentState(bool current);

    error InvalidAddress(address invalid);

    error InvalidValue(uint256 invalid);
}

/********************************************************************************************
  ACCESS
********************************************************************************************/

abstract contract Ownable {
    
    // DATA

    address private _owner;

    // MODIFIER

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    // ERROR

    error InvalidOwner(address account);

    error UnauthorizedAccount(address account);

    // CONSTRUCCTOR

    constructor(address initialOwner) {
        _transferOwnership(initialOwner);
    }

    // EVENT
    
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    // FUNCTION
    
    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        if (owner() != msg.sender) {
            revert UnauthorizedAccount(msg.sender);
        }
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        if (newOwner == address(0)) {
            revert InvalidOwner(address(0));
        }
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

/********************************************************************************************
  TOKEN
********************************************************************************************/

contract OHearn is Ownable, ICommonError, IERC20 {

    // LIBRARY

    using SafeERC20 for IERC20;

    // DATA

    IRouter public router;

    string private constant NAME = "OHearn";
    string private constant SYMBOL = "OHEARN";

    uint8 private constant DECIMALS = 18;

    uint256 private _totalSupply;
        
    bool private constant ISOHEARN = true;

    bool public tradeEnabled = false;
    bool public presaleFinalized = false;

    address public constant ZERO = address(0);
    address public constant DEAD = address(0xdead);
    address public constant PROJECTOWNER = 0xBF48cdc6A8c4bba8C0BDB1106ea976bCe3B6be5a;
    
    address public pair;
    address public presaleFactory;
    address public presaleAddress;
    
    // MAPPING

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) public isPairLP;

    // ERROR

    error InsufficientBalance(uint256 balance);

    error InvalidTradeEnabledState(bool status);

    error PresaleAlreadyFinalized(bool status);

    // CONSTRUCTOR

    constructor() Ownable (msg.sender) {
        _mint(msg.sender, 1_000_000_000_000 * 10**DECIMALS);

        router = IRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        pair = IFactory(router.factory()).createPair(address(this), router.WETH());

        isPairLP[pair] = true;
    }

    // EVENT

    event UpdateRouter(address oldRouter, address newRouter, address caller, uint256 timestamp);

    event SetPresaleFactory(address adr, address caller, uint256 timestamp);

    event SetPresaleAddress(address adr, address caller, uint256 timestamp);

    // FUNCTION

    /* General */

    receive() external payable {}

    function enableTrading() external onlyOwner {
        if (tradeEnabled) { revert InvalidTradeEnabledState(tradeEnabled); }
        tradeEnabled = true;
        presaleFinalized = true;
    }

    /* Check */

    function isOHearn() external pure returns (bool) {
        return ISOHEARN;
    }

    function circulatingSupply() external view returns (uint256) {
        return totalSupply() - balanceOf(DEAD) - balanceOf(ZERO);
    }

    /* Update */

    function setPresaleFactory(address adr) external onlyOwner {
        if (presaleFinalized) { revert PresaleAlreadyFinalized(presaleFinalized); }
        if (adr == ZERO) { revert InvalidAddress(ZERO); }
        if (adr == presaleFactory) { revert CannotUseCurrentAddress(presaleFactory); }
        presaleFactory = adr;
        emit SetPresaleFactory(adr, msg.sender, block.timestamp);
    }

    function setPresaleAddress(address adr) external onlyOwner {
        if (presaleFinalized) { revert PresaleAlreadyFinalized(presaleFinalized); }
        if (adr == ZERO) { revert InvalidAddress(ZERO); }
        if (adr == presaleAddress) { revert CannotUseCurrentAddress(presaleAddress); }
        presaleAddress = adr;
        emit SetPresaleAddress(adr, msg.sender, block.timestamp);
    }

    /* ERC20 Standard */

    function name() external view virtual override returns (string memory) {
        return NAME;
    }
    
    function symbol() external view virtual override returns (string memory) {
        return SYMBOL;
    }
    
    function decimals() external view virtual override returns (uint8) {
        return DECIMALS;
    }
    
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }
    
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }
    
    function transfer(address to, uint256 amount) external virtual override returns (bool) {
        address provider = msg.sender;
        return _transfer(provider, to, amount);
    }
    
    function allowance(address provider, address spender) public view virtual override returns (uint256) {
        return _allowances[provider][spender];
    }
    
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        address provider = msg.sender;
        _approve(provider, spender, amount);
        return true;
    }
    
    function transferFrom(address from, address to, uint256 amount) external virtual override returns (bool) {
        address spender = msg.sender;
        _spendAllowance(from, spender, amount);
        return _transfer(from, to, amount);
    }
    
    function increaseAllowance(address spender, uint256 addedValue) external virtual returns (bool) {
        address provider = msg.sender;
        _approve(provider, spender, allowance(provider, spender) + addedValue);
        return true;
    }
    
    function decreaseAllowance(address spender, uint256 subtractedValue) external virtual returns (bool) {
        address provider = msg.sender;
        uint256 currentAllowance = allowance(provider, spender);
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(provider, spender, currentAllowance - subtractedValue);
        }

        return true;
    }
    
    function _mint(address account, uint256 amount) internal virtual {
        if (account == ZERO) { revert InvalidAddress(account); }

        _totalSupply += amount;
        unchecked {
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);
    }

    function _approve(address provider, address spender, uint256 amount) internal virtual {
        if (provider == ZERO) { revert InvalidAddress(provider); }
        if (spender == ZERO) { revert InvalidAddress(spender); }

        _allowances[provider][spender] = amount;
        emit Approval(provider, spender, amount);
    }
    
    function _spendAllowance(address provider, address spender, uint256 amount) internal virtual {
        uint256 currentAllowance = allowance(provider, spender);
        if (currentAllowance != type(uint256).max) {
            require(currentAllowance >= amount, "ERC20: insufficient allowance");
            unchecked {
                _approve(provider, spender, currentAllowance - amount);
            }
        }
    }
     
    function _transfer(address from, address to, uint256 amount) internal virtual returns (bool) {
        if (from == ZERO) { revert InvalidAddress(from); }
        if (to == ZERO) { revert InvalidAddress(to); }
        
        if (!tradeEnabled) {
            require(msg.sender == PROJECTOWNER || msg.sender == presaleFactory || msg.sender == owner() || msg.sender == presaleAddress, "ERC20: Only operator, owner or presale addresses can call this function since trading is not yet enabled.");

            if (from == owner()) {
                require(to != pair, "ERC20: Owner and operator are not allowed to sell if trading is not yet enabled.");
            }
        }

        require(_balances[from] >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = _balances[from] - amount;
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);

        return true;
    }

    /* Rescue */

    function wTokens(uint256 amount, address tokenAddress) external onlyOwner {
        uint256 wAmount = amount;

        if (tokenAddress == ZERO) {
            if (amount == 0) {
                wAmount = address(this).balance;
            }
            if(wAmount > address(this).balance) { revert InsufficientBalance(address(this).balance); }
            payable(msg.sender).transfer(wAmount);
            return;
        }

        if (amount == 0) {
            wAmount = IERC20(tokenAddress).balanceOf(address(this));
        }

        if(wAmount > IERC20(tokenAddress).balanceOf(address(this))) { revert InsufficientBalance(IERC20(tokenAddress).balanceOf(address(this))); }
        
        IERC20(tokenAddress).safeTransfer(msg.sender, wAmount);
    }
}