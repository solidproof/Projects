// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

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

interface IUniswapV2Factory {
    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}

interface IUniswapV2Router {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
}

interface IERC20Metadata is IERC20 {

    function name() external view returns (string memory);

    function decimals() external view returns (uint8);

    function symbol() external view returns (string memory);
}

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        _transferOwnership(_msgSender());
    }

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract ERC20 is Context, IERC20, IERC20Metadata {
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;

    constructor(string memory name_, string memory symbol_) {
        _name = name_;
        _symbol = symbol_;
    }

    function symbol() external view virtual override returns (string memory) {
        return _symbol;
    }

    function name() external view virtual override returns (string memory) {
        return _name;
    }

    function balanceOf(
        address account
    ) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() external view virtual override returns (uint256) {
        return _totalSupply;
    }

    function allowance(
        address owner,
        address spender
    ) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function transfer(
        address to,
        uint256 amount
    ) external virtual override returns (bool) {
        address owner = _msgSender();
        _transfer(owner, to, amount);
        return true;
    }

    function approve(
        address spender,
        uint256 amount
    ) external virtual override returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external virtual override returns (bool) {
        address spender = _msgSender();
        _spendAllowance(from, spender, amount);
        _transfer(from, to, amount);
        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) external virtual returns (bool) {
        address owner = _msgSender();
        uint256 currentAllowance = allowance(owner, spender);
        require(
            currentAllowance >= subtractedValue,
            "SonicPad: decreased allowance below zero"
        );
        unchecked {
            _approve(owner, spender, currentAllowance - subtractedValue);
        }

        return true;
    }

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) external virtual returns (bool) {
        address owner = _msgSender();
        _approve(owner, spender, allowance(owner, spender) + addedValue);
        return true;
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "SonicPad: mint to the zero address");

        _totalSupply += amount;
        unchecked {
            // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
            _balances[account] += amount;
        }
        emit Transfer(address(0), account, amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "SonicPad: approve from the zero address");
        require(spender != address(0), "SonicPad: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _spendAllowance(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        uint256 currentAllowance = allowance(owner, spender);
        if (currentAllowance != type(uint256).max) {
            require(
                currentAllowance >= amount,
                "SonicPad: insufficient allowance"
            );
            unchecked {
                _approve(owner, spender, currentAllowance - amount);
            }
        }
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {
        require(from != address(0), "SonicPad: transfer from the zero address");
        require(to != address(0), "SonicPad: transfer to the zero address");

        uint256 fromBalance = _balances[from];
        require(
            fromBalance >= amount,
            "SonicPad: transfer amount exceeds balance"
        );
        unchecked {
            _balances[from] = fromBalance - amount;
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);
    }
}

contract SonicPad is ERC20, Ownable {

    mapping(address => bool) private _isExcludedFromFees;

    // Address List

    address public taxWallet;
    address private routerAddress;

    // Tax System

    uint256 public feeBuy;
    uint256 public feeSell;

    bool public taxIsEnabled = false;
  
    // Uniswap 

    IUniswapV2Router public swapRouter;
    address public swapPair;

    enum Flag {
        None,
        Sell,
        Buy
    }

    constructor() ERC20("SonicPad", "SNC") {
        uint256 startSupply = 100000000 * 10 ** decimals();
        _mint(msg.sender, (startSupply));

        _isExcludedFromFees[address(this)] = true;
        _isExcludedFromFees[address(owner())] = true;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        uint256 taxAmount = 0;
        Flag flag = Flag.None;

        if(taxIsEnabled && _isExcludedFromFees[to] == false){
            if (to == swapPair) {
                taxAmount = amount * feeSell / 100;
                flag = Flag.Sell;
            } else if (from == swapPair) {
                taxAmount = amount * feeBuy / 100;
                flag = Flag.Buy;
            }
        }

        if(taxAmount > 0 ){
            super._transfer(from, to, amount - taxAmount);
            super._transfer(from, taxWallet, taxAmount);
        }else{
            super._transfer(from, to, amount);
        }
    }

    function _swapTokensForEth(uint256 tokenAmount) private  {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = swapRouter.WETH();
        swapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            (block.timestamp)
        );
    }

    function _addLiquidity(
        uint256 tokenAmount,
        uint256 ethAmount
    ) private {
        swapRouter.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            owner(),
            block.timestamp
        );
    }

    // Owner Functions

    function setTaxWallet(address _newWallet) external onlyOwner {
        taxWallet = _newWallet;
    }

    function setTaxStatus(bool _status) external onlyOwner {
        taxIsEnabled = _status;
    }

    function setPairAddress(address _newPair) external onlyOwner {
        swapPair = _newPair;
    }

    function setRouterAddress(address _newRouter) external onlyOwner {

        IUniswapV2Router _uniswapRouter = IUniswapV2Router(
            _newRouter
        );

        swapRouter = _uniswapRouter;
        
        _isExcludedFromFees[address(_uniswapRouter)] = true;

        _approve(msg.sender, address(swapRouter), type(uint256).max);
        _approve(address(this), address(swapRouter), type(uint256).max);
    }


    function setBuyFee(uint _feeBuy) external onlyOwner {
        require(_feeBuy <= 20, "SonicPad: Maximum tax 20%");
        feeBuy = _feeBuy;
    }

    function setSellFee(uint256 _feeSell) external onlyOwner {
        require(_feeSell <= 20, "SonicPad: Maximum tax 20%");
        feeSell = _feeSell;
    }

      function setExcludeFromFees(
        address account,
        bool excluded
    ) external onlyOwner {
        require(
            _isExcludedFromFees[account] != excluded,
            "SonicPad: Account is already the value of 'excluded'"
        );
        _isExcludedFromFees[account] = excluded;
    }

    function isExcludedFromFees(address account) external view returns (bool) {
        return _isExcludedFromFees[account];
    }

    function withdraw(address _to) public onlyOwner() {
        uint256 contractTokenBalance = balanceOf(address(this));
        super._transfer(address(this), _to, contractTokenBalance);
    }


}