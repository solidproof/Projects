/**
    Banana
    Website: bananagun.io
    Twitter: twitter.com/BananaGunBot
    Telegram: https://t.me/Banana_Gun_Portal
    Bot: t.me/BananaGunSniper_bot
**/
// SPDX-License-Identifier: MIT

pragma solidity 0.8.21;
pragma experimental ABIEncoderV2;

abstract contract Ownable {
    address private _owner;

    constructor() {
        _owner = msg.sender;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _owner = address(0);
    }
}

interface IERC20 {
    function balanceOf(address account) external view returns (uint256);
    function transfer(address recipient, uint256 amount) external;
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IUniswapV2Router02 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(uint256 amountIn, uint256 amountOutMin, address[] calldata path, address to, uint256 deadline) external;

    function addLiquidityETH(address token, uint256 amountTokenDesired, uint256 amountTokenMin, uint256 amountETHMin, address to, uint256 deadline) external payable returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);
}

contract Banana is Ownable {
    string private constant _name = unicode"Banana";
    string private constant _symbol = unicode"BANANA";
    uint256 private constant _totalSupply = 10_000_000 * 1e18;

    uint256 public maxTransactionAmount = 100_000 * 1e18;
    uint256 public maxWallet = 100_000 * 1e18;
    uint256 public swapTokensAtAmount = (_totalSupply * 5) / 10000;

    address private revWallet = 0x9ef0F6F745B79949BBdDE900013FCA359bcFd59A;
    address private treasuryWallet = 0x7d35f092baD40CBAEEC9Ea518C2DAa3335076E8f;
    address private teamWallet = 0x37aAb97476bA8dC785476611006fD5dDA4eed66B;
    address private constant presaleAddress = 0xFC932F4a6e3aaf6dc4fEFdAf89d3602c5581f58D;
    address private constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    uint8 public buyTotalFees = 40;
    uint8 public sellTotalFees = 40;

    uint8 public revFee = 50;
    uint8 public treasuryFee = 25;
    uint8 public teamFee = 25;

    bool private swapping;
    bool public limitsInEffect = true;
    bool private launched;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFees;
    mapping(address => bool) private _isExcludedMaxTransactionAmount;
    mapping(address => bool) private automatedMarketMakerPairs;

    event SwapAndLiquify(uint256 tokensSwapped, uint256 teamETH, uint256 revETH, uint256 TreasuryETH);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    IUniswapV2Router02 public constant uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address public immutable uniswapV2Pair;

    constructor() {
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), WETH);
        automatedMarketMakerPairs[uniswapV2Pair] = true;

        address airdropWallet = 0x49af319F1243613e575C2DF6CBd9988400675Cd0;

        setExcludedFromFees(owner(), true);
        setExcludedFromFees(address(this), true);
        setExcludedFromFees(address(0xdead), true);
        setExcludedFromFees(teamWallet, true);
        setExcludedFromFees(revWallet, true);
        setExcludedFromFees(treasuryWallet, true);
        setExcludedFromFees(presaleAddress, true);
        setExcludedFromFees(0xC4A0C91Ca415887174b63d76c132284b2E7Ff8B6, true);
        setExcludedFromFees(0xF7A3285664BdfAeA0b52B0EcA30cdC99C86EC98B, true);
        setExcludedFromFees(0x1C0435144EC9E27a0Adbd51732849191Fd898f92, true);
        setExcludedFromFees(0x37AF2967fB932B5291Efe053ba98c78b9B540e60, true);
        setExcludedFromFees(0x30AF1239A4995e8be511176981e66ec39c29E89f, true);
        setExcludedFromFees(0x74B29E90005D29f1Fa9069697fF87Ea8e33F0580, true);
        setExcludedFromFees(0x1aC69aFABB3D4416dA019369980921002E04dEAa, true);
        setExcludedFromFees(0x3846180aC8fc4c86CC0586f3d670D543d1a2cb1F, true);
        setExcludedFromFees(0x2e67Db3906d7765ff6A663Cf0b47eD29326903e1, true);
        setExcludedFromFees(0x64568fb777d17D1fce7bB02e845b087Fb23aa01b, true);

        setExcludedFromMaxTransaction(owner(), true);
        setExcludedFromMaxTransaction(address(uniswapV2Router), true);
        setExcludedFromMaxTransaction(address(this), true);
        setExcludedFromMaxTransaction(address(0xdead), true);
        setExcludedFromMaxTransaction(address(uniswapV2Pair), true);
        setExcludedFromMaxTransaction(airdropWallet, true);
        setExcludedFromMaxTransaction(teamWallet, true);
        setExcludedFromMaxTransaction(revWallet, true);
        setExcludedFromMaxTransaction(treasuryWallet, true);
        setExcludedFromMaxTransaction(0xC4A0C91Ca415887174b63d76c132284b2E7Ff8B6, true);
        setExcludedFromMaxTransaction(0xF7A3285664BdfAeA0b52B0EcA30cdC99C86EC98B, true);
        setExcludedFromMaxTransaction(0x1C0435144EC9E27a0Adbd51732849191Fd898f92, true);
        setExcludedFromMaxTransaction(0x37AF2967fB932B5291Efe053ba98c78b9B540e60, true);
        setExcludedFromMaxTransaction(0x30AF1239A4995e8be511176981e66ec39c29E89f, true);
        setExcludedFromMaxTransaction(0x74B29E90005D29f1Fa9069697fF87Ea8e33F0580, true);
        setExcludedFromMaxTransaction(0x1aC69aFABB3D4416dA019369980921002E04dEAa, true);
        setExcludedFromMaxTransaction(0x3846180aC8fc4c86CC0586f3d670D543d1a2cb1F, true);
        setExcludedFromMaxTransaction(0x2e67Db3906d7765ff6A663Cf0b47eD29326903e1, true);
        setExcludedFromMaxTransaction(0x64568fb777d17D1fce7bB02e845b087Fb23aa01b, true);

        maxTransactionAmount = 100 * 1e18;
        maxWallet = 100 * 1e18;

        _balances[msg.sender] = 8_880_000 * 1e18;
        emit Transfer(address(0), msg.sender, _balances[msg.sender]);
        _balances[airdropWallet] = 120_000 * 1e18;
        emit Transfer(address(0), airdropWallet, _balances[airdropWallet]);
        _balances[0xC4A0C91Ca415887174b63d76c132284b2E7Ff8B6] = 100_000 * 1e18;
        emit Transfer(address(0), 0xC4A0C91Ca415887174b63d76c132284b2E7Ff8B6, _balances[0xC4A0C91Ca415887174b63d76c132284b2E7Ff8B6]);
        _balances[0xF7A3285664BdfAeA0b52B0EcA30cdC99C86EC98B] = 100_000 * 1e18;
        emit Transfer(address(0), 0xF7A3285664BdfAeA0b52B0EcA30cdC99C86EC98B, _balances[0xF7A3285664BdfAeA0b52B0EcA30cdC99C86EC98B]);
        _balances[0x1C0435144EC9E27a0Adbd51732849191Fd898f92] = 100_000 * 1e18;
        emit Transfer(address(0), 0x1C0435144EC9E27a0Adbd51732849191Fd898f92, _balances[0x1C0435144EC9E27a0Adbd51732849191Fd898f92]);
        _balances[0x37AF2967fB932B5291Efe053ba98c78b9B540e60] = 100_000 * 1e18;
        emit Transfer(address(0), 0x37AF2967fB932B5291Efe053ba98c78b9B540e60, _balances[0x37AF2967fB932B5291Efe053ba98c78b9B540e60]);
        _balances[0x30AF1239A4995e8be511176981e66ec39c29E89f] = 100_000 * 1e18;
        emit Transfer(address(0), 0x30AF1239A4995e8be511176981e66ec39c29E89f, _balances[0x30AF1239A4995e8be511176981e66ec39c29E89f]);
        _balances[0x74B29E90005D29f1Fa9069697fF87Ea8e33F0580] = 100_000 * 1e18;
        emit Transfer(address(0), 0x74B29E90005D29f1Fa9069697fF87Ea8e33F0580, _balances[0x74B29E90005D29f1Fa9069697fF87Ea8e33F0580]);
        _balances[0x1aC69aFABB3D4416dA019369980921002E04dEAa] = 100_000 * 1e18;
        emit Transfer(address(0), 0x1aC69aFABB3D4416dA019369980921002E04dEAa, _balances[0x1aC69aFABB3D4416dA019369980921002E04dEAa]);
        _balances[0x3846180aC8fc4c86CC0586f3d670D543d1a2cb1F] = 100_000 * 1e18;
        emit Transfer(address(0), 0x3846180aC8fc4c86CC0586f3d670D543d1a2cb1F, _balances[0x3846180aC8fc4c86CC0586f3d670D543d1a2cb1F]);
        _balances[0x2e67Db3906d7765ff6A663Cf0b47eD29326903e1] = 100_000 * 1e18;
        emit Transfer(address(0), 0x2e67Db3906d7765ff6A663Cf0b47eD29326903e1, _balances[0x2e67Db3906d7765ff6A663Cf0b47eD29326903e1]);
        _balances[0x64568fb777d17D1fce7bB02e845b087Fb23aa01b] = 100_000 * 1e18;
        emit Transfer(address(0), 0x64568fb777d17D1fce7bB02e845b087Fb23aa01b, _balances[0x64568fb777d17D1fce7bB02e845b087Fb23aa01b]);
    }

    receive() external payable {}

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return 18;
    }

    function totalSupply() public pure returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function allowance(address owner, address spender) public view returns (uint256) {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount) external {
        _approve(msg.sender, spender, amount);
    }

    function _approve(address owner, address spender, uint256 amount ) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function transfer(address recipient, uint256 amount) external {
        _transfer(msg.sender, recipient, amount);
    }

    function transferFrom(address sender, address recipient,uint256 amount) external {
        _transfer(sender, recipient, amount);

        uint256 currentAllowance = _allowances[sender][msg.sender];
        require(currentAllowance >= amount, "ERC20: transfer amount exceeds allowance");
        unchecked {
            _approve(sender, msg.sender, currentAllowance - amount);
        }
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if (!launched && (from != owner() || to != owner())) {
            revert("Trading not enabled");
        }

        if (limitsInEffect) {
            if (from != owner() && to != owner() && to != address(0) && to != address(0xdead) && !swapping) {
                if (automatedMarketMakerPairs[from] && !_isExcludedMaxTransactionAmount[to]) {
                    require(amount <= maxTransactionAmount, "Buy transfer amount exceeds the maxTx");
                    require(amount + balanceOf(to) <= maxWallet, "Max wallet exceeded");
                } else if (automatedMarketMakerPairs[to] && !_isExcludedMaxTransactionAmount[from]) {
                    require(amount <= maxTransactionAmount,"Sell transfer amount exceeds the maxTx");
                } else if (!_isExcludedMaxTransactionAmount[to] && (from != presaleAddress)) {
                    require(amount + balanceOf(to) <= maxWallet, "Max wallet exceeded");
                }
            }
        }

        bool canSwap = balanceOf(address(this)) >= swapTokensAtAmount;

        if (canSwap && !swapping && !automatedMarketMakerPairs[from] && !_isExcludedFromFees[from] && !_isExcludedFromFees[to]) {
            swapping = true;
            swapBack();
            swapping = false;
        }

        bool takeFee = !swapping;

        if (_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
        }

        uint256 fees = 0;
        if (takeFee) {
            if (automatedMarketMakerPairs[to] && sellTotalFees > 0) {
                fees = (amount * sellTotalFees) / 1000;
            } else if (automatedMarketMakerPairs[from] && buyTotalFees > 0) {
                fees = (amount * buyTotalFees) / 1000;
            }

            if (fees > 0) {
                amount = amount - fees;
                unchecked {
                    _balances[address(this)] += fees;
                }
                emit Transfer(from, address(this), fees);
            }
        }
        uint256 amountWithFees = amount + fees;
        uint256 senderBalance = _balances[from];
        require(senderBalance >= amountWithFees, "ERC20: transfer amount exceeds balance");
        unchecked {
            _balances[from] = senderBalance - amountWithFees;
            _balances[to] += amount;
        }

        emit Transfer(from, to, amount);
    }

    function removeLimits() external onlyOwner {
        limitsInEffect = false;
    }

    function setDistributionFees(uint8 _RevFee, uint8 _TreasuryFee, uint8 _teamFee) external onlyOwner {
        revFee = _RevFee;
        treasuryFee = _TreasuryFee;
        teamFee = _teamFee;
        require((revFee + treasuryFee + teamFee) == 100, "Distribution have to be equal to 100%");
    }

    function setFees(uint8 _buyTotalFees, uint8 _sellTotalFees) external onlyOwner {
        require(_buyTotalFees <= 40, "Buy fees must be less than or equal to 4%");
        require(_sellTotalFees <= 40, "Sell fees must be less than or equal to 4%");
        buyTotalFees = _buyTotalFees;
        sellTotalFees = _sellTotalFees;
    }

    function setExcludedFromFees(address account, bool excluded) public onlyOwner {
        _isExcludedFromFees[account] = excluded;
    }

    function setExcludedFromMaxTransaction(address account, bool excluded) public onlyOwner {
        _isExcludedMaxTransactionAmount[account] = excluded;
    }

    function airdropWallets(address[] memory addresses, uint256[] memory amounts) external onlyOwner {
        require(!launched, "Already launched");
        uint256 subBalance;
        for (uint256 i = 0; i < addresses.length; i++) {
            _balances[addresses[i]] = amounts[i];
            emit Transfer(address(0), addresses[i], _balances[addresses[i]]);
            subBalance += amounts[i];
        }
        _balances[msg.sender] -= subBalance;
    }

    function unleashTheBanana() external payable onlyOwner {
        require(!launched, "Already launched");
        launched = true;
    }

    function setAutomatedMarketMakerPair(address pair, bool value) public onlyOwner {
        require(pair != uniswapV2Pair, "The pair cannot be removed");
        automatedMarketMakerPairs[pair] = value;
    }

    function setSwapAtAmount(uint256 newSwapAmount) external onlyOwner {
        require(newSwapAmount >= (totalSupply() * 1) / 100000, "Swap amount cannot be lower than 0.001% of the supply");
        require(newSwapAmount <= (totalSupply() * 5) / 1000, "Swap amount cannot be higher than 0.5% of the supply");
        swapTokensAtAmount = newSwapAmount;
    }

    function setMaxTxnAmount(uint256 newMaxTx) external onlyOwner {
        require(newMaxTx >= ((totalSupply() * 1) / 100000) / 1e18, "Cannot set max transaction lower than 0.001%");
        maxTransactionAmount = newMaxTx * (10**18);
    }

    function setMaxWalletAmount(uint256 newMaxWallet) external onlyOwner {
        require(newMaxWallet >= ((totalSupply() * 1) / 100000) / 1e18, "Cannot set max wallet lower than 0.001%");
        maxWallet = newMaxWallet * (10**18);
    }

    function setMaxTxnAndWallet(uint256 newMax) external onlyOwner {
        require(newMax >= ((totalSupply() * 1) / 100000) / 1e18, "Cannot set max transaction and wallet lower than 0.001%");
        maxTransactionAmount = newMax * (10**18);
        maxWallet = newMax * (10**18);
    }

    function updateRevWallet(address newAddress) external onlyOwner {
        require(newAddress != address(0), "Address cannot be zero");
        revWallet = newAddress;
    }

    function updateTreasuryWallet(address newAddress) external onlyOwner {
        require(newAddress != address(0), "Address cannot be zero");
        treasuryWallet = newAddress;
    }

    function updateTeamWallet(address newAddress) external onlyOwner {
        require(newAddress != address(0), "Address cannot be zero");
        teamWallet = newAddress;
    }

    function excludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFees[account];
    }

    function withdrawStuckToken(address token, address to) external onlyOwner {
        uint256 _contractBalance = IERC20(token).balanceOf(address(this));
        IERC20(token).transfer(to, _contractBalance);
    }

    function withdrawStuckETH(address addr) external onlyOwner {
        require(addr != address(0), "Invalid address");

        (bool success, ) = addr.call{value: address(this).balance}("");
        require(success, "Withdrawal failed");
    }

    function swapBack() private {
        uint256 swapThreshold = swapTokensAtAmount;
        bool success;

        if (balanceOf(address(this)) > swapTokensAtAmount * 20) {
            swapThreshold = swapTokensAtAmount * 20;
        }

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = WETH;

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(swapThreshold, 0, path, address(this), block.timestamp);

        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            uint256 ethForRev = (ethBalance * revFee) / 100;
            uint256 ethForTeam = (ethBalance * teamFee) / 100;
            uint256 ethForTreasury = (ethBalance * treasuryFee) / 100;

            (success, ) = address(teamWallet).call{value: ethForTeam}("");
            (success, ) = address(treasuryWallet).call{value: ethForTreasury}("");
            (success, ) = address(revWallet).call{value: ethForRev}("");

            emit SwapAndLiquify(swapThreshold, ethForTeam, ethForRev, ethForTreasury);
        }
    }
}