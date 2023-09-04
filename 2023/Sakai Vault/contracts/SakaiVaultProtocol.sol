/**
 *Submitted for verification at BscScan.com on 2023-08-31
*/

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

interface IERC20Vault {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(
        address recipient,
        uint256 amount
    ) external returns (bool);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

interface IERC20MetadataVault is IERC20Vault {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}


abstract contract ContextVault {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract OwnableVault is ContextVault {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    /**
     * @dev Initializes the contract setting the deployer as the initial owner.
     */
    constructor() {
        _transferOwnership(_msgSender());
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    /**
     * @dev Returns the address of the current owner.
     */
    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if the sender is not the owner.
     */
    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "OwnableVaultNFT: caller is not the owner");
    }

    /**
     * @dev Leaves the contract without owner. It will not be possible to call
     * `onlyOwner` functions. Can only be called by the current owner.
     *
     * NOTE: Renouncing ownership will leave the contract without an owner,
     * thereby disabling any functionality that is only available to the owner.
     */
    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Can only be called by the current owner.
     */
    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "OwnableVaultNFT: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    /**
     * @dev Transfers ownership of the contract to a new account (`newOwner`).
     * Internal function without access restriction.
     */
    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}

contract ERC20Vault is ContextVault, IERC20Vault, IERC20MetadataVault {
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

    function balanceOf(
        address account
    ) public view virtual override returns (uint256) {
        return _balances[account];
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(
        address owner,
        address spender
    ) public view virtual override returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) public virtual override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override returns (bool) {
        uint256 currentAllowance = _allowances[sender][_msgSender()];
        if (currentAllowance != type(uint256).max) {
            require(
                currentAllowance >= amount,
                "ERC20Vault: transfer amount exceeds allowance"
            );
            unchecked {
                _approve(sender, _msgSender(), currentAllowance - amount);
            }
        }

        _transfer(sender, recipient, amount);

        return true;
    }

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) public virtual returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        require(
            currentAllowance >= subtractedValue,
            "ERC20Vault: decreased allowance below zero"
        );
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
        require(sender != address(0), "ERC20Vault: transfer from the zero address");
        require(recipient != address(0), "ERC20Vault: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];
        require(
            senderBalance >= amount,
            "ERC20Vault: transfer amount exceeds balance"
        );
        unchecked {
            _balances[sender] = senderBalance - amount;
        }
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);

        _afterTokenTransfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20Vault: mint to the zero address");

        _beforeTokenTransfer(address(0), account, amount);

        _totalSupply += amount;
        _balances[account] += amount;
        emit Transfer(address(0), account, amount);

        _afterTokenTransfer(address(0), account, amount);
    }

    function _burn(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20Vault: burn from the zero address");

        _beforeTokenTransfer(account, address(0), amount);

        uint256 accountBalance = _balances[account];
        require(accountBalance >= amount, "ERC20Vault: burn amount exceeds balance");
        unchecked {
            _balances[account] = accountBalance - amount;
        }
        _totalSupply -= amount;

        emit Transfer(account, address(0), amount);

        _afterTokenTransfer(account, address(0), amount);
    }

    function burn(uint256 amount) public virtual {
        require(_msgSender() != address(0), "ERC20Vault: burn from the zero address");
        require(amount > 0, "ERC20Vault: burn amount exceeds balance");
        require(_balances[_msgSender()] >= amount, "ERC20Vault: burn amount exceeds balance");
        _burn(_msgSender(), amount);
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal virtual {
        require(owner != address(0), "ERC20Vault: approve from the zero address");
        require(spender != address(0), "ERC20Vault: approve to the zero address");

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

interface IUniswapV2FactoryVault {
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint
    );

    function feeTo() external view returns (address);

    function feeToSetter() external view returns (address);

    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);

    function allPairs(uint) external view returns (address pair);

    function allPairsLength() external view returns (uint);

    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);

    function setFeeTo(address) external;

    function setFeeToSetter(address) external;
}

interface IUniswapV2PairVault {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);

    function symbol() external pure returns (string memory);

    function decimals() external pure returns (uint8);

    function totalSupply() external view returns (uint);

    function balanceOf(address owner) external view returns (uint);

    function allowance(
        address owner,
        address spender
    ) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);

    function transfer(address to, uint value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint value
    ) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);

    function PERMIT_TYPEHASH() external pure returns (bytes32);

    function nonces(address owner) external view returns (uint);

    function permit(
        address owner,
        address spender,
        uint value,
        uint deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(
        address indexed sender,
        uint amount0,
        uint amount1,
        address indexed to
    );
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

    function getReserves()
    external
    view
    returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);

    function price0CumulativeLast() external view returns (uint);

    function price1CumulativeLast() external view returns (uint);

    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);

    function burn(address to) external returns (uint amount0, uint amount1);

    function swap(
        uint amount0Out,
        uint amount1Out,
        address to,
        bytes calldata data
    ) external;

    function skim(address to) external;

    function sync() external;

    function initialize(address, address) external;
}

interface IUniswapV2Router01Vault {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

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
    )
    external
    payable
    returns (uint amountToken, uint amountETH, uint liquidity);

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
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint amountA, uint amountB);

    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
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

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function swapTokensForExactETH(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapETHForExactTokens(
        uint amountOut,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function quote(
        uint amountA,
        uint reserveA,
        uint reserveB
    ) external pure returns (uint amountB);

    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) external pure returns (uint amountOut);

    function getAmountIn(
        uint amountOut,
        uint reserveIn,
        uint reserveOut
    ) external pure returns (uint amountIn);

    function getAmountsOut(
        uint amountIn,
        address[] calldata path
    ) external view returns (uint[] memory amounts);

    function getAmountsIn(
        uint amountOut,
        address[] calldata path
    ) external view returns (uint[] memory amounts);
}

interface IUniswapV2Router02Vault is IUniswapV2Router01Vault {
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
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
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

interface ITheVaultTicker {
    function mintNFT(address to, uint256 tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address owner);
    function buyback(uint256 _tokenId, address newOwner) external;
}

contract SakaiVaultProtocol is ERC20Vault, OwnableVault {
    address public committedTokenAddress;
    address public stakingAddress;
    address public charityAddress;
    uint256 public startingAt;
    uint256 public endingAt;
    uint256 public defaultEligibleDays;
    uint256 public eligibleIndex;
    uint256 public startEligibleIndex;
    uint256 public startBalanceAmount;
    uint256 public pricePerTicket;
    uint256 public periodEligible;
    uint256 public pickWinnerLoop;
    uint256 public totalLockedAmountForReward;

    address public uniswapV2RouterAddress;
    address public busdAddress;
    address public nftAddress;

    struct Buyers {
        address ownerAddress;
        uint256 amountUSD;
        uint256 amountSAKAI;
        uint256 ticketId;
        uint256 buyAt;
        uint256 claimAt;
        uint256 amountReward;
        uint256 period;
    }

    mapping(uint256 => Buyers) public ticketBuyers;

    mapping(uint256 => address) public eligibleAddresses;
    mapping(uint256 => uint256) public eligibleAmounts;
    mapping(uint256 => uint256) public periodAccumulateAmount;
    mapping(uint256 => uint256[]) public periodWinnerIndex;

    uint256 public percentFirstWinner;
    uint256 public percentSecondWinner;
    uint256 public percentThirdWinner;
    uint256 public percentFourthWinner;
    uint256 public percentStaking;

    uint256 public percentTaxWithdrawlStaking;
    uint256 public percentTaxWithdrawlCharity;
    bool public isAutoPickWinnerEnable;

    event UpdateEligibleDays(uint256 _days);
    event ResetEligible(uint256 startingAt, uint256 endingAt, uint256 defaultDays);
    event UpdateCommittedTokenAddress(address _committedTokenAddress);
    event UpdateStakingAddress(address _stakingAddress);
    event UpdateCharityAddress(address _charityAddress);
    event UpdateRouterAddress(address _uniswapV2RouterAddress);
    event UpdateBusdAddress(address _busdAddress);
    event Buy(address _buyer, uint256 _amount, uint256 _numberOfTickets, uint256 _valueInBUSD, uint256 _amountBuy);
    event UpdatePercentWinner(uint256 _percentFirstWinner, uint256 _percentSecondWinner, uint256 _percentThirdWinner, uint256 _percentFourthWinner, uint256 _percentStaking);
    event UpdatePercentTaxClaim(uint256 _percentTaxWithdrawlStaking, uint256 _percentTaxWithdrawlCharity);
    event UpdateNFTAddress(address _nftAddress);
    event ClaimReward(address _claimer, uint256 _tokenId, uint256 _amount);
    event PricePerTicket(uint256 _pricePerTicket);
    event UpdateIsAutoPickWinnerEnable(bool state);

    constructor(
        address _commitedTokenAddress,
        address _charityAddress,
        address _nftAddress,
        address _usdtAddress
    )  ERC20Vault("Sakai Vault Protocol", "Vault") {
        committedTokenAddress = _commitedTokenAddress;
        stakingAddress = msg.sender;
        defaultEligibleDays = 5 days;
        eligibleIndex = 0;
        uniswapV2RouterAddress = getRouterAddress();
        busdAddress = _usdtAddress;
        nftAddress = _nftAddress;
        charityAddress = _charityAddress;

        percentFirstWinner = 30;
        percentSecondWinner = 10;
        percentThirdWinner = 8;
        percentFourthWinner = 5;
        percentStaking = 47;

        percentTaxWithdrawlStaking = 3;
        percentTaxWithdrawlCharity = 2;
        pricePerTicket = 10 * 10 ** 18;

        isAutoPickWinnerEnable = true;

    }

    receive() external payable {}

    function getRouterAddress() public view returns (address) {
        uint256 id;
        assembly {
            id := chainid()
        }
        if (id == 97) return 0xD99D1c33F9fC3444f8101754aBC46c52416550D1;
        else if (id == 56) return 0x10ED43C718714eb63d5aA57B78B54704E256024E;
        else if (id == 1) return 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
        else return 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    }

    function _resetEligible() internal {
        startingAt = block.timestamp;
        endingAt = startingAt + defaultEligibleDays;
        startEligibleIndex = eligibleIndex;
        startBalanceAmount = 0;
        periodEligible += 1;
        emit ResetEligible(startingAt, endingAt, defaultEligibleDays);
    }


    function resetEligible() public onlyOwner {
        require(block.timestamp > endingAt, "Raffle is still running");
        _resetEligible();
    }

    function stopEligible() public onlyOwner {
        require(block.timestamp > endingAt, "Raffle is still running");
        startingAt = 0;
        endingAt = 0;
    }

    function updatePricePerTicket(uint256 _pricePerTicket) public onlyOwner {
        pricePerTicket = _pricePerTicket;
        emit PricePerTicket(_pricePerTicket);
    }

    function updateIsAutoPickWinner(bool state) public onlyOwner {
        isAutoPickWinnerEnable = state;
        emit UpdateIsAutoPickWinnerEnable(state);
    }

    function updateDefaultEligibleDays(uint256 _days) public onlyOwner {
        defaultEligibleDays = _days;
        emit UpdateEligibleDays(_days);
    }

    function updateCommittedTokenAddress(address _committedTokenAddress) public onlyOwner {
        require(_committedTokenAddress != address(0), "Invalid address");
        committedTokenAddress = _committedTokenAddress;
        emit UpdateCommittedTokenAddress(_committedTokenAddress);
    }

    function updateStakingAddress(address _stakingAddress) public onlyOwner {
        require(_stakingAddress != address(0), "Invalid address");
        stakingAddress = _stakingAddress;
        emit UpdateStakingAddress(_stakingAddress);
    }

    function updateCharityAddress(address _charityAddress) public onlyOwner {
        require(_charityAddress != address(0), "Invalid address");
        charityAddress = _charityAddress;
        emit UpdateCharityAddress(_charityAddress);
    }

    function updateRouterAddress(address _uniswapV2RouterAddress) public onlyOwner {
        require(_uniswapV2RouterAddress != address(0), "Invalid address");
        uniswapV2RouterAddress = _uniswapV2RouterAddress;
        emit UpdateRouterAddress(_uniswapV2RouterAddress);
    }

    function updateBusdAddress(address _busdAddress) public onlyOwner {
        require(_busdAddress != address(0), "Invalid address");
        busdAddress = _busdAddress;
        emit UpdateBusdAddress(_busdAddress);
    }

    function updateNFTAddress(address _nftAddress) public onlyOwner {
        require(_nftAddress != address(0), "Invalid address");
        nftAddress = _nftAddress;
        emit UpdateNFTAddress(_nftAddress);
    }

    function updatePercentWinner(uint256 _percentFirstWinner, uint256 _percentSecondWinner, uint256 _percentThirdWinner, uint256 _percentFourthWinner, uint256 _percentStaking) public onlyOwner {
        percentFirstWinner = _percentFirstWinner;
        percentSecondWinner = _percentSecondWinner;
        percentThirdWinner = _percentThirdWinner;
        percentFourthWinner = _percentFourthWinner;
        percentStaking = _percentStaking;
        require(percentFirstWinner + percentSecondWinner + percentThirdWinner + percentFourthWinner + percentStaking == 100, "Total percent must be 100");
        emit UpdatePercentWinner(_percentFirstWinner, _percentSecondWinner, _percentThirdWinner, _percentFourthWinner, _percentStaking);
    }

    function updatePercentTaxClaim(uint256 _percentTaxWithdrawlStaking, uint256 _percentTaxWithdrawlCharity) public onlyOwner {
        percentTaxWithdrawlStaking = _percentTaxWithdrawlStaking;
        percentTaxWithdrawlCharity = _percentTaxWithdrawlCharity;
        require(percentTaxWithdrawlStaking + percentTaxWithdrawlCharity <= 25, "Total percent must be less than or equal to 25");
        emit UpdatePercentTaxClaim(_percentTaxWithdrawlStaking, _percentTaxWithdrawlCharity);
    }


    function buy(uint256 numberOfTickets) public returns (uint256[] memory) {
        require(startingAt > 0, "Raffle is not started");
        require(block.timestamp >= startingAt, "Raffle is not started");
        require(numberOfTickets > 0, "Amount must be greater than 0");

        if(isAutoPickWinnerEnable && block.timestamp >= endingAt && (eligibleIndex - startEligibleIndex >= 4)) _pickWinners(true);

        uint256 amountUSDT = numberOfTickets * pricePerTicket;
        address[] memory path = new address[](2);
        path[0] = busdAddress;
        path[1] = committedTokenAddress;
        uint[] memory amounts = IUniswapV2Router02Vault(uniswapV2RouterAddress).getAmountsOut(amountUSDT, path);
        IERC20Vault(committedTokenAddress).transferFrom(msg.sender, address(this), amounts[1]);
        uint256[] memory ticketIds = new uint256[](numberOfTickets);
        for (uint256 i = 0; i < numberOfTickets; i++) {
            ITheVaultTicker(nftAddress).mintNFT(msg.sender, eligibleIndex);
            eligibleAddresses[eligibleIndex] = msg.sender;
            ticketBuyers[eligibleIndex].ticketId = eligibleIndex;
            ticketBuyers[eligibleIndex].ownerAddress = msg.sender;
            ticketBuyers[eligibleIndex].buyAt = block.timestamp;
            ticketBuyers[eligibleIndex].amountUSD = pricePerTicket;
            ticketBuyers[eligibleIndex].period = periodEligible;
            ticketIds[i] = i;
            eligibleIndex++;
        }
        periodAccumulateAmount[periodEligible] += amounts[1];
        emit Buy(msg.sender, amounts[0], numberOfTickets, amountUSDT, amounts[0]);
        return ticketIds;
    }

    function _pickWinners(bool withRestart) internal {
        require(block.timestamp > endingAt, "Raffle is still running");
        require(eligibleIndex > startEligibleIndex, "No one is eligible");
        require((eligibleIndex - startEligibleIndex) >= 4, "Not enough eligible");
        uint256 randomFactor = 1001 + periodEligible;
        uint256 totalEligibleAmountPeriod = periodAccumulateAmount[periodEligible];
        uint256[] memory winnerIndex = getRandomNumbers(4, startEligibleIndex, eligibleIndex, randomFactor);

        periodWinnerIndex[periodEligible] = (winnerIndex);

        uint256 firstWinnerAmount = totalEligibleAmountPeriod * percentFirstWinner / 100;
        uint256 secondWinnerAmount = totalEligibleAmountPeriod * percentSecondWinner / 100;
        uint256 thirdWinnerAmount = totalEligibleAmountPeriod * percentThirdWinner / 100;
        uint256 fourthWinnerAmount = totalEligibleAmountPeriod * percentFourthWinner / 100;
        uint256 stakingAmount = totalEligibleAmountPeriod * percentStaking / 100;

        eligibleAmounts[winnerIndex[0]] = firstWinnerAmount;
        eligibleAmounts[winnerIndex[1]] = secondWinnerAmount;
        eligibleAmounts[winnerIndex[2]] = thirdWinnerAmount;
        eligibleAmounts[winnerIndex[3]] = fourthWinnerAmount;
        IERC20Vault(committedTokenAddress).transfer(stakingAddress, stakingAmount);

        ticketBuyers[winnerIndex[0]].amountReward = firstWinnerAmount;
        ticketBuyers[winnerIndex[1]].amountReward = secondWinnerAmount;
        ticketBuyers[winnerIndex[2]].amountReward = thirdWinnerAmount;
        ticketBuyers[winnerIndex[3]].amountReward = fourthWinnerAmount;
        totalLockedAmountForReward += firstWinnerAmount;
        totalLockedAmountForReward += secondWinnerAmount;
        totalLockedAmountForReward += thirdWinnerAmount;
        totalLockedAmountForReward += fourthWinnerAmount;

        if(withRestart) {
            _resetEligible();
        } else {
            startingAt = 0;
            endingAt = 0;
        }
    }

    function pickWinners(bool withRestart) public onlyOwner {
        _pickWinners(withRestart);
    }


    function getRandomNumbers(uint256 count, uint256 min, uint256 max, uint256 randomFactor) public returns (uint256[] memory) {
        require(count > 0, "Count must be greater than 0");
        require(min < max, "Invalid range");

        uint256[] memory randomNumbers = new uint256[](count);
        for (uint256 i = 0; i < count; i++) {
            randomNumbers[i] = getRandomNumber(min, (max-1), i, randomFactor);
            // Prevent duplicate random numbers
            for (uint256 j = 0; j < i; j++) {
                if (randomNumbers[j] == randomNumbers[i]) {
                    i--;
                    break;
                }
            }
        }

        return randomNumbers;
    }

    function getRandomNumber(uint256 min, uint256 max, uint256 loop, uint256 randomFactor) internal returns (uint256) {
        require(min < max, "Invalid range");
        pickWinnerLoop += 1;
        uint256 randomNumber = uint256(keccak256(abi.encodePacked(((block.timestamp*randomFactor) - (loop*pickWinnerLoop)), msg.sender, block.timestamp))) % (max - min + 1);
        return randomNumber + min;
    }

    function buyback(uint256 tokenId) public {
        require(eligibleAmounts[tokenId] > 0, "No reward");
        require(ITheVaultTicker(nftAddress).ownerOf(tokenId) == msg.sender, "You are not the owner");
        if(isAutoPickWinnerEnable && block.timestamp >= endingAt && (eligibleIndex - startEligibleIndex >= 4)) _pickWinners(true);

        uint256 amount = eligibleAmounts[tokenId];
        totalLockedAmountForReward -= amount;
        if(percentTaxWithdrawlStaking > 0){
            uint256 amountForStaking = amount * (percentTaxWithdrawlStaking) / 100;
            amount -= amountForStaking;
            IERC20Vault(committedTokenAddress).transfer(stakingAddress, amountForStaking);
        }
        if(percentTaxWithdrawlCharity > 0){
            uint256 amountForCharity = amount * (percentTaxWithdrawlCharity) / 100;
            amount -= amountForCharity;
            IERC20Vault(committedTokenAddress).transfer(charityAddress, amountForCharity);
        }
        eligibleAmounts[tokenId] = 0;
        ticketBuyers[tokenId].claimAt = block.timestamp;
        address nftOwner = ITheVaultTicker(nftAddress).ownerOf(tokenId);
        IERC20Vault(committedTokenAddress).transfer(nftOwner, amount);
        ITheVaultTicker(nftAddress).buyback(tokenId, owner());
        emit ClaimReward(nftOwner, tokenId, amount);
    }

    function getPeriodWinnerIndex(uint256 period) public view returns (uint256[] memory) {
        return periodWinnerIndex[period];
    }

    function getPeriodWinnerAddress(uint256 period) public view returns(address[] memory) {
        uint256[] memory winnerIndex = periodWinnerIndex[period];
        address[] memory winnerAddress = new address[](winnerIndex.length);
        for(uint256 i = 0; i < winnerIndex.length; i++) {
            winnerAddress[i] = ITheVaultTicker(nftAddress).ownerOf(winnerIndex[i]);
        }
        return winnerAddress;
    }

    function getCurrentPeriod() public view returns (uint256) {
        return periodEligible - 1;
    }

    function getEligibleByOwner(address _owner) public view returns(uint256[] memory){
        uint256 count = 0;
        for(uint256 i = 0; i < eligibleIndex; i++) {
            if(eligibleAddresses[i] == _owner) {
                count++;
            }
        }

        uint256[] memory indexes = new uint256[](count);

        uint256 selectedId = 0;
        for(uint256 i = 0; i < eligibleIndex; i++) {
            if(eligibleAddresses[i] == _owner) {
                indexes[selectedId] = i;
                selectedId++;
            }
        }
        return indexes;
    }
}