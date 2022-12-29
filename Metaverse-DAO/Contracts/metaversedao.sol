/**
 *Submitted for verification at BscScan.com on 2022-12-28
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

/**
 * @dev collections of functions ralted to the address type
 */
library Address {

    /**
     * @dev returns true if `account` is a contract
     */
    function isContract(address account) internal view returns(bool) {
        bytes32 codehash;
        bytes32 accountHash = 0xc5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470;
        assembly{
            codehash := extcodehash(account)
        }
        return (codehash != accountHash && codehash != 0x0);
    }

    /**
     * @dev replacement for solidity's `transfer`: sends `amount` wei to `recipient`,
     * forwarding all available gas and reverting on errors;
     */
    function sendValue(address payable recipient, uint256 amount) internal {
        require(address(this).balance >= amount, "Address: insufficient balance.");

        (bool success,) = recipient.call{value: amount}("");
        require(success, "Address: unable to send value, recipient may have reverted.");
    }

    /**
     * @dev performs a solidity function call using a low level `call`. A plain `call` is an
     * unsafe replacement for a function call: use this function instead.
     */
    function functionCall(address target, bytes memory data) internal returns(bytes memory) {
        return functionCall(target, data, "Address: low-level call failed.");
    }

    function functionCall(address target, bytes memory data, string memory errMsg) internal returns(bytes memory) {
        return _functionCallWithValue(target, data, 0, errMsg);
    }

    function functionCallWithValue(address target, bytes memory data, uint256 value) internal returns (bytes memory) {
        return functionCallWithValue(target, data, value, "Address: low-level call with value failed");
    }

    function functionCallWithValue(address target, bytes memory data, uint256 value, string memory errorMessage) internal returns (bytes memory) {
        require(address(this).balance >= value, "Address: insufficient balance for call");
        return _functionCallWithValue(target, data, value, errorMessage);
    }

    function _functionCallWithValue(address target, bytes memory data, uint256 weiValue, string memory errMsg) private returns(bytes memory) {
        require(isContract(target), "Address: call to non-contract.");

        (bool success, bytes memory returndata) = target.call{value : weiValue}(data);
        if (success) {
            return returndata;
        } else {
            // Look for revert reason and bubble it up if present
            if (returndata.length > 0) {
                // The easiest way to bubble the revert reason is using memory via assembly

                // solhint-disable-next-line no-inline-assembly
                assembly {
                    let returndata_size := mload(returndata)
                    revert(add(32, returndata), returndata_size)
                }
            } else {
                revert(errMsg);
            }
        }
    }

}



library IterableMapping {
    // Iterable mapping from address to uint;
    struct Map {
        address[] keys;
        mapping(address => uint) values;
        mapping(address => uint) indexOf;
        mapping(address => bool) inserted;
    }

    function get(Map storage map, address key) public view returns (uint) {
        return map.values[key];
    }

    function getIndexOfKey(Map storage map, address key) public view returns (int) {
        if(!map.inserted[key]) {
            return -1;
        }
        return int(map.indexOf[key]);
    }

    function getKeyAtIndex(Map storage map, uint index) public view returns (address) {
        return map.keys[index];
    }



    function size(Map storage map) public view returns (uint) {
        return map.keys.length;
    }

    function set(Map storage map, address key, uint val) public {
        if (map.inserted[key]) {
            map.values[key] = val;
        } else {
            map.inserted[key] = true;
            map.values[key] = val;
            map.indexOf[key] = map.keys.length;
            map.keys.push(key);
        }
    }

    function remove(Map storage map, address key) public {
        if (!map.inserted[key]) {
            return;
        }

        delete map.inserted[key];
        delete map.values[key];

        uint index = map.indexOf[key];
        uint lastIndex = map.keys.length - 1;
        address lastKey = map.keys[lastIndex];

        map.indexOf[lastKey] = index;
        delete map.indexOf[key];

        map.keys[index] = lastKey;
        map.keys.pop();
    }
}



// a library for performing various math operations
library Math {
    function min(uint x, uint y) internal pure returns (uint z) {
        z = x < y ? x : y;
    }

    // babylonian method (https://en.wikipedia.org/wiki/Methods_of_computing_square_roots#Babylonian_method)
    function sqrt(uint y) internal pure returns (uint z) {
        if (y > 3) {
            z = y;
            uint x = y / 2 + 1;
            while (x < z) {
                z = x;
                x = (y / x + x) / 2;
            }
        } else if (y != 0) {
            z = 1;
        }
    }
}



/**
 * @dev Wrappers over Solidity's arithmetic operations with added overflow
 * checks.
 *
 * Arithmetic operations in Solidity wrap on overflow. This can easily result
 * in bugs, because programmers usually assume that an overflow raises an
 * error, which is the standard behavior in high level programming languages.
 * `SafeMath` restores this intuition by reverting the transaction when an
 * operation overflows.
 *
 * Using this library instead of the unchecked operations eliminates an entire
 * class of bugs, so it's recommended to use it always.
 */
library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns(uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow.");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns(uint256) {
        return sub(a, b, "SafeMath: subtraction overflow.");
    }

    function sub(uint256 a, uint256 b, string memory errMsg) internal pure returns(uint256) {
        require(b <= a, errMsg);
        uint256 c = a - b;
        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns(uint256) {
        if(a == 0){
            return 0;
        }

        uint256 c = a * b;
        require(c/a == b, "SafeMath: mutiplication overflow.");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns(uint256) {
        return div(a, b, "SafeMath: division by zero.");
    }

    function div(uint256 a, uint256 b, string memory errMsg) internal pure returns(uint256) {
        require(b > 0, errMsg);
        uint256 c = a / b;
        return c;
    }

    function mod(uint256 a, uint256 b) internal pure returns (uint256) {
        return mod(a, b, "SafeMath: modulo by zero.");
    }

    function mod(uint256 a, uint256 b, string memory errMsg) internal pure returns(uint256) {
        require(b != 0, errMsg);
        return a % b;
    }

}



library SafeMathInt {
    function add(int256 a, int256 b) internal pure returns(int256) {
        int256 c = a + b;
        require((b >= 0 && c >= a) || (b < 0 && c < a));
        return c;
    }

    function sub(int256 a, int256 b) internal pure returns(int256) {
        require((b >= 0 && a - b <= a) || (b < 0 && a - b > a));
        return a - b;
    }

    function mul(int256 a, int256 b) internal pure returns(int256) {
        require(!(a == -2**255 && b == -1) && !(b == -2**255 && a == -1));
         int256 c = a * b;
         require((b == 0) || (c/b == a));
         return c;
    }

    function div(int256 a, int256 b) internal pure returns(int256){
        require(!(a == -2**255 && b == -1) && (b > 0));
        return a/b;
    }

    function toUint256Safe(int256 a) internal pure returns(uint256) {
        require(a >= 0);
        return uint256(a);
    }
}



library SafeMathUint {
    function toInt256Safe(uint256 a) internal pure returns(int256){
        int256 b = int256(a);
        require(b >= 0, "need >= 0");
        return b;
    }
}



interface IERC20 {

    /**
     * @dev returns the amount of tokens in existence.
     */
    function totalSupply() external view returns(uint256);

    /**
     * @dev returns the amount of tokens owned by account
     */
    function balanceOf(address account) external view returns(uint256);

    /**
     * @dev moves amount tokens from the call's account to recipient.
     * returns a bool value indicating whether the operation successed.
     */
    function transfer(address recipient, uint256 amount) external returns(bool);

    /**
     * @dev returns the remaining number of tokens that spender will be allowed to spend
     * on behalf of owner through {transferFrom}. this is zero by default.
     *
     * his value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns(uint256);

    /**
     * @dev sets amount as the allowance of spender over the caller's tokens.
     * returns a bool value indicating whether the operation is successed.
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
    function approve(address spender, uint256 amount) external returns(bool);

    /**
     * @dev moves amount tokens from sender to recipient using the allowance mechanism.
     * amount is then deducted from the caller's allowance.
     *
     * returns a boolean value indicating whether the operation successed.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns(bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);

}



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



interface IUniswapV2Router01 {
    function factory() external view returns (address);
    function WETH() external view returns (address);

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



interface IDividendPayingToken {

  function dividendOf(address _owner) external view returns(uint256);

  function withdrawDividend() external;

  event DividendsDistributed(
    address indexed from,
    uint256 weiAmount
  );

  event DividendWithdrawn(
    address indexed to,
    uint256 weiAmount
  );
}



interface IDividendPayingTokenOptional {
  function withdrawableDividendOf(address _owner) external view returns(uint256);

  function withdrawnDividendOf(address _owner) external view returns(uint256);

  function accumulativeDividendOf(address _owner) external view returns(uint256);
}



abstract contract Context {
    function _msgSender() internal view virtual returns(address payable) {
        return payable(msg.sender);
    }

    function _msgData() internal view virtual returns(bytes memory){
        this;   // silence state mutability warning without generating bytecode - see https://github.com/ethereum/solidity/issues/2691
        return msg.data;
    }
}



contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed _previousOwner, address indexed newOwner);

    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view returns(address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner.");
        _;
    }

    /**
    * @dev Leaves the contract without owner. It will not be possible to call
    * `onlyOwner` functions anymore. Can only be called by the current owner.
    */
    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnerShip(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is zero address.");

        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

}



contract ERC20 is Context, IERC20 {
    using SafeMath for uint256;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
        _decimals = 18;
    }

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns(string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns(uint8) {
        return _decimals;
    }

    function totalSupply() public view virtual override returns(uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns(uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public virtual override returns(bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns(uint256) {
       return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns(bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns(bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()].sub(amount, "ERC20: transfer amount exceeds allowance."));
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     */
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns(bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns(bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].sub(subtractedValue, "ERC20: decrease allowance bellow zero."));
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address.");
        _beforeTokenTransfer(sender, recipient, amount);
        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance.");
        _balances[recipient] = _balances[recipient].add(amount);
        emit Transfer(sender, recipient, amount);
    }

    /**
     * @dev creates `amount` tokens and assign them to `account`, increasing the total supply.
     */
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to zero address.");

        _beforeTokenTransfer(address(0), account, amount);
        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev destroys `amount` tokens from `account`, reducing the total supply.
     */
    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address.");

        _beforeTokenTransfer(account, address(0), amount);
        _balances[account] = _balances[account].sub(amount, "ERC20: burn amount exceeds balance.");
        _totalSupply = _totalSupply.sub(amount);
        emit Transfer(account, address(0), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner` s tokens.
     */
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address.");
        require(spender != address(0), "ERC20: approve to the zero address.");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Sets {decimals} to a value other than the default one of 18.
     */
    function _setupDecimals(uint8 decimals_) internal virtual {
        _decimals = decimals_;
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes minting and burning.
     */
    function _beforeTokenTransfer(address sender, address recipient, uint256 amount) internal virtual { }

}



contract DividendPayingToken is ERC20, IDividendPayingToken, IDividendPayingTokenOptional {
  using SafeMath for uint256;
  using SafeMathUint for uint256;
  using SafeMathInt for int256;


  uint256 constant internal magnitude = 2**128;

  uint256 internal magnifiedDividendPerShare;
  uint256 internal lastAmount;

  address public dividendToken = 0x55d398326f99059fF775485246999027B3197955;

  mapping(address => int256) internal magnifiedDividendCorrections;

  mapping(address => uint256) internal withdrawnDividends;

  uint256 public totalDividendsDistributed;


  uint256 public _dividendLimitUsd = 3 * 10 ** 18;

  constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {

  }

  receive() external payable { }



  function distributeDividends(uint256 amount) internal {
    require(totalSupply() > 0);

    if (amount > 0) {
      magnifiedDividendPerShare = magnifiedDividendPerShare.add(
        (amount).mul(magnitude) / totalSupply()
      );
      emit DividendsDistributed(msg.sender, amount);

      totalDividendsDistributed = totalDividendsDistributed.add(amount);
    }
  }

  function withdrawDividend() public virtual override {
    _withdrawDividendOfUser(payable(msg.sender));
  }

  function _withdrawDividendOfUser(address payable user) internal returns (uint256) {
    uint256 _withdrawableDividend = withdrawableDividendOf(user);

    if (_withdrawableDividend > _dividendLimitUsd) {
      withdrawnDividends[user] = withdrawnDividends[user].add(_withdrawableDividend);
      emit DividendWithdrawn(user, _withdrawableDividend);
      bool success = IERC20(dividendToken).transfer(user, _withdrawableDividend);

      if(!success) {
        withdrawnDividends[user] = withdrawnDividends[user].sub(_withdrawableDividend);
        return 0;
      }

      return _withdrawableDividend;
    }

    return 0;
  }


  function dividendOf(address _owner) public view override returns(uint256) {
    return withdrawableDividendOf(_owner);
  }

  function withdrawableDividendOf(address _owner) public view override returns(uint256) {
    return accumulativeDividendOf(_owner).sub(withdrawnDividends[_owner]);
  }

  function withdrawnDividendOf(address _owner) public view override returns(uint256) {
    return withdrawnDividends[_owner];
  }

  function accumulativeDividendOf(address _owner) public view override returns(uint256) {
      return magnifiedDividendPerShare.mul(balanceOf(_owner)).toInt256Safe()
      .add(magnifiedDividendCorrections[_owner]).toUint256Safe() / magnitude;

  }

  function _transfer(address from, address to, uint256 value) internal virtual override {
    require(false);

    int256 _magCorrection = magnifiedDividendPerShare.mul(value).toInt256Safe();
    magnifiedDividendCorrections[from] = magnifiedDividendCorrections[from].add(_magCorrection);
    magnifiedDividendCorrections[to] = magnifiedDividendCorrections[to].sub(_magCorrection);
  }

  function _mint(address account, uint256 value) internal override {
    super._mint(account, value);

    magnifiedDividendCorrections[account] = magnifiedDividendCorrections[account]
    .sub( (magnifiedDividendPerShare.mul(value)).toInt256Safe() );

  }

  function _burn(address account, uint256 value) internal override {
    super._burn(account, value);

    magnifiedDividendCorrections[account] = magnifiedDividendCorrections[account]
    .add( (magnifiedDividendPerShare.mul(value)).toInt256Safe() );
  }

  function _setBalance(address account, uint256 newBalance) internal {
    uint256 currentBalance = balanceOf(account);

    if(newBalance > currentBalance) {
      uint256 mintAmount = newBalance.sub(currentBalance);
      _mint(account, mintAmount);
    } else if(newBalance < currentBalance) {
      uint256 burnAmount = currentBalance.sub(newBalance);
      _burn(account, burnAmount);
    }
  }

}



contract DividendTracker is DividendPayingToken, Ownable {
    using SafeMath for uint256;
    using SafeMathInt for int256;
    using IterableMapping for IterableMapping.Map;

    IterableMapping.Map private tokenHoldersMap;
    uint256 public lastProcessedIndex;

    mapping (address => bool) public excludedFromDividends;

    mapping (address => uint256) public lastClaimTimes;

    uint256 public claimWait;
    uint256 public immutable minimumTokenBalanceForDividends;

    IUniswapV2Router02 public uniswapV2Router;

    event ExcludeFromDividends(address indexed account);
    event UnExcludeFromDividends(address indexed account);
    event ClaimWaitUpdated(uint256 indexed newValue, uint256 indexed oldValue);

    event Claim(address indexed account, uint256 amount, bool indexed automatic);

    event SendDividends(uint256 tokensSwapped,uint256 amount);

    constructor() DividendPayingToken("METADAO_Dividend", "METADAO_Dividend2.0") {
        claimWait = 30 * 60;
        minimumTokenBalanceForDividends = 0 * (10**19);
        uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    }

    function _transfer(address, address, uint256)  internal pure override {
        require(false, "METADAO_Dividend: No transfers allowed");
    }

    function withdrawDividend() public pure override {
        require(false, "METADAO_Dividend: withdrawDividend disabled.");
    }

    function excludeFromDividends(address account) external onlyOwner {
        require(!excludedFromDividends[account]);
        excludedFromDividends[account] = true;

        _setBalance(account, 0);
        tokenHoldersMap.remove(account);

        emit ExcludeFromDividends(account);
    }

    function updateClaimWait(uint256 newClaimWait) external onlyOwner {
        require(newClaimWait >= 300 && newClaimWait <= 86400, "METADAO_Dividend: claimWait must be updated to between 5 mins and 24 hours");
        require(newClaimWait != claimWait, "METADAO_Dividend: Cannot update claimWait to same value");
        emit ClaimWaitUpdated(newClaimWait, claimWait);
        claimWait = newClaimWait;
    }

    function getLastProcessedIndex() external view returns(uint256) {
        return lastProcessedIndex;
    }

    function getNumberOfTokenHolders() external view returns(uint256) {
        return tokenHoldersMap.keys.length;
    }


    function getAccount(address _account)
        public view returns (
            address account,
            int256 index,
            int256 iterationsUntilProcessed,
            uint256 withdrawableDividends,
            uint256 totalDividends,
            uint256 lastClaimTime,
            uint256 nextClaimTime,
            uint256 secondsUntilAutoClaimAvailable) {
        account = _account;

        index = tokenHoldersMap.getIndexOfKey(account);

        iterationsUntilProcessed = -1;

        if(index >= 0) {
            if(uint256(index) > lastProcessedIndex) {
                iterationsUntilProcessed = index.sub(int256(lastProcessedIndex));
            }
            else {
                uint256 processesUntilEndOfArray = tokenHoldersMap.keys.length > lastProcessedIndex ?
                                                        tokenHoldersMap.keys.length.sub(lastProcessedIndex) :
                                                        0;


                iterationsUntilProcessed = index.add(int256(processesUntilEndOfArray));
            }
        }


        withdrawableDividends = withdrawableDividendOf(account);
        totalDividends = accumulativeDividendOf(account);

        lastClaimTime = lastClaimTimes[account];

        nextClaimTime = lastClaimTime > 0 ?
                                    lastClaimTime.add(claimWait) :
                                    0;

        secondsUntilAutoClaimAvailable = nextClaimTime > block.timestamp ?
                                                    nextClaimTime.sub(block.timestamp) :
                                                    0;
    }

    function getAccountAtIndex(uint256 index)
        public view returns (
            address,
            int256,
            int256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256) {
        if(index >= tokenHoldersMap.size()) {
            return (0x0000000000000000000000000000000000000000, -1, -1, 0, 0, 0, 0, 0);
        }

        address account = tokenHoldersMap.getKeyAtIndex(index);

        return getAccount(account);
    }

    function canAutoClaim(uint256 lastClaimTime) private view returns (bool) {
        if(lastClaimTime > block.timestamp)  {
            return false;
        }

        return block.timestamp.sub(lastClaimTime) >= claimWait;
    }

    function setBalance(address payable account, uint256 newBalance) external onlyOwner {
        if(excludedFromDividends[account]) {
            return;
        }
        if(newBalance >= minimumTokenBalanceForDividends) {
            _setBalance(account, newBalance);
            tokenHoldersMap.set(account, newBalance);
        }
        else {
            _setBalance(account, 0);
            tokenHoldersMap.remove(account);
        }

        processAccount(account, true);

    }


    function process(uint256 gas) public onlyOwner returns (uint256, uint256, uint256) {
        uint256 numberOfTokenHolders = tokenHoldersMap.keys.length;

        if(numberOfTokenHolders == 0) {
            return (0, 0, lastProcessedIndex);
        }

        uint256 _lastProcessedIndex = lastProcessedIndex;

        uint256 gasUsed = 0;

        uint256 gasLeft = gasleft();

        uint256 iterations = 0;
        uint256 claims = 0;

        while(gasUsed < gas && iterations < numberOfTokenHolders) {
            _lastProcessedIndex++;

            if(_lastProcessedIndex >= tokenHoldersMap.keys.length) {
                _lastProcessedIndex = 0;
            }

            address account = tokenHoldersMap.keys[_lastProcessedIndex];

            if(canAutoClaim(lastClaimTimes[account])) {
                if(processAccount(payable(account), true)) {
                    claims++;
                }
            }

            iterations++;

            uint256 newGasLeft = gasleft();

            if(gasLeft > newGasLeft) {
                gasUsed = gasUsed.add(gasLeft.sub(newGasLeft));
            }

            gasLeft = newGasLeft;
        }

        lastProcessedIndex = _lastProcessedIndex;

        return (iterations, claims, lastProcessedIndex);
    }

    function processAccount(address payable account, bool automatic) public onlyOwner returns (bool) {
        uint256 amount = _withdrawDividendOfUser(account);

        if(amount > 0) {
            lastClaimTimes[account] = block.timestamp;
            emit Claim(account, amount, automatic);
            return true;
        }

        return false;
    }

    function getExcludedFromDividends(address account) public view returns(bool) {
        return excludedFromDividends[account];
    }

    function setDividendLimit(uint256 limit) public onlyOwner {
        _dividendLimitUsd = limit;
    }

    function setDividendTokenAddress(address newToken) public onlyOwner {
        require(newToken != address(0), "new address is zero address.");
        dividendToken = newToken;
    }

    function getWithdrawableDividendOf(address account) public view returns(uint256) {
        return withdrawableDividendOf(account);
    }

    function swapAndDistributeDividends(address token) public onlyOwner {
        uint256 usdt_before = IERC20(dividendToken).balanceOf(address(this));
        uint256 tokenAmount = IERC20(token).balanceOf(address(this));
        _swapTokensForUsdt(token, tokenAmount);
        uint256 usdt_after = IERC20(dividendToken).balanceOf(address(this));
        uint256 dividends = usdt_after.sub(usdt_before);
        distributeDividends(dividends);
        emit SendDividends(tokenAmount, dividends);
    }

    function _swapTokensForUsdt(address token, uint256 tokenAmount) private {
        address[] memory path = new address[](3);
        path[0] = token;
        path[1] = uniswapV2Router.WETH();
        path[2] = dividendToken;

        uniswapV2Router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp.add(180)
        );
    }


}



contract MetaverseDao is ERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => uint256) private _balances;
    address public pdcWbnbPair;// pair of this token and bnb
    address public usdtWbnbPair;// pair of usdt and bnb
    DividendTracker public dividendTracker;
    IUniswapV2Router02 public uniswapV2Router;

    address public router = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
    address public usdt = 0x55d398326f99059fF775485246999027B3197955;
    address public WBNB = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;
    address _blackhole = 0x000000000000000000000000000000000000dEaD;
    address public _divReceiver;

    bool private inSwap = false;
    uint256 private _maxTotal = 35 * 10 ** 7 * 10 ** 18 ;
    uint256 private _maxSell = 1 * 10 ** 5 * 10 ** 18;// max amount to sell
    uint256 public minimumAmountToSwap = 20 * 10 ** 18;// min (usdt) amount of tarcker to sell
    uint8 private _decimals = 18;
    uint256 public gasForProcessing = 300000;// gas for a dividend
    uint256 public highestSellTaxRate = 45;
    bool public enableFee = true;// Whether to charge transaction fees
    bool public isAutoDividend = true;// Whether to automatically distribute dividends
    uint256 constant internal priceMagnitude = 2 ** 64;
    uint256 public basePrice;
    uint256 public basePriceTimeInterval = 4320;
    uint256 public basePricePreMin = 180;
    uint256 public lastBasePriceTimestamp;
    uint256 public startTimestamp;
    uint256 public sellRateUpper = 100;
    uint256 public sellRateBelow = 200;
    uint256 public fixSellSlippage = 0;
    uint256 public currentSellRate = 0;

    constructor() ERC20("Metaverse-DAO", "METADAO2.0") {
        dividendTracker = new DividendTracker();
        _divReceiver = address(dividendTracker);
        uniswapV2Router = IUniswapV2Router02(router);
        WBNB = uniswapV2Router.WETH();
        startTimestamp = block.timestamp;

        _mint(owner(), _maxTotal);

        dividendTracker.excludeFromDividends(_blackhole);
        dividendTracker.excludeFromDividends(address(this));
        dividendTracker.excludeFromDividends(owner());
        dividendTracker.excludeFromDividends(_divReceiver);
        dividendTracker.excludeFromDividends(address(uniswapV2Router));

        _isExcludedFromFee[_blackhole] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[_divReceiver] = true;
        _isExcludedFromFee[address(uniswapV2Router)] = true;
    }


    //to recieve ETH from uniswapV2Router when swaping
    receive() external payable {}

    function _transfer(address from, address to, uint256 amount) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(from != to, "Sender and reciever must be different");
        require(amount > 0, "Transfer amount must be greater than zero");

        //check max sell amount when selling, exclude tracker and owner
        if(to == pdcWbnbPair && from != _divReceiver && from != owner()) {
            require(amount <= _maxSell, "Sell amount reach maximum.");
        }

        //check and update pairs
        _checkLps();

        if((from == pdcWbnbPair || to == pdcWbnbPair) && enableFee) {
            _updateBasePrice();
            currentSellRate = _getSellTaxRate();
        }

        //Sell tokens in the tracker when sell base token
        if(to == pdcWbnbPair){
            if(!inSwap){
                inSwap = true;
                if(from != _divReceiver && isAutoDividend){
                    _swapDividend();
                }
                inSwap = false;
            }
        }

        if(to == pdcWbnbPair){
            if(_isExcludedFromFee[from] || !enableFee){
                super._transfer(from, to, amount);
            } else {
                _transferSellStandard(from, to, amount);
            }
        } else {
            super._transfer(from, to, amount);
        }

        try dividendTracker.setBalance(payable(from), balanceOf(from)) {} catch {}
        try dividendTracker.setBalance(payable(to), balanceOf(to)) {}  catch {}

        if((from == pdcWbnbPair || to == pdcWbnbPair) && !inSwap && isAutoDividend) {
            uint256 gas = gasForProcessing;

            try dividendTracker.process(gas) returns (uint256 iterations, uint256 claims, uint256 lastProcessedIndex) {
                emit ProcessedDividendTracker(iterations, claims, lastProcessedIndex, true, gas, tx.origin);
            } catch {}
        }
    }

    function _checkLps() private {
        //create a uniswap pair for this new token
        address _pdcWbnbPair = IUniswapV2Factory(uniswapV2Router.factory()).getPair(address(this), WBNB);
        if (pdcWbnbPair != _pdcWbnbPair) {
            pdcWbnbPair = _pdcWbnbPair;
            dividendTracker.excludeFromDividends(address(_pdcWbnbPair));
        }

        address _usdtWbnbPair = IUniswapV2Factory(uniswapV2Router.factory()).getPair(address(usdt), WBNB);
        if (usdtWbnbPair != _usdtWbnbPair) {
            usdtWbnbPair = _usdtWbnbPair;
            dividendTracker.excludeFromDividends(address(_usdtWbnbPair));
        }
    }

    function _updateBasePrice() private {
        (uint256 _pdcReserve, uint256 _wbnbReserve) = _getPdcWbnbReserves();
        if(_pdcReserve <= 0 || _wbnbReserve <= 0) return;

        uint256 _currentPrice = getLpPriceNow();
        if(lastBasePriceTimestamp == 0) {
            lastBasePriceTimestamp = block.timestamp;
            basePrice = _currentPrice;
            return;
        }

        uint256 lastTimeMin = lastBasePriceTimestamp.div(60);
        uint256 currentTimeMin = block.timestamp.div(60);
        if(lastTimeMin == currentTimeMin) return;

        uint256 startMin = startTimestamp.div(60);
        uint256 minSinceBegin = currentTimeMin.sub(startMin).add(1);
        uint256 timeInterval = basePriceTimeInterval;

        if (currentTimeMin > lastTimeMin) {
            uint256 minSinceLast = currentTimeMin.sub(lastTimeMin);
            if (minSinceBegin > timeInterval) {
                if (minSinceLast > timeInterval) {
                    basePrice = _currentPrice;
                } else {
                    basePrice = basePrice.mul(timeInterval.sub(minSinceLast)).div(timeInterval).add(_currentPrice.mul(minSinceLast).div(timeInterval));
                }
            } else {
                uint256 denominator = minSinceBegin.add(basePricePreMin);
                basePrice = basePrice.mul(denominator.sub(minSinceLast)).div(denominator).add(_currentPrice.mul(minSinceLast).div(denominator));
            }
        }

        lastBasePriceTimestamp = block.timestamp;
    }

    function getLpPriceNow() public view returns(uint256) {
        (uint112 pwreserve0, uint112 pwreserve1, ) = IUniswapV2Pair(pdcWbnbPair).getReserves();
        if(pwreserve0 == 0 || pwreserve1 == 0){
            return 0;
        }
        address pwtoken0 = IUniswapV2Pair(pdcWbnbPair).token0();
        uint256 pdPriceInWbnb;
        if(pwtoken0 == address(this)){
            pdPriceInWbnb = uint256(pwreserve1).mul(priceMagnitude).div(uint256(pwreserve0));
        } else {
            pdPriceInWbnb = uint256(pwreserve0).mul(priceMagnitude).div(uint256(pwreserve1));
        }

        (uint112 uwreserve0, uint112 uwreserve1, ) = IUniswapV2Pair(usdtWbnbPair).getReserves();
        if(uwreserve0 == 0 || uwreserve1 == 0){
            return 0;
        }
        address uwtoken0 = IUniswapV2Pair(usdtWbnbPair).token0();
        uint256 wbnbPriceInUsdt;
        if(uwtoken0 == WBNB){
            wbnbPriceInUsdt = uint256(uwreserve1).mul(priceMagnitude).div(uint256(uwreserve0));
        } else {
            wbnbPriceInUsdt = uint256(uwreserve0).mul(priceMagnitude).div(uint256(uwreserve1));
        }

        return pdPriceInWbnb.mul(wbnbPriceInUsdt).div(priceMagnitude);
    }

    function _getPdcWbnbReserves() private view returns(uint256 _pdcReserve, uint256 _wbnbReserve) {
        (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pdcWbnbPair).getReserves();
        address token0 = IUniswapV2Pair(pdcWbnbPair).token0();
        if(token0 == address(this)){
            _pdcReserve = uint256(reserve0);
            _wbnbReserve = uint256(reserve1);
        } else {
            _pdcReserve = uint256(reserve1);
            _wbnbReserve = uint256(reserve0);
        }
    }

    function _getWbnbUsdtReserves() private view returns(uint256 _wbnbReserve, uint256 _usdtReserve) {
        (uint112 reserve0, uint112 reserve1,) = IUniswapV2Pair(usdtWbnbPair).getReserves();
        address token0 = IUniswapV2Pair(usdtWbnbPair).token0();
        if (token0 == WBNB) {
            _wbnbReserve = uint256(reserve0);
            _usdtReserve = uint256(reserve1);
        } else {
            _wbnbReserve = uint256(reserve1);
            _usdtReserve = uint256(reserve0);
        }
    }

    function _getAmountOutUsdt(uint256 tokenAmount) private view returns (uint256) {
        if (tokenAmount <= 0) return 0;
        (uint256 _pdcReserve, uint256 _wbnbReserve) = _getPdcWbnbReserves();
        if (_wbnbReserve <= 0 || _pdcReserve <= 0) return 0;
        uint256 wbnbOut = uint256(_getAmountOut(tokenAmount, _pdcReserve, _wbnbReserve));

        (uint256 _wbnbReserve1, uint256 _usdtReserve) = _getWbnbUsdtReserves();
        if (_wbnbReserve1 <= 0 || _usdtReserve <= 0) return 0;
        return uint256(_getAmountOut(wbnbOut, _wbnbReserve1, _usdtReserve));
    }

    function _getAmountOutWbnb(uint256 tokenAmount) private view returns (uint256) {
        if (tokenAmount <= 0) return 0;
        (uint256 _pdcReserve, uint256 _wbnbReserve) = _getPdcWbnbReserves();
        if (_wbnbReserve <= 0 || _pdcReserve <= 0) return 0;
        return uint256(_getAmountOut(tokenAmount, _pdcReserve, _wbnbReserve));
    }

    function _getAmountInPd(uint256 amountOut) private view returns(uint256){
        (uint256 _pdcReserve, uint256 _wbnbReserve) = _getPdcWbnbReserves();
        if (_wbnbReserve <= 0 || _pdcReserve <= 0) return 0;
        return uint256(_getAmountIn(amountOut, _pdcReserve, _wbnbReserve));
    }

    function _getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) private pure returns (uint amountIn) {
        if (amountOut <= 0) return 0;
        if (reserveIn <= 0) return 0;
        if (reserveOut <= 0) return 0;
        uint numerator = reserveIn.mul(amountOut).mul(10000);
        uint denominator = reserveOut.sub(amountOut).mul(9975);
        amountIn = (numerator / denominator).add(1);
    }

    function _getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) private pure returns (uint amountOut) {
        if (amountIn <= 0) return 0;
        if (reserveIn <= 0) return 0;
        if (reserveOut <= 0) return 0;
        uint amountInWithFee = amountIn.mul(9975);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(10000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    // Sell tokens in the tracker
    function _swapDividend() private {
        uint256 divBal = balanceOf(_divReceiver);
        uint256 divBalInUsdt = _getAmountOutUsdt(divBal);
        if (divBalInUsdt >= minimumAmountToSwap) {
            _approve(address(dividendTracker), address(uniswapV2Router), divBal + 10000);
            dividendTracker.swapAndDistributeDividends(address(this));
        }
    }

    function _transferSellStandard(address from, address to, uint256 amount) private {
        uint256 totalFee = _getSellFees(amount);
        uint256 transferAmount = amount.sub(totalFee);

        super._transfer(from, _divReceiver, totalFee);
        super._transfer(from, to, transferAmount);
    }

    function _getSellFees(uint256 amount) private view returns (uint256) {
        uint256 amountOutWbnb = _getAmountOutWbnb(amount);
        uint256 amountOutWbnbAfterFee = amountOutWbnb.sub(amountOutWbnb.mul(currentSellRate).div(10000));
        uint256 amountInPd = _getAmountInPd(amountOutWbnbAfterFee);
        uint256 fee = amount.sub(amountInPd);
        return fee;
    }

    function _getSellTaxRate() private view returns (uint256) {
        if(fixSellSlippage > 0){
            return _convertToSellSlippage(fixSellSlippage);
        }

        uint256 rate = getBasePriceRate();
        if (rate == 0 || rate == 1000) {
            return _convertToSellSlippage(100);
        }
        uint256 diff;
        uint256 rateToReturn;
        if (rate > 1000) {
            diff = rate.sub(1000);
            rateToReturn = diff.mul(sellRateUpper).div(100).add(100);
            if (rateToReturn > highestSellTaxRate.mul(10)) {
                return _convertToSellSlippage(highestSellTaxRate.mul(10));
            } else {
                return _convertToSellSlippage(rateToReturn);
            }
        }

        diff = uint256(1000).sub(rate);
        rateToReturn = diff.mul(sellRateBelow).div(100).add(100);
        if (rateToReturn > highestSellTaxRate.mul(10)) {
            return _convertToSellSlippage(highestSellTaxRate.mul(10));
        } else {
            return _convertToSellSlippage(rateToReturn);
        }
    }

    function getSellTaxRate() public view returns (uint256) {
        if(fixSellSlippage > 0){
            return (fixSellSlippage);
        }

        uint256 rate = getBasePriceRate();
        if (rate == 0 || rate == 1000) {
            return (100);
        }
        uint256 diff;
        uint256 rateToReturn;
        if (rate > 1000) {
            diff = rate.sub(1000);
            rateToReturn = diff.mul(sellRateUpper).div(100).add(100);
            if (rateToReturn > highestSellTaxRate.mul(10)) {
                return (highestSellTaxRate.mul(10));
            } else {
                return (rateToReturn);
            }
        }

        diff = uint256(1000).sub(rate);
        rateToReturn = diff.mul(sellRateBelow).div(100).add(100);
        if (rateToReturn > highestSellTaxRate.mul(10)) {
            return (highestSellTaxRate.mul(10));
        } else {
            return (rateToReturn);
        }
    }

    function _convertToSellSlippage(uint256 taxRate) private pure returns(uint256) {
        return uint256(10000).sub(uint256(10000000).div(uint256(1000).add(taxRate)));
    }

    function getBasePriceRate() public view returns (uint256) {
        uint256 basePriceNow = getBasePriceNow();
        if (basePriceNow == 0) return 0;
        uint256 lpPrice = getLpPriceNow();
        if (lpPrice == 0) return 0;
        return lpPrice.mul(1000).div(basePriceNow);
    }

    function getBasePriceNow() public view returns(uint256) {
        uint256 _currentLpPrice = getLpPriceNow();
        if (basePrice == 0) return _currentLpPrice;
        uint256 lastTimeMin = lastBasePriceTimestamp.div(60);
        uint256 currentTimeMin = block.timestamp.div(60);
        uint256 timeInterval = basePriceTimeInterval;
        if (currentTimeMin == lastTimeMin) {
            return basePrice;
        } else {
            uint256 startMin = uint256(startTimestamp).div(60);
            uint256 minSinceBegin = currentTimeMin.sub(startMin).add(1);
            uint256 minSinceLast = currentTimeMin.sub(lastTimeMin);
            if (minSinceBegin > timeInterval) {
                if(minSinceLast > timeInterval) {
                    return _currentLpPrice;
                } else {
                    return basePrice.mul(timeInterval.sub(minSinceLast)).div(timeInterval).add(_currentLpPrice.mul(minSinceLast).div(timeInterval));
                }
            } else {
                uint256 denominator = minSinceBegin.add(basePricePreMin);
                return basePrice.mul(denominator.sub(minSinceLast)).div(denominator).add(_currentLpPrice.mul(minSinceLast).div(denominator));
            }
        }
    }

    function setBasePriceTimeInterval(uint256 _basePriceTimeInterval) public onlyOwner{
        basePriceTimeInterval = _basePriceTimeInterval;
    }

    function setHighestSellTaxRate (uint256 _highestSellTaxRate) public onlyOwner{
        highestSellTaxRate = _highestSellTaxRate;
    }

    function setMinimumAmountToSwap(uint256 _minimumAmountToSwap) public onlyOwner{
        minimumAmountToSwap = _minimumAmountToSwap;
    }

    function setMaxSell(uint256 __maxSellAmount) public onlyOwner{
        _maxSell = __maxSellAmount;
    }

    function setIsAutoDividend(bool _isAutoDividend) public onlyOwner{
        isAutoDividend = _isAutoDividend;
    }

    function updateDividendTracker(address newAddress) public onlyOwner {
        require(newAddress != address(dividendTracker), "The dividend tracker already has that address");

        DividendTracker newDividendTracker = DividendTracker(payable(newAddress));

        require(newDividendTracker.owner() == address(this), "The new dividend tracker must be owned by the this token contract");

        newDividendTracker.excludeFromDividends(_blackhole);
        newDividendTracker.excludeFromDividends(owner());
        newDividendTracker.excludeFromDividends(address(this));
        newDividendTracker.excludeFromDividends(address(newDividendTracker));
        newDividendTracker.excludeFromDividends(address(uniswapV2Router));
        newDividendTracker.excludeFromDividends(pdcWbnbPair);
        newDividendTracker.excludeFromDividends(usdtWbnbPair);

        _divReceiver = address(newDividendTracker);
        _isExcludedFromFee[_divReceiver] = true;

        dividendTracker = newDividendTracker;
    }

    function excludeFromFees(address _account, bool _excluded) public onlyOwner {
        require(_isExcludedFromFee[_account] != _excluded, "Account is already the value of 'excluded'");
        _isExcludedFromFee[_account] = _excluded;
        emit ExcludeFromFees(_account, _excluded);
    }

    function updateGasForProcessing(uint256 _newValue) public onlyOwner {
        require(_newValue >= 200000 && _newValue <= 500000, "gasForProcessing must be between 200,000 and 500,000");
        require(_newValue != gasForProcessing, "Cannot update gasForProcessing to same value");
        gasForProcessing = _newValue;
        emit GasForProcessingUpdated(_newValue, gasForProcessing);
    }

    function setEnableFee(bool _enableFee) public onlyOwner{
        enableFee = _enableFee;
    }

    function getExcludeFromFee(address addr) public view returns(bool) {
        return _isExcludedFromFee[addr];
    }

    function updateFixSellSlippage(uint256 _fixSellSlippage) public onlyOwner{
        fixSellSlippage = _fixSellSlippage;
    }

    function dividendTokenBalanceOf(address account) public view returns (uint256) {
        return dividendTracker.balanceOf(account);
    }

    function getExcludedFromDividends(address account) public view returns (bool){
        return dividendTracker.getExcludedFromDividends(account);
    }

    function setDividendLimit(uint256 limit) public onlyOwner{
        dividendTracker.setDividendLimit(limit);
    }

    function setDividendToken(address newToken) public onlyOwner{
        dividendTracker.setDividendTokenAddress(newToken);
    }

    function updateClaimWait(uint256 claim) public onlyOwner{
        dividendTracker.updateClaimWait(claim);
    }

    function getWithdrawableDividendOf(address account) public view returns(uint256) {
        return dividendTracker.withdrawableDividendOf(account);
    }

    function excludeFromDividends(address addr) public onlyOwner{
        dividendTracker.excludeFromDividends(addr);
    }

    function withdrawableDividendOf(address addr) public view returns(uint256) {
        return dividendTracker.withdrawableDividendOf(addr);
    }

    function withdrawnDividendOf(address addr) public view returns(uint256) {
        return dividendTracker.withdrawnDividendOf(addr);
    }

    function setSellRateUpper(uint256 newTax) public onlyOwner{
        sellRateUpper = newTax;
    }

    function setSellRateBelow(uint256 newTax) public onlyOwner{
        sellRateBelow = newTax;
    }





    event ProcessedDividendTracker(
        uint256 iterations,
        uint256 claims,
        uint256 lastProcessedIndex,
        bool indexed automatic,
        uint256 gas,
        address indexed processor
    );
    event GasForProcessingUpdated(uint256 indexed newValue, uint256 indexed oldValue);
    event ExcludeFromFees(address indexed account, bool isExcluded);

}