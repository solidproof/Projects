// SPDX-License-Identifier: No License
pragma solidity 0.8.3;

import "./IPinkAntiBot.sol";
import "./IBinanceApePropulsor.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract BinanceApeStationToken is Context, IERC20 {
    using SafeMath for uint256;

    IPinkAntiBot public pinkAntiBot;
    bool private _pinkAntiBotActivated = false;

    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;

    uint256 private _initialTotalSupply;
    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    address private _owner;

    address private _stakingContract;

    bool _feesActivated = false;
    bool _burnPaused = false;

    mapping(address => bool) _excludedFeesAddress;

    constructor (address pinkAntiBotAddr) {
        _owner = msg.sender;
        _name = "Binance Ape Station";
        _symbol = "BAPES";
        _totalSupply = 200000000 * (10 ** 18);
        _initialTotalSupply = _totalSupply;

        if (pinkAntiBotAddr != address(0)) {
            pinkAntiBot = IPinkAntiBot(pinkAntiBotAddr);
            pinkAntiBot.setTokenOwner(msg.sender);
            _pinkAntiBotActivated = true;
        }

        _balances[msg.sender] += _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "BAPES: unauthorized");
        _;
    }

    function setPinkAntiBotActivated(bool value) public onlyOwner {
        _pinkAntiBotActivated = value;
    }

    function setStakingContract(address addr) public onlyOwner {
        _stakingContract = addr;
    }

    function setFeesActivated(bool value) public onlyOwner {
        _feesActivated = value;
    }

    function setBurnPaused(bool value) public onlyOwner {
        _burnPaused = value;
    }

    function setExcludedFeesAddr(address addr, bool value) public onlyOwner {
        _excludedFeesAddress[addr] = value;
    }

    function pinkAntiBotActivated() public view returns (bool) {
        return _pinkAntiBotActivated;
    }

    function stakingContract() public view returns (address) {
        return _stakingContract;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(currentAllowance >= amount, "BAPES: transfer amount exceeds allowance");

        _approve(sender, _msgSender(), currentAllowance - amount);
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(currentAllowance >= subtractedValue, "BAPES: decreased allowance below zero");

        _approve(_msgSender(), spender, currentAllowance - subtractedValue);
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "BAPES: transfer from the zero address");
        require(recipient != address(0), "BAPES: transfer to the zero address");
        require(amount > 0, "BAPES: transfer amount must be greater than zero");
        require(_balances[sender] >= amount, "BAPES: transfer amount exceeds balance");

        if (_pinkAntiBotActivated) {
            pinkAntiBot.onPreTransferCheck(sender, recipient, amount);
        }

        if (_feesActivated && !_excludedFeesAddress[sender]) {
            require(_stakingContract != address(0), "BAPES: staking contract must be set");

            uint256 burnAmount = amount.div(100).mul(5);
            uint256 stakingAmount = amount.div(100).mul(5);

            uint256 amountMinusFees = amount.sub(burnAmount).sub(stakingAmount);

            // Removing total amount minus burn amount from the sender
            _balances[sender] = _balances[sender] - amount.sub(burnAmount);

            // Adding total amount minus fees to the recipient
            _balances[recipient] += amountMinusFees;
            emit Transfer(sender, recipient, amountMinusFees);

            bool isBurnPaused = _burnPaused || (_totalSupply <= _initialTotalSupply.div(2));

            if (!isBurnPaused) {
                // Burning if not paused, burn amount is removed from the sender by the _burn function
                _burn(sender, burnAmount);
            }
            else {
                // Removing burn amount from the sender
                _balances[sender] = _balances[sender] - burnAmount;

                // Adding burn amount to the staking contract
                _balances[_stakingContract] += burnAmount;
                emit Transfer(sender, _stakingContract, burnAmount);
            }

            // Adding staking amount to the staking contract
            _balances[_stakingContract] += stakingAmount;
            emit Transfer(sender, _stakingContract, stakingAmount);

            // Pulsing the propuslor
            uint256 propulsorFeesAmount = stakingAmount;
            if (isBurnPaused) {
                propulsorFeesAmount = stakingAmount.add(burnAmount);
            }

            IBinanceApePropulsor(_stakingContract).pulse(propulsorFeesAmount);
        }
        else {
            // Removing total amount from the sender
            _balances[sender] = _balances[sender] - amount;

            // Adding total amount to the recipient
            _balances[recipient] += amount;
            emit Transfer(sender, recipient, amount);
        }
    }

    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "BAPES: burn from the zero address");

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "BAPES: burn amount exceeds balance");
        _balances[account] = accountBalance - amount;
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }

    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "BAPES: approve from the zero address");
        require(spender != address(0), "BAPES: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function burn(uint256 amount) public {
        _burn(_msgSender(), amount);
    }

    function burnFrom(address account, uint256 amount) public {
        uint256 currentAllowance = allowance(account, _msgSender());
        require(currentAllowance >= amount, "BAPES: burn amount exceeds allowance");
        _approve(account, _msgSender(), currentAllowance - amount);
        _burn(account, amount);
    }
}