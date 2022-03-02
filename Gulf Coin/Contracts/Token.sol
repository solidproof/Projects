// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Token is Ownable, IERC20 {
    uint private constant SECONDS_PER_DAY = 24 * 60 * 60;
    uint private constant SECONDS_PER_HOUR = 60 * 60;
    uint private constant SECONDS_PER_MINUTE = 60;
    int private constant OFFSET19700101 = 2440588;

    using SafeMath for uint256;
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;

    string constant private _name = "Gulf Coin";
    string constant private _symbol = "GULF";
    uint8 constant private _decimals = 18;
    uint256 constant private _initialSupply = 10000000000*10**18;
    uint256 private _totalSupply;

    uint constant private burnRate = 1; // %1
    bool public autoBurn = false;

    uint public firstMint_Date_TimeStamp = timestampFromDateTime(2022, 6, 15, 23, 59, 59);
    bool public firstMint_Sent = false;
    uint public secondMint_Date_TimeStamp = timestampFromDateTime(2023, 1, 1, 23, 59, 59);
    bool public secondMint_Sent = false;
    uint public thirdMint_Date_TimeStamp = timestampFromDateTime(2023, 6, 1, 23, 59, 59);
    bool public thirdMint_Sent = false;
    uint public fourthMint_Date_TimeStamp = timestampFromDateTime(2024, 1, 1, 23, 59, 59);
    bool public fourthMint_Sent = false;
    uint public fifthMint_Date_TimeStamp = timestampFromDateTime(2024, 6, 1, 23, 59, 59);
    bool public fifthMint_Sent = false;
    uint public sixthMint_Date_TimeStamp = timestampFromDateTime(2025, 1, 1, 23, 59, 59);
    bool public sixthMint_Sent = false;
    uint public seventhMint_Date_TimeStamp = timestampFromDateTime(2025, 6, 1, 23, 59, 59);
    bool public seventhMint_Sent = false;

    uint public _now = block.timestamp;

    event ManualBurn(address from, uint256 amount);
    event ManualMint(address from, uint256 amount);

    constructor () {
         _totalSupply += _initialSupply;
        _mint(_msgSender(), 3000000000*10**18);
        _mint(address(this), 7000000000*10**18);
    }
    /* EXCLUSIVE FUNCTIONS */
    function autoBurn_On() public virtual onlyOwner {
        autoBurn = true;
    }
    function autoBurn_Off() public virtual onlyOwner {
        autoBurn = false;
    }
    function manual_burn(uint256 amount) public virtual onlyOwner {
        require(_balances[address(this)] >= amount, "Contract balance cannot be below zero after burn.");
        require(_totalSupply.sub(amount) >= 0, "Total supply cannot be below zero.");
        _burn(address(this), amount);
        emit ManualBurn(address(this), amount);
    }
    function manual_mint(uint256 amount) public virtual onlyOwner {
        require(_totalSupply + amount <= _initialSupply, "Total supply cannot be more than 10000000000.");
        _mint(_msgSender(), amount);
        _totalSupply += amount;
        emit ManualMint(_msgSender(), amount);
    }
    /* EXCLUSIVE FUNCTIONS */
    /* CORE FUNCTIONS */
    function _mint(address account, uint256 amount) internal {
        require(amount != 0);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }
    function burn(uint256 amount) public virtual {
        _burn(_msgSender(), amount);
    }
    function _burn(address account, uint256 amount) internal {
        require(amount != 0);
        require(amount <= _balances[account]);
        _totalSupply = _totalSupply.sub(amount);
        _balances[account] = _balances[account].sub(amount);
        emit Transfer(account, address(0), amount);
    }
    function name() public view virtual returns (string memory) {
        return _name;
    }
    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }
    function decimals() public view virtual returns (uint8) {
        return _decimals;
    }
    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }
    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }
    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        if (autoBurn == true) {
            if (_msgSender() == owner()){
                _transfer(_msgSender(), recipient, amount);
            }else{
                _burn(_msgSender(), amount.div(100*burnRate));
                _transfer(_msgSender(), recipient, amount.sub(amount.div(100*burnRate)));
            }
        }else{
            _transfer(_msgSender(), recipient, amount);
        }

        return true;
    }
    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }
    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }
    function transferFrom(address sender, address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }
    function increaseAllowance(address spender, uint256 addedValue) public virtual returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }
    function decreaseAllowance(address spender, uint256 subtractedValue) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "ERC20: decreased allowance below zero");
        unchecked {
            _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        }

        return true;
    }
    function _transfer(address sender, address recipient, uint256 amount) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");

        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
    }
    function _approve(address owner, address spender, uint256 amount) internal virtual {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }
    /* CORE FUNCTIONS */


    /* DATE FUNCTIONS */
    function _daysFromDate(uint year, uint month, uint day) internal pure returns (uint _days) {
        require(year >= 1970);
        int _year = int(year);
        int _month = int(month);
        int _day = int(day);

        int __days = _day
          - 32075
          + 1461 * (_year + 4800 + (_month - 14) / 12) / 4
          + 367 * (_month - 2 - (_month - 14) / 12 * 12) / 12
          - 3 * ((_year + 4900 + (_month - 14) / 12) / 100) / 4
          - OFFSET19700101;

        _days = uint(__days);
    }
    function timestampFromDateTime(uint year, uint month, uint day, uint hour, uint minute, uint second) internal pure returns (uint timestamp) {
        timestamp = _daysFromDate(year, month, day) * SECONDS_PER_DAY + hour * SECONDS_PER_HOUR + minute * SECONDS_PER_MINUTE + second;
    }
    function updateDateNow() public virtual onlyOwner {
        _now = block.timestamp;
    }
    /* DATE FUNCTIONS */

    /* OPEN THE LIQ LOCKS */
    function firstMintExecute() public virtual onlyOwner returns (bool) {
        require(firstMint_Date_TimeStamp <= _now, "First one is not there yet");
        require(firstMint_Sent == false, "First one has been sent before");
        require(_totalSupply + 1000000000*10**18 <= _initialSupply, "Total supply cannot be more than 10000000000.");
        require(address(this).balance >= 1000000000*10**18, "You need to have at least 1000000000 to mint.");
        _transfer(address(this), owner(), 1000000000*10**18);
        firstMint_Sent = true;
        return true;
    }
    function secondMintExecute() public virtual onlyOwner returns (bool) {
        require(secondMint_Date_TimeStamp <= _now, "Second one is not there yet");
        require(secondMint_Sent == false, "Second one has been sent before");
        require(_totalSupply + 1500000000*10**18 <= _initialSupply, "Total supply cannot be more than 10000000000.");
        require(address(this).balance >= 1500000000*10**18, "You need to have at least 1500000000 to mint.");
        _transfer(address(this), owner(), 1500000000*10**18);
        secondMint_Sent = true;
        return true;
    }
    function thirdMintExecute() public virtual onlyOwner returns (bool) {
        require(thirdMint_Date_TimeStamp <= _now, "Third one is not there yet");
        require(thirdMint_Sent == false, "Third one has been sent before");
        require(_totalSupply + 10000000000*10**18 <= _initialSupply, "Total supply cannot be more than 10000000000.");
        require(address(this).balance >= 1500000000*10**18, "You need to have at least 1500000000 to mint.");
        _transfer(address(this), owner(), 1500000000*10**18);
        thirdMint_Sent = true;
        return true;
    }
    function fourthMintExecute() public virtual onlyOwner returns (bool) {
        require(fourthMint_Date_TimeStamp <= _now, "Fourth one is not there yet");
        require(fourthMint_Sent == false, "Fourth one has been sent before");
        require(_totalSupply + 10000000000*10**18 <= _initialSupply, "Total supply cannot be more than 10000000000.");
        require(address(this).balance >= 1000000000*10**18, "You need to have at least 1000000000 to mint.");
        _transfer(address(this), owner(), 1000000000*10**18);
        fourthMint_Sent = true;
        return true;
    }
    function fifthMintExecute() public virtual onlyOwner returns (bool) {
        require(fifthMint_Date_TimeStamp <= _now, "Fifth one is not there yet");
        require(fifthMint_Sent == false, "Fifth one has been sent before");
        require(_totalSupply + 1000000000*10**18 <= _initialSupply, "Total supply cannot be more than 10000000000.");
        require(address(this).balance >= 1000000000*10**18, "You need to have at least 1000000000 to mint.");
        _transfer(address(this), owner(), 1000000000*10**18);
        fifthMint_Sent = true;
        return true;
    }
    function sixthMintExecute() public virtual onlyOwner returns (bool) {
        require(sixthMint_Date_TimeStamp <= _now, "Sixth one is not there yet");
        require(sixthMint_Sent == false, "Sixth one has been sent before");
        require(_totalSupply + 500000000*10**18 <= _initialSupply, "Total supply cannot be more than 10000000000.");
        require(address(this).balance >= 500000000*10**18, "You need to have at least 500000000 to mint.");
        _transfer(address(this), owner(), 500000000*10**18);
        sixthMint_Sent = true;
        return true;
    }
    function seventhMintExecute() public virtual onlyOwner returns (bool) {
        require(seventhMint_Date_TimeStamp <= _now, "Seventh one is not there yet");
        require(seventhMint_Sent == false, "Seventh one has been sent before");
        require(_totalSupply + 500000000*10**18 <= _initialSupply, "Total supply cannot be more than 10000000000.");
        require(address(this).balance >= 500000000*10**18, "You need to have at least 500000000 to mint.");
        _transfer(address(this), owner(), 500000000*10**18);
        seventhMint_Sent = true;
        return true;
    }
    /* OPEN THE LIQ LOCKS */
}

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
            // Gas optimization: this is cheaper than requiring 'a' not being zero, but the
            // benefit is lost if 'b' is also tested.
            // See: https://github.com/OpenZeppelin/openzeppelin-contracts/pull/522
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