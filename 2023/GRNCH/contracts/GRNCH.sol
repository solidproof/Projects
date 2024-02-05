// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";

import "./lib/uniswap/IUniswapV2Router02.sol";
import "./lib/uniswap/IUniswapV2Factory.sol";

contract GRNCH is ERC20Burnable, Ownable {
    using Address for address payable;

    struct FeesConfig {
        uint256 buyFee;
        uint256 sellFee;
        uint256 burnSellFee;
        uint256 burnBuyFee;
        uint256 transferFee;
    }

    mapping(address => bool) private _excludedFromFees;
    uint256 private _swapTokensAtAmount;
    bool private _isSwapping;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    address public marketingWallet;
    FeesConfig public feesConfig;
    bool public isTradingEnabled;

    uint256 public maxTransactionAmount;
    uint256 public maxWalletAmount;

    uint256 public constant initialSupply = 10_000_000 * 10 ** 18;
    address public constant BURN_ADDRESS = address(0xdead);
    uint256 public constant MAX_TOTAL_FEES = 10; // 10%

    event ExcludedFromFeesUpdated(address account, bool isExcluded);
    event FeesConfigUpdated(FeesConfig config);
    event MarketingWalletUpdated(address account);
    event SwapTokensAtAmountUpdated(uint256 amount);
    event MaxTransactionAmountUpdated(uint256 amount);
    event MaxWalletAmountUpdated(uint256 amount);
    event SwapAndSendMarketing(uint256 swapped, uint256 sent);
    event TradingEnabled(bool isEnabled);

    constructor(address _router) ERC20("GRNCH", "GRNCH") {
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(_router);
        address _uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(
            address(this),
            _uniswapV2Router.WETH()
        );

        uniswapV2Router = _uniswapV2Router;
        uniswapV2Pair = _uniswapV2Pair;

        _approve(address(this), address(uniswapV2Router), type(uint256).max);

        marketingWallet = 0xf4554B6365a14788cFb8143F712285c084794971;
        feesConfig = FeesConfig({
            buyFee: 0,
            sellFee: 1,
            burnBuyFee: 0,
            burnSellFee: 1,
            transferFee: 0
        });

        _excludedFromFees[address(this)] = true;
        _excludedFromFees[owner()] = true;
        _excludedFromFees[marketingWallet] = true;
        _excludedFromFees[BURN_ADDRESS] = true;

        _mint(owner(), initialSupply);

        maxTransactionAmount = (totalSupply() * 10) / 1000; // 1%;
        maxWalletAmount = (totalSupply() * 30) / 1000; // 3%

        _swapTokensAtAmount = totalSupply() / 5_000; // 0.02%

        isTradingEnabled = false;
    }

    function isExcludedFromFees(address account) public view returns (bool) {
        return _excludedFromFees[account];
    }

    function setExcludedFromFees(address account, bool isExcluded) external onlyOwner {
        require(_excludedFromFees[account] != isExcluded, "Value already set");

        _excludedFromFees[account] = isExcluded;
        emit ExcludedFromFeesUpdated(account, isExcluded);
    }

    function setSwapTokensAtAmount(uint256 amount) external onlyOwner {
        require(amount > (totalSupply() / 1_000_000), "Value cannot be less than 0.0001%");

        _swapTokensAtAmount = amount;
        emit SwapTokensAtAmountUpdated(_swapTokensAtAmount);
    }

    function setMarketingWallet(address account) external onlyOwner {
        require(account != marketingWallet, "Value already set");
        require(account != address(0), "Invalid address");

        marketingWallet = account;
        emit MarketingWalletUpdated(marketingWallet);
    }

    function setMaxTransactionAmount(uint256 amount) external onlyOwner {
        require(amount >= (totalSupply() / 1_000), "Value cannot be less than 0.1%");

        maxTransactionAmount = amount;
        emit MaxTransactionAmountUpdated(amount);
    }

    function setMaxWalletAmount(uint256 amount) external onlyOwner {
        require(amount >= (totalSupply() / 100), "Value cannot be less than 1%");

        maxWalletAmount = amount;
        emit MaxWalletAmountUpdated(amount);
    }

    function setFeesConfig(FeesConfig memory config) external onlyOwner {
        uint256 totalFees = config.buyFee +
            config.sellFee +
            config.burnBuyFee +
            config.burnSellFee +
            config.transferFee;
        require(totalFees <= MAX_TOTAL_FEES, "Invalid fee");

        feesConfig = config;
        emit FeesConfigUpdated(feesConfig);
    }

    function enableTrading() external onlyOwner {
        require(!isTradingEnabled, "Value already set");

        isTradingEnabled = true;
        emit TradingEnabled(isTradingEnabled);
    }

    function _transfer(address from, address to, uint256 amount) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(
            isTradingEnabled || _excludedFromFees[from] || _excludedFromFees[to],
            "Trading not yet enabled!"
        );

        if (amount == 0) {
            super._transfer(from, to, 0);
            return;
        }

        if (
            (from == uniswapV2Pair || to == uniswapV2Pair) &&
            !_excludedFromFees[from] &&
            !_excludedFromFees[to]
        ) {
            require(
                amount <= maxTransactionAmount,
                "AntiWhale: Transfer amount exceeds the maxTransactionAmount"
            );
        }

        uint256 contractTokenBalance = balanceOf(address(this));
        bool isSwapAllowed = contractTokenBalance >= _swapTokensAtAmount;

        if (isSwapAllowed && !_isSwapping && to == uniswapV2Pair) {
            _isSwapping = true;

            swapAndSendMarketing(contractTokenBalance);

            _isSwapping = false;
        }

        uint256 fee;
        uint256 burnFee;
        if (_excludedFromFees[from] || _excludedFromFees[to] || _isSwapping) {
            fee = 0;
        } else if (from == uniswapV2Pair) {
            fee = feesConfig.buyFee;
            burnFee = feesConfig.burnBuyFee;
        } else if (to == uniswapV2Pair) {
            fee = feesConfig.sellFee;
            burnFee = feesConfig.burnSellFee;
        } else {
            fee = feesConfig.transferFee;
        }

        if (fee + burnFee > 0) {
            uint256 calculatedFee = (amount * fee) / 100;
            uint256 calculatedBurnFee = (amount * burnFee) / 100;

            amount = amount - calculatedFee - calculatedBurnFee;

            if (calculatedFee > 0) {
                super._transfer(from, address(this), calculatedFee);
            }

            if (calculatedBurnFee > 0) {
                super._transfer(from, BURN_ADDRESS, calculatedBurnFee);
            }
        }

        if (!_excludedFromFees[from] && !_excludedFromFees[to] && to != uniswapV2Pair) {
            uint256 balance = balanceOf(to);
            require(
                balance + amount <= maxWalletAmount,
                "AntiWhale: Recipient exceeds the maxWalletAmount"
            );
        }

        super._transfer(from, to, amount);
    }

    function swapAndSendMarketing(uint256 amount) private {
        uint256 initialBalance = address(this).balance;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amount,
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 newBalance = address(this).balance - initialBalance;

        payable(marketingWallet).sendValue(newBalance);
        emit SwapAndSendMarketing(amount, newBalance);
    }

    function claimStuckTokens(address token) external onlyOwner {
        require(token != address(this), "Owner cannot claim contract's balance");
        if (token == address(0x0)) {
            payable(msg.sender).sendValue(address(this).balance);
            return;
        }
        IERC20 ERC20token = IERC20(token);
        uint256 balance = ERC20token.balanceOf(address(this));
        ERC20token.transfer(msg.sender, balance);
    }

    receive() external payable {}
}
