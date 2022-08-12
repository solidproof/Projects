// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

contract Token is Context, IERC20Metadata, Ownable {
    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private constant _decimals = 18;
    uint256 public constant hardCap = 2_000_000_000 * (10**_decimals); //2 billion
    uint256 public constant mintHardCap = 1_400_000_000 * (10**_decimals); //1.4 billion
    uint256 public constant lockedSupply = hardCap - mintHardCap; //600 million
    uint256 public mintable = mintHardCap;
    uint256 public locking_start;
    uint256 public locking_end;
    uint256 public mintedLockedSupply;

    event LockStarted(uint256 startTime, uint256 endTime);

    constructor(
        string memory name_,
        string memory symbol_,
        uint256 _mintAmount,
        uint256 lockingStartTime,
        uint256 lockingEndTime
    ) Ownable() {
        require(
            _mintAmount > 0 && _mintAmount <= mintHardCap,
            "Invalid mint amount"
        );
        require(
            lockingStartTime >= block.timestamp,
            "Start time is in the past"
        );
        require(lockingEndTime > lockingStartTime, "Invalid end time");
        _name = name_;
        _symbol = symbol_;
        mintable -= _mintAmount;
        _mint(owner(), _mintAmount);
        locking_start = lockingStartTime;
        locking_end = lockingEndTime;
        emit LockStarted(locking_start, locking_end);
    }

    function mint(uint256 amount) external onlyOwner {
        require(amount > 0 && amount <= mintable, "Amount out of bounds");
        mintable -= amount;
        _mint(owner(), amount);
    }

    function mintLockedSupply() external onlyOwner {
        uint256 amount = mintableLockedAmount();
        if (amount > 0) {
            mintedLockedSupply += amount;
            _mint(owner(), amount);
        } else {
            revert("Nothing to mint");
        }
    }

    function mintableLockedAmount() public view returns (uint256 finalAmount) {
        if (block.timestamp <= locking_start) {
            finalAmount = 0;
        } else if (
            block.timestamp > locking_start && block.timestamp < locking_end
        ) {
            uint256 timePassed = (block.timestamp - locking_start) *
                (10**_decimals);
            uint256 totalLock = (lockedSupply * timePassed) /
                ((locking_end - locking_start) * (10**_decimals));
            finalAmount = (totalLock - mintedLockedSupply);
        } else {
            finalAmount = lockedSupply - mintedLockedSupply;
        }
    }

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address from, address to)
        public
        view
        virtual
        override
        returns (uint256)
    {
        return _allowances[from][to];
    }

    function approve(address to, uint256 amount)
        public
        virtual
        override
        returns (bool)
    {
        _approve(_msgSender(), to, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][_msgSender()];
        require(
            currentAllowance >= amount,
            "ERC20: transfer amount exceeds allowance"
        );
        unchecked {
            _approve(sender, _msgSender(), currentAllowance - amount);
        }

        return true;
    }

    function increaseAllowance(address to, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        _approve(_msgSender(), to, _allowances[_msgSender()][to] + addedValue);
        return true;
    }

    function decreaseAllowance(address to, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        uint256 currentAllowance = _allowances[_msgSender()][to];
        require(
            currentAllowance >= subtractedValue,
            "ERC20: decreased allowance below zero"
        );
        unchecked {
            _approve(_msgSender(), to, currentAllowance - subtractedValue);
        }

        return true;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        uint256 senderBalance = _balances[sender];
        require(
            senderBalance >= amount,
            "ERC20: transfer amount exceeds balance"
        );
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: burn from the zero address");

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);
    }

    function burn(uint256 amount) external {
        _burn(_msgSender(), amount);
    }

    function _approve(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "ERC20: approve from the zero address");
        require(to != address(0), "ERC20: approve to the zero address");

        _allowances[from][to] = amount;
        emit Approval(from, to, amount);
    }
}
