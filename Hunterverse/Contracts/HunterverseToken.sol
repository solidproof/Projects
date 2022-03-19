// SPDX-License-Identifier: MIT
pragma solidity ^0.8.8;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract Hunterverse is ERC20, Ownable, ERC20Burnable {
    using SafeMath for uint256;
    using Address for address;

    struct TraderInfo {
        uint256 lastTrade;
        uint256 amount;
    }

    string private constant _name = "Hunterverse";
    string private constant _symbol = "HUT";
    uint8 private constant _decimals = 18;

    uint256 private _totalSupply = 150000000 * 10**uint256(_decimals);
    uint256 private _tFeeTotal;
    uint256 private _tBurnTotal;

    bool public isAntiWhale;
    uint256 public maxBuy = 300000000000000000000;
    uint256 public maxSell = 150000000000000000000;
    address public pancakeLiquidPair;
    uint256 public buyCooldown = 0 minutes;
    uint256 public sellCooldown = 0 minutes;

    mapping(address => mapping(string => TraderInfo)) private traders;

    mapping(address => bool) public blacklist;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => uint256) private _balances;

    constructor() ERC20(_name, _symbol) {
        _balances[_msgSender()] = _balances[_msgSender()].add(_totalSupply);
        emit Transfer(address(0), _msgSender(), _totalSupply);
    }

    function multiBlacklist(address[] memory addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            blacklist[addresses[i]] = true;
        }
    }

    function multiRemoveFromBlacklist(address[] memory addresses)
        external
        onlyOwner
    {
        for (uint256 i = 0; i < addresses.length; i++) {
            blacklist[addresses[i]] = false;
        }
    }

    function multiTransfer(address[] memory receivers, uint256[] memory amounts)
        public
    {
        for (uint256 i = 0; i < receivers.length; i++) {
            transfer(receivers[i], amounts[i]);
        }
    }

    function allowance(address owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual override {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        override
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].add(addedValue)
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        override
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

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
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

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(
            amount <= _balances[sender],
            "ERC20: amount must be less or equal to balance"
        );
        require(!blacklist[sender] && !blacklist[recipient]);

        if (isAntiWhale) {
            antiWhale(sender, recipient, amount);
        }

        _balances[sender] = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);

        emit Transfer(sender, recipient, amount);
    }

    function burn(uint256 amount) public virtual override onlyOwner {
        _burn(_msgSender(), amount);
    }

    function _burn(address account, uint256 amount) internal override {
        require(amount != 0);
        require(amount <= _balances[account]);
        _totalSupply = _totalSupply.sub(amount);
        _tBurnTotal = _tBurnTotal.add(amount);
        _balances[account] = _balances[account].sub(amount);
        emit Transfer(account, address(0), amount);
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address owner) public view override returns (uint256) {
        return _balances[owner];
    }

    function totalBurn() public view returns (uint256) {
        return _tBurnTotal;
    }

    function setAntiWhale(bool _isAntiWhale) external onlyOwner {
        isAntiWhale = _isAntiWhale;
    }

    function antiWhale(
        address _sender,
        address _recipient,
        uint256 _amount
    ) internal {
        uint256 curTime = block.timestamp;
        if (pancakeLiquidPair != address(0)) {
            if (_sender == pancakeLiquidPair) {
                if (_amount > maxBuy) revert("Buy amount limited ");
                else if (traders[_recipient]["BUY"].lastTrade == 0) {
                    traders[_recipient]["BUY"] = TraderInfo({
                        lastTrade: curTime,
                        amount: _amount
                    });
                } else if (
                    traders[_recipient]["BUY"].lastTrade + buyCooldown > curTime
                ) {
                    revert("You are cooldown to next trade!");
                } else {
                    traders[_recipient]["BUY"] = TraderInfo({
                        lastTrade: curTime,
                        amount: _amount
                    });
                }
            } else {
                if (_amount > maxSell) revert("Sell amount limited ");
                else if (traders[_sender]["SELL"].lastTrade == 0) {
                    traders[_sender]["SELL"] = TraderInfo({
                        lastTrade: curTime,
                        amount: _amount
                    });
                } else if (
                    traders[_sender]["SELL"].lastTrade + sellCooldown > curTime
                ) {
                    revert("You are cooldown to next trade!");
                } else {
                    traders[_sender]["SELL"] = TraderInfo({
                        lastTrade: curTime,
                        amount: _amount
                    });
                }
            }
        } else {
            if (_amount > maxBuy) revert("Buy amount limited ");
        }
    }

    function setBuyCooldown(uint256 _duration) external onlyOwner {
        buyCooldown = _duration;
    }

    function setSellCooldown(uint256 _duration) external onlyOwner {
        sellCooldown = _duration;
    }

    function setMaxBuy(uint256 _maxBuy) external onlyOwner {
        maxBuy = _maxBuy;
    }

    function setMaxSell(uint256 _maxSell) external onlyOwner {
        maxSell = _maxSell;
    }

    function setLiquidPair(address _lp) external onlyOwner {
        pancakeLiquidPair = _lp;
    }
}
