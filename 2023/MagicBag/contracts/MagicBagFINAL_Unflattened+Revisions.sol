// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract MagicBag is Ownable, IERC20{
    using SafeMath for uint256;

    string  private _name;
    string  private _symbol;
    uint256 private _decimals;
    uint256 private _totalSupply;

    uint256 public  maxTxLimit;
    uint256 public  maxWalletLimit;
    address payable public developmentWallet;
    uint256 public  swapableRefection;
    uint256 public  swapableDevTax;
    address private constant DEAD = 0x000000000000000000000000000000000000dEaD;

    uint256 public sellTax;
    uint256 public buyTax;
    uint256 public taxDivisionPercentage;
    uint256 public totalBurned;
    uint256 public totalReflected;
    uint256 public totalLP;

    IUniswapV2Router02 public dexRouter;
    address public  lpPair;
    bool    public  tradingActive;
    uint256 public  ethReflectionBasis;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool)    private _reflectionExcluded;
    mapping(address => uint256) public  lastReflectionBasis;
    mapping(address => uint256) public  totalClaimedReflection;
    mapping(address => bool)    public  lpPairs;
    mapping(address => bool)    private _isExcludedFromTax;
    mapping(address => bool)    private _bots;

    event functionType (uint Type, address sender, uint256 amount);

    constructor(string memory name_, 
                string memory symbol_, 
                uint256 decimals_, 
                uint256 totalSupply_,
                address payable devWallet_,
                uint256 taxDivisionPercentage_, 
                uint256 maxTxLimit_, 
                uint256 maxWalletLimit_){
        _name              = name_;
        _symbol            = symbol_;
        _decimals          = decimals_;
        _totalSupply       = totalSupply_.mul(10 ** _decimals);
        _balances[owner()] = _balances[owner()].add(_totalSupply);

        developmentWallet  = payable(devWallet_);
        sellTax            = 60;
        buyTax             = 15;
        maxTxLimit         = maxTxLimit_;
        maxWalletLimit     = maxWalletLimit_;
        taxDivisionPercentage   = taxDivisionPercentage_;

        dexRouter = IUniswapV2Router02(0xD99D1c33F9fC3444f8101754aBC46c52416550D1);
        lpPair    = IUniswapV2Factory(dexRouter.factory()).createPair(address(this), dexRouter.WETH());
        lpPairs[lpPair] = true;

        _approve(owner(), address(dexRouter), type(uint256).max);
        _approve(address(this), address(dexRouter), type(uint256).max);

        _isExcludedFromTax[owner()]       = true;
        _isExcludedFromTax[address(this)] = true;
        _isExcludedFromTax[lpPair]        = true;

        emit Transfer(address(0), owner(), _totalSupply);
    }

    receive() external payable {}

    //@notice All ERC20 functions implementation
    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint256) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function allowance(address sender, address spender) public view override returns (uint256) {
        return _allowances[sender][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function _approve(address sender, address spender, uint256 amount) private {
        require(sender  != address(0), "ERC20: Zero Address");
        require(spender != address(0), "ERC20: Zero Address");

        _allowances[sender][spender] = amount;
        emit Approval(sender, spender, amount);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        require(_msgSender() != address(0), "ERC20: Zero Address");
        require(recipient != address(0), "ERC20: Zero Address");
        require(recipient != DEAD, "ERC20: Dead Address");
        require(_balances[msg.sender] >= amount, "ERC20: Amount exceeds account balance");

        _transfer(msg.sender, recipient, amount);

        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        require(_msgSender() != address(0), "ERC20: Zero Address");
        require(recipient != address(0), "ERC20: Zero Address");
        require(recipient != DEAD, "ERC20: Dead Address");
        require(_allowances[sender][msg.sender] >= amount, "ERC20: Insufficient allowance.");
        require(_balances[sender] >= amount, "ERC20: Amount exceeds sender's account balance");

        if (_allowances[sender][msg.sender] != type(uint256).max) {
            _allowances[sender][msg.sender]  = _allowances[sender][msg.sender].sub(amount);
        }
        _transfer(sender, recipient, amount);

        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) private {
        require(_bots[sender] == false && _bots[recipient] == false, "ERC20: Bots can't trade");

        if (sender == owner() && lpPairs[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        }
        else if (lpPairs[sender] || lpPairs[recipient]){
            require(tradingActive == true, "ERC20: Trading is not active.");
            
            if (_isExcludedFromTax[sender] && !_isExcludedFromTax[recipient]){
                if (_checkWalletLimit(recipient, amount) && _checkTxLimit(amount)) {
                    _transferFromExcluded(sender, recipient, amount);//buy
                } 
            }   
            else if (!_isExcludedFromTax[sender] && _isExcludedFromTax[recipient]){
                if (_checkTxLimit(amount)) {
                    _transferToExcluded(sender, recipient, amount);//sell
                }
            }
            else if (_isExcludedFromTax[sender] && _isExcludedFromTax[recipient]) {
                if (sender == owner() || recipient == owner() || sender == address(this) || recipient == address(this)) {
                    _transferBothExcluded(sender, recipient, amount);
                } else if (lpPairs[recipient]) {
                    if (_checkTxLimit(amount)) {
                        _transferBothExcluded(sender, recipient, amount);
                    }
                } else if (_checkWalletLimit(recipient, amount) && _checkTxLimit(amount)){
                    _transferBothExcluded(sender, recipient, amount);
                }
            } 
        } else {
            if (sender == owner() || recipient == owner() || sender == address(this) || recipient == address(this)) {
                    _transferBothExcluded(sender, recipient, amount);
            } else if(_checkWalletLimit(recipient, amount) && _checkTxLimit(amount)){
                    _transferBothExcluded(sender, recipient, amount);
            }
        }
    }

    function _transferFromExcluded(address sender, address recipient, uint256 amount) private { //buy
        uint256 randomNumber  = _generateRandomNumber();
        uint256 taxAmount     = amount.mul(buyTax).div(100);
        uint256 receiveAmount = amount.sub(taxAmount);
        (
        uint256 devAmount,
        uint256 burnAmount,
        uint256 lpAmount,
        uint256 reflectionAmount
        ) = _getTaxAmount(taxAmount);

        _balances[sender]        = _balances[sender].sub(amount);
        _balances[recipient]     = _balances[recipient].add(receiveAmount);
        _balances[address(this)] = _balances[address(this)].add(devAmount);
        swapableDevTax           = swapableDevTax.add(devAmount);

        if (randomNumber == 1) {
            _burn(sender, burnAmount);
            emit functionType(randomNumber, sender, burnAmount);
        } else if (randomNumber == 2) {
            _takeLP(sender, lpAmount);
            emit functionType(randomNumber, sender, lpAmount);
        } else if (randomNumber == 3) {
            _balances[address(this)] = _balances[address(this)].add(reflectionAmount);
            swapableRefection        = swapableRefection.add(reflectionAmount);
            totalReflected           = totalReflected.add(reflectionAmount);
            emit functionType(randomNumber, sender, reflectionAmount);
        }
        emit Transfer(sender, recipient, amount);
    }

    function _transferToExcluded(address sender, address recipient, uint256 amount) private { //sell
        uint256 randomNumber = _generateRandomNumber();
        uint256 taxAmount    = amount.mul(sellTax).div(100);
        uint256 sentAmount   = amount.sub(taxAmount);
        (
        uint256 devAmount,  
        uint256 burnAmount,
        uint256 lpAmount,
        uint256 reflectionAmount
        ) = _getTaxAmount(taxAmount);

        _balances[sender]        = _balances[sender].sub(amount);
        _balances[recipient]     = _balances[recipient].add(sentAmount);
        _balances[address(this)] = _balances[address(this)].add(devAmount);
        swapableDevTax           = swapableDevTax.add(devAmount);

        if (randomNumber == 1) {
            _burn(sender, burnAmount);
            emit functionType(randomNumber, sender, burnAmount);
        } else if (randomNumber == 2) {
            _takeLP(sender, lpAmount);
            emit functionType(randomNumber, sender, lpAmount);
        } else if (randomNumber == 3) {
            _balances[address(this)] = _balances[address(this)].add(reflectionAmount);
            swapableRefection        = swapableRefection.add(reflectionAmount);
            totalReflected           = totalReflected.add(reflectionAmount);
            emit functionType(randomNumber, sender, reflectionAmount);
        }
        emit Transfer(sender, recipient, amount);
    }

    function _transferBothExcluded(address sender, address recipient, uint256 amount) private {
        _balances[sender]    = _balances[sender].sub(amount);
        _balances[recipient] = _balances[recipient].add(amount);

        emit Transfer(sender, recipient, amount);
    }

    //@notice Burn function for public use, anyone can burn their tokens
    function burn(uint256 amountTokens) public {
        address sender = msg.sender;
        require(_balances[sender] >= amountTokens, "ERC20: Burn Amount exceeds account balance");
        require(amountTokens > 0, "ERC20: Enter some amount to burn");

        if (amountTokens > 0) {
            _balances[sender] = _balances[sender].sub(amountTokens);
            _burn(sender, amountTokens);
        }
    }

    function _burn(address from, uint256 amount) private {
        _totalSupply = _totalSupply.sub(amount);
        totalBurned  = totalBurned.add(amount);

        emit Transfer(from, address(0), amount);
    }

    //@notice Adding tax to the LP address
    function _takeLP(address from, uint256 tax) private {
        if (tax > 0) {
            (, , uint256 lp, ) = _getTaxAmount(tax);
            _balances[lpPair]  = _balances[lpPair].add(lp);
            totalLP = totalLP.add(lp);

            emit Transfer(from, lpPair, lp);
        }
    }

    //@notice Reflections related functionalities
    function addReflection() external payable {
        ethReflectionBasis = ethReflectionBasis.add(msg.value);
    }

    function isReflectionExcluded(address account) public view returns (bool) {
        return _reflectionExcluded[account];
    }

    function removeReflectionExcluded(address account) external onlyOwner {
        require(isReflectionExcluded(account), "ERC20: Account must be excluded");

        _reflectionExcluded[account] = false;
    }

    function addReflectionExcluded(address account) external onlyOwner {
        _addReflectionExcluded(account);
    }

    function _addReflectionExcluded(address account) internal {
        require(!isReflectionExcluded(account), "ERC20: Account must not be excluded");
        _reflectionExcluded[account] = true;
    }

    function unclaimedReflection(address addr) public view returns (uint256) {
        if (addr == lpPair || addr == address(dexRouter)) return 0;

        uint256 basisDifference = ethReflectionBasis - lastReflectionBasis[addr];
        return (basisDifference * balanceOf(addr)) / _totalSupply;
    }

    function _claimReflection(address payable addr) internal {
        uint256 unclaimed         = unclaimedReflection(addr);
        require(unclaimed > 0, "ERC20: Claim amount should be more then 0");
        require(isReflectionExcluded(addr) == false, "ERC20: Address is excluded to claim reflection");
        
        lastReflectionBasis[addr] = ethReflectionBasis;
        if (unclaimed > 0) {
            addr.transfer(unclaimed);
        }
        totalClaimedReflection[addr] = totalClaimedReflection[addr].add(unclaimed);
    }

    function claimReflection() external {
        _claimReflection(payable(msg.sender));
    }

    function swapReflection() public onlyOwner {
        require(swapableRefection > 0, "ERC20: Insufficient token to swap");

        uint256 currentBalance = address(this).balance;
        _swap(address(this), swapableRefection);
        swapableRefection = 0;

        uint256 ethTransfer = (address(this).balance).sub(currentBalance);
        ethReflectionBasis  = ethReflectionBasis.add(ethTransfer);
    }

    function swapDevTax() public onlyOwner {
        require(swapableDevTax > 0, "ERC20: Insufficient token to swap");
        _swap(developmentWallet, swapableDevTax);
        swapableDevTax = 0;
    }

    //@notice Other functions
    function setmaxTxLimit(uint256 amount) public onlyOwner {
        maxTxLimit = amount;
    }

    function setMaxWalletLimit(uint256 amount) public onlyOwner {
        maxWalletLimit = amount;
    }

    function setDevWallet(address payable newDevWallet) public onlyOwner {
        require(newDevWallet != address(0), "ERC20: Can't set development wallet as null address.");
        developmentWallet = newDevWallet;
    }

    //@notice Sell tax can not go above 15 percent
    function setsellTax(uint256 tax) public onlyOwner {
        require(tax <= 15, "ERC20: The percentage can't more 100.");
        sellTax = tax;
    }

    //@notice Sell tax can not go above 15 percent
    function setbuyTax(uint256 tax) public onlyOwner {
        require(tax <= 15, "ERC20: The percentage can't more 100.");
        buyTax = tax;
    }

    function setTaxDivPercentage(uint256 percentage) public onlyOwner {
        require(percentage <= 100, "ERC20: The percentage can't more then 100");
        taxDivisionPercentage = percentage;
    }

    function enableTrading() external onlyOwner {
        tradingActive = true;
    }

    function disableTrading() external onlyOwner {
        tradingActive = false;
    }

    function addBot(address[] memory _bot) public onlyOwner {
        for (uint i = 0; i < _bot.length; i++) {
            _bots[_bot[i]] = true;
        }
    }

    function removeBot(address _bot) public onlyOwner {
        require(_bots[_bot] == true, "ERC20: Bot is not in the list");
        _bots[_bot] = false;
    }

    function addLpPair(address pair, bool status) public onlyOwner{
        lpPairs[pair] = status;
        _isExcludedFromTax[pair] = status;
    }

    function removeAllTax() public onlyOwner {
        sellTax = 0;
        buyTax  = 0;
        taxDivisionPercentage = 0;
    }

    function excludeFromTax(address account) public onlyOwner {
        require(!_isExcludedFromTax[account], "ERC20: Account is already excluded.");
        _isExcludedFromTax[account] = true;
    }

    function includeInTax(address _account) public onlyOwner {
        require(_isExcludedFromTax[_account], "ERC20: Account is already included.");
        _isExcludedFromTax[_account] = false;
    }
    
    function recoverAllEth() public onlyOwner {
        payable(owner()).transfer(address(this).balance);
    }

    function recoverErc20token(address token, uint256 amount) public onlyOwner {
        IERC20(token).transfer(owner(), amount);
    }

    //@dev View functions
    function checkExludedFromTax(address _account) public view returns (bool) {
        return _isExcludedFromTax[_account];
    }

    function isBot(address _account) public view returns(bool) {
        return _bots[_account];
    }

    //@dev Private functions
    function _generateRandomNumber() private view returns (uint256) {
        return (uint256(keccak256(abi.encodePacked(block.timestamp, block.difficulty, block.gaslimit, tx.origin, block.number, tx.gasprice))) % 3) + 1;
    }

    function _getTaxAmount(uint256 _tax) private view returns (uint256 _devAmount, uint256 Burn, uint256 LP, uint256 Reflection) {
        uint256 devAmount;
        uint256 burnAmount;
        uint256 lpAmount;
        uint256 reflectionAmount;

        if (_tax > 0) {
            devAmount = _tax.mul((100 - taxDivisionPercentage)).div(100);
            burnAmount = _tax.mul(taxDivisionPercentage).div(100);
            lpAmount = _tax.mul(taxDivisionPercentage).div(100);
            reflectionAmount = _tax.mul(taxDivisionPercentage).div(100);
        }
        return (devAmount, burnAmount, lpAmount, reflectionAmount);
    }

    function _checkWalletLimit(address recipient, uint256 amount) private view returns(bool){
        require(maxWalletLimit >= balanceOf(recipient).add(amount), "ERC20: Wallet limit exceeds");
        return true;
    }

    function _checkTxLimit(uint256 amount) private view returns(bool){
        require(amount <= maxTxLimit, "ERC20: Transaction limit exceeds");
        return true;
    }

    function _swap(address recipient, uint256 amount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = dexRouter.WETH();

        dexRouter.swapExactTokensForETH(
            amount,
            0,
            path,
            recipient,
            block.timestamp
        );
    }
}