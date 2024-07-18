/**
 *Submitted for verification at basescan.org on 2024-07-14
*/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.24;

// Provides utilities for retrieving the message sender in a transaction.
abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

// Interface for the ERC20 standard as defined in the EIP.
interface IERC20 {
    function totalSupply() external view returns (uint256);
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external returns (bool);
    function allowance(address owner, address spender) external view returns (uint256);
    function approve(address spender, uint256 amount) external returns (bool);
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval (address indexed owner, address indexed spender, uint256 value);
}

/* Contract module which provides a basic access control mechanism, where there is 
an account (an owner) that can be granted exclusive access to specific functions.
*/
contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor () {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }

}

// Interface for the optional metadata functions from the ERC20 standard.
interface IERC20Metadata is IERC20 {
    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
}


// Implementation of the {IERC20} interface.
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

    function name() public view virtual override returns (string memory) {
        return _name;
    }

    function symbol() public view virtual override returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual override returns (uint8) {
        return 18;
    }

    function totalSupply() public view virtual override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
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

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(senderBalance >= amount, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);

        _afterTokenTransfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: _mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
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

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual {}
}

// Interface for the Uniswap V2 Factory.
interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

// Interface for the Uniswap V2 Router.
interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
}

/// @title UZI ERC20 Token Contract
/// @dev This contract implements an ERC20 token with integrated swap functionality and fee management.
contract UZI is ERC20, Ownable {
    // Uniswap V2 router and pair for token swapping.
    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;

    // Tracks whether a swap is in progress to prevent reentrancy.
    bool private inSwap;

    // Marketing fee as a percentage of the transaction amount.
    uint256 public marketingFee = 5;

    // The amount of tokens that triggers an automatic token swap.
    uint256 public swapTokensAtAmount = 30000000 * (10**18);

    // Wallet address for receiving marketing funds and fees.
    address payable public marketingWallet = payable(0x79B6d82C280845D1d3Fe29848c512D55cc029068);
    // Mapping to keep track of addresses excluded from fees.
    mapping(address => bool) private _isExcludedFromFees;

    // Event emitted when an account is excluded from fees.
    event FeesExclusionUpdated(address indexed account, bool isExcluded);

    // Event emited when the swap threshold is updated by the owner.
    event SwapThresholdUpdated(uint256 newLimit);

    // Modifier to lock the swap during its execution.
    modifier lockTheSwap {
        inSwap = true;
        _;
        inSwap = false;
    }

    /// @dev Constructor to initialize the contract with necessary parameters.
    /// @notice Constructor to setup the initial settings of the token.
    constructor(address _owner) ERC20("UZI INU", "UZI") {
        // Setup the Uniswap V2 Router and create a pair for this token.
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x1b02dA8Cb0d097eB8D57A175b88c7D8b47997506);
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());
        uniswapV2Router = _uniswapV2Router;

        // Exclude the owner, contract, and dev wallet from transaction fees.
        excludeFromFees(_owner, true);
        excludeFromFees(address(this), true);
        excludeFromFees(marketingWallet, true);

        // Mint the initial token supply to the owner. This is the only time minting will occur.
        _mint(_owner, 420_000_000_000 * (10**18));
        transferOwnership(_owner);

    }

    /// @dev Internal function to handle the transfer of tokens including fee processing.
    /// @param from Sender address.
    /// @param to Receiver address.
    /// @param amount Amount of tokens to transfer.
    function _transfer(address from, address to, uint256 amount) internal override {
        require(from != address(0) && to != address(0), "ERC20: transfer from/to the zero address");

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        uint256 contractTokenBalance = balanceOf(address(this));
        bool overMinTokenBalance = contractTokenBalance >= swapTokensAtAmount;
        if (overMinTokenBalance && !inSwap && to == uniswapV2Pair) {
            swapTokensForEth(swapTokensAtAmount);
        }

        uint256 fees = 0;
        if (!_isExcludedFromFees[from] && !_isExcludedFromFees[to] && (from == uniswapV2Pair || to == uniswapV2Pair)) {
            fees = amount * marketingFee / 100;
            amount -= fees;
            if (fees > 0) {
                super._transfer(from, address(this), fees);
            }
        }

        super._transfer(from, to, amount);
    }

    /// @dev Swaps tokens for Ethereum using the Uniswap V2 Router.
    /// @param tokenAmount Amount of tokens to swap.
    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            marketingWallet,
            block.timestamp
        );
    }

    /// @dev Allows the owner to update the marketing fee with a limit of up to 5%.
    /// @param newFee The new marketing fee percentage.
    function setMarketingFee(uint256 newFee) public onlyOwner {
        require(newFee <= 5, "UZI: Marketing fee cannot exceed 5%");
        marketingFee = newFee;
    }

    /// @dev Returns whether an address is excluded from fees.
    /// @param account The address to check.
    function isExcludedFromFees(address account) public view returns (bool) {
        return _isExcludedFromFees[account];
    }

    /// @dev Exclude or include an account from fees.
    /// @param account The account to modify.
    /// @param value True if excluding from fees, false otherwise.
    function excludeFromFees(address account, bool value) public onlyOwner {
        _isExcludedFromFees[account] = value;
        emit FeesExclusionUpdated(account, value);
    }

    function updateSwapThreshold(uint256 _newLimit) public onlyOwner {
        // Define the minimum and maximum swap thresholds directly within the function.
        uint256 MIN_SWAP_THRESHOLD = 300000 * (10**18);  // Minimum swap threshold
        uint256 MAX_SWAP_THRESHOLD = 210000000 * (10**18);  // Maximum swap threshold

        require(_newLimit >= MIN_SWAP_THRESHOLD, "UZI: new limit too low");
        require(_newLimit <= MAX_SWAP_THRESHOLD, "UZI: new limit too high");
        swapTokensAtAmount = _newLimit;
        emit SwapThresholdUpdated(_newLimit);
    }

    // Allows the contract to receive ETH directly.
    receive() external payable {}
}