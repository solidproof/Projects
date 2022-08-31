//SPDX-License-Identifier: MIT

pragma solidity ^0.8.14;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";

contract UWC is IERC20, Ownable {
    using SafeMath for uint256;

    string constant _name = "Universe World Cup NFTs";
    string constant _symbol = "UWC";
    uint8 constant _decimals = 18;

    uint256 _totalSupply = 1000000000 * (10**_decimals);

    mapping(address => uint256) _balances;
    mapping(address => mapping(address => uint256)) _allowances;

    // allowed users to do transactions before trading enable
    mapping(address => bool) isAuthorized;
    mapping(address => bool) isMaxWalletExempt;
    mapping(address => bool) isMaxTxExempt;

    IUniswapV2Router02 public router;
    address public pair;

    bool public tradingOpen = false;

    uint256 public maxWalletTokens = _totalSupply / 100; // 1% of supply
    uint256 public maxTxAmount = _totalSupply / 1000; // 0.1% of supply

    constructor() {
        router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        pair = IUniswapV2Factory(router.factory()).createPair(
            router.WETH(),
            address(this)
        );
        _allowances[address(this)][address(router)] = type(uint256).max;

        isMaxTxExempt[msg.sender] = true;
        isMaxWalletExempt[msg.sender] = true;

        isAuthorized[msg.sender] = true;

        _balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    receive() external payable {}

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function allowance(address holder, address spender)
        external
        view
        override
        returns (uint256)
    {
        return _allowances[holder][spender];
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

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

    function approveMax(address spender) external returns (bool) {
        return approve(spender, type(uint256).max);
    }

    function transfer(address recipient, uint256 amount)
        external
        override
        returns (bool)
    {
        return _transferFrom(msg.sender, recipient, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        if (_allowances[sender][msg.sender] != type(uint256).max) {
            _allowances[sender][msg.sender] = _allowances[sender][msg.sender]
                .sub(amount, "Insufficient Allowance");
        }

        return _transferFrom(sender, recipient, amount);
    }

    function _transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        if (!isAuthorized[sender]) {
            require(tradingOpen, "Trading not open yet");
        }
        if (!isMaxTxExempt[sender] && sender != pair) {
            require(amount <= maxTxAmount, "Max Transaction amount exceeded");
        }
        if (!isMaxWalletExempt[recipient] && recipient != pair) {
            uint256 currentBalance = _balances[recipient].add(amount);
            require(
                currentBalance <= maxWalletTokens,
                "Max wallet amount exceeded"
            );
        }

        //Exchange tokens
        _balances[sender] = _balances[sender].sub(
            amount,
            "Insufficient Balance"
        );

        _balances[recipient] = _balances[recipient].add(amount);

        emit Transfer(sender, recipient, amount);
        return true;
    }

    function getBep20Tokens(address _tokenAddress, uint256 amount)
        external
        onlyOwner
    {
        require(
            _tokenAddress != address(this),
            "You can not withdraw native tokens"
        );
        require(
            IERC20(_tokenAddress).balanceOf(address(this)) >= amount,
            "No Enough Tokens"
        );
        IERC20(_tokenAddress).transfer(msg.sender, amount);
    }

    function clearStuckBalance(uint256 amountPercentage) external onlyOwner {
        uint256 amountBNB = address(this).balance;
        payable(msg.sender).transfer((amountBNB * amountPercentage) / 100);
    }

    // switch Trading
    function enableTrading() public onlyOwner {
        tradingOpen = true;
    }

    function whitelistPreSale(address _preSale) public onlyOwner {
        isAuthorized[_preSale] = true;
        isMaxTxExempt[_preSale] = true;
        isMaxWalletExempt[_preSale] = true;
    }

    function isMaxTxExcluded(address _wallet) public view returns (bool) {
        return isMaxTxExempt[_wallet];
    }

    function isMaxWalletExcluded(address _wallet) public view returns (bool) {
        return isMaxWalletExempt[_wallet];
    }

    function setMaxTxAmount(uint256 amount) external onlyOwner {
        require(
            amount >= 1000000,
            "Minimum wallet token amount should grater than 0.1%"
        );

        maxTxAmount = amount * (10**_decimals);
    }

    function setMaxWalletToken(uint256 amount) external onlyOwner {
        require(
            amount >= 10000000,
            "Minimum wallet token amount should grater than 1%"
        );
        maxWalletTokens = amount * (10**_decimals);
    }
}