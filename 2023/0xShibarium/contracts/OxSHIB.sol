// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@chainlink/contracts/src/v0.8/interfaces/AggregatorV3Interface.sol";

contract ZeroXShibarium is Context, ERC20, Ownable {
    using SafeERC20 for IERC20;
    using Address for address;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    _ZeroXShibariumWallets public ZeroXShibariumWallets;
    _burnData public burnData;
    _buyTaxes public buyTaxes;
    _sellTaxes public sellTaxes;

    mapping(address => bool) public pair;
    mapping (address => bool) public _isExcludedFromFees;

    uint256 private start;
    uint256 private end;

    uint256 public swapTokensAtAmount;

    bool public swapping;
    bool public taxDisabled;

    uint256 private maxWalletTimer;
    uint256 private started;
    uint256 private maxWallet;
    uint256 private _supply;

    // @dev All wallets are multi-sig gnosis safe's
    struct _ZeroXShibariumWallets {
        address payable cexWallet;
        address payable marketingWallet;
        address payable devWallet;
        address payable platformWallet;
    }

    struct _burnData {
        uint256 burnCounter;
        uint256 amountToBurn;
        uint256 burnRemaining;
        uint256[] burnMilestones;
        bool burning;
    }

    struct _buyTaxes {
        uint256 devFee;
        uint256 marketingFee;
        uint256 totalBuyFees;
    }

    struct _sellTaxes {
        uint256 devFee;
        uint256 marketingFee;
        uint256 totalSellFees;
    }

    event swapRouterUpdated(
        address newRouter
    );

    event TaxesSent(
        address taxWallet,
        uint256 ETHAmount
    );

    event FeesUpdated(
        uint256 DevFee,
        uint256 MarketingFee
    );

    event TradingPairAdded(
        address indexed newPair
    );

    event TokensBurned(
        address indexed burner,
        uint256 amount
    );

    event BurnFailed();

    constructor(address payable _cexWallet, address payable _marketingWallet, address payable _devWallet, address payable _platformWallet, uint256 _end, uint256 _maxWalletTimer) ERC20("0xS", "$0xS") {

        uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D); // Router address for Uniswap
        address _pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());

        pair[_pair] = true;
        uniswapV2Pair = address(0);

        setBuyFees(20,30);
        setSellFees(20,30);

        ZeroXShibariumWallets.cexWallet = payable(_cexWallet);
        ZeroXShibariumWallets.marketingWallet = payable(_marketingWallet);
        ZeroXShibariumWallets.devWallet = payable(_devWallet);
        ZeroXShibariumWallets.platformWallet = payable(_platformWallet);

        _supply = 1 * 10 ** 8 * 10 ** decimals();
        started = block.timestamp;
        end = _end;
        maxWallet = ((_supply * 75) / 10000); // Max wallet of 0.75% of total supply
        maxWalletTimer = _maxWalletTimer;
        swapTokensAtAmount = ((_supply * 25) / 10000); // Swap 0.25% of total supply

        burnData.burnCounter = 0;
        burnData.burning = true;
        burnData.burnRemaining = ((_supply * 200) / 1000); // Total amount to be burnt
        burnData.amountToBurn = burnData.burnRemaining / 4;
        burnData.burnMilestones = [(1000000 * 1e18), (2000000 * 1e18), (4000000 * 1e18), (6000000 * 1e18)];

        _isExcludedFromFees[address(this)] = true;
        _isExcludedFromFees[owner()] = true;

        _mint(owner(), ((_supply * 500) / 1000)); // 55% of total supply for initial liquidity
        _mint(_marketingWallet, ((_supply * 50) / 1000)); // Tokens to be sent to marketing wallet 5% of total supply
        _mint(_cexWallet, ((_supply * 100) / 1000)); // Tokens to be sent to development wallet 10& of total supply
        _mint(_platformWallet, ((_supply * 150) / 1000)); // Tokens to be sent to platform wallet 15% of total supply
        _mint(address(this), burnData.burnRemaining); // Tokens reserved in contract to be automatically burnt over time 40% of total supply
    }

    receive() external payable {

  	}

    function setBuyFees(
        uint256 _devFee,
        uint256 _marketingFee
    ) public onlyOwner {
        require((_devFee + _marketingFee) <= 50, "Taxes cannot exceed 5%");

        buyTaxes.devFee = _devFee;
        buyTaxes.marketingFee = _marketingFee;
        buyTaxes.totalBuyFees = (_devFee + _marketingFee);

        emit FeesUpdated(_devFee, _marketingFee);
    }

    function setSellFees(
        uint256 _devFee,
        uint256 _marketingFee
    ) public onlyOwner {
        require((_devFee + _marketingFee) <= 50, "Taxes cannot exceed 5%");

        sellTaxes.devFee = _devFee;
        sellTaxes.marketingFee = _marketingFee;
        sellTaxes.totalSellFees = (_devFee + _marketingFee);

        emit FeesUpdated(_devFee, _marketingFee);
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount * 10 ** decimals());
    }

    function addPair(address toPair) public onlyOwner {
        if(uniswapV2Pair == address(0)) {
            uniswapV2Pair = toPair;
            start = block.number;
        } else {
            require(!pair[toPair], "This pair already exists");

            pair[toPair] = true;
        }

        emit TradingPairAdded(toPair);
    }

    function updateRouterAddress(address _router) public onlyOwner {
        require(_router != address(uniswapV2Router), "This is already the router address");

         uniswapV2Router = IUniswapV2Router02(_router);

         emit swapRouterUpdated(_router);
    }

    function getPriceInUSD() public view returns (uint256) {
        // Import the Chainlink AggregatorV3Interface contract
        AggregatorV3Interface ethUsdPriceFeed = AggregatorV3Interface(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419); // ETH/USD Price Feed

        address pairAddress = IUniswapV2Factory(uniswapV2Router.factory()).getPair(address(this), uniswapV2Router.WETH());
        (uint112 reserve0, uint112 reserve1, ) = IUniswapV2Pair(pairAddress).getReserves();

        // Ensure non-zero reserves
        require(reserve0 > 0 && reserve1 > 0, "Reserves are zero");

        uint256 tokenPriceInETH;

        if (address(this) < uniswapV2Router.WETH()) { // token is token0
            tokenPriceInETH = (uint256(reserve1) * 10**decimals()) / reserve0;
        } else { // token is token1
            tokenPriceInETH = (uint256(reserve0) * 10**decimals()) / reserve1;
        }

        // Get the price of ETH in USD from Chainlink
        (, int price,, ,) = ethUsdPriceFeed.latestRoundData();
        uint8 chainlinkDecimals = ethUsdPriceFeed.decimals();

        // Adjust for Chainlink's decimals
        uint256 adjustedEthPriceInUSD = uint256(price) * 10**(decimals() - chainlinkDecimals);

        uint256 tokenPrice = (tokenPriceInETH * adjustedEthPriceInUSD) / 10**decimals();

        // Calculate the MC in USD
        uint256 mcUsd = ((tokenPrice * totalSupply()) / 10 ** decimals());

        return mcUsd;
    }

    function burnTokensAtMC() private {
        if(burnData.burning && burnData.burnCounter < burnData.burnMilestones.length) {
            uint256 mcUSD = getPriceInUSD();
            if(mcUSD > burnData.burnMilestones[burnData.burnCounter]) {
                uint256 amount = burnData.amountToBurn;
                _burn(address(this), amount);
                burnData.burnRemaining -= amount;
                burnData.burnCounter++;

                emit TokensBurned(address(this), amount);

                if(burnData.burnRemaining == 0) {
                    burnData.burning = false;
                }
            }
        }
    }

    function burnRemaining() public onlyOwner { // Function to burn remaining tokens in case of issue at higher MC
        require(burnData.burning, "Burning is already completed");

        uint256 amount = burnData.burnRemaining;
        _burn(address(this), amount);
        burnData.burnRemaining = 0;

        burnData.burning = false;
        
        emit TokensBurned(address(this), amount);
    }

    function updateSwapAmount(uint256 newSwapAmount) public onlyOwner {
        swapTokensAtAmount = newSwapAmount * 10 ** decimals();
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if(uniswapV2Pair != address(0)) {
            burnTokensAtMC();
        }
        
        if(uniswapV2Pair == address(0) && from != owner() && to != owner()) {
            revert("Trading is not yet active");
        }

        uint256 current = block.number;

        if((block.timestamp < (started + maxWalletTimer)) && to != address(0) && to != uniswapV2Pair && !_isExcludedFromFees[to] && !_isExcludedFromFees[from]) {
            uint256 balance = balanceOf(to);
            require(balance + amount <= maxWallet, "Transfer amount exceeds maximum wallet");
        }

		uint256 contractTokenBalance = (balanceOf(address(this)) - burnData.burnRemaining);
        bool canSwap = contractTokenBalance >= swapTokensAtAmount;
		
		if(canSwap && !swapping && pair[to] && from != address(uniswapV2Router) && from != owner() && to != owner() && !_isExcludedFromFees[to] && !_isExcludedFromFees[from]) {

		    contractTokenBalance = swapTokensAtAmount;
            
            swapping = true;
            

            if (sellTaxes.totalSellFees > 0) {
                
                swapTokensForEth(contractTokenBalance);
                
                if (sellTaxes.devFee > 0) {
                    uint256 devAmount = ((address(this).balance * sellTaxes.devFee) / sellTaxes.totalSellFees);
                    (bool success, ) = address(ZeroXShibariumWallets.devWallet).call{value: devAmount}("");
                    require(success, "Failed to send dev fee");

                    emit TaxesSent(address(ZeroXShibariumWallets.devWallet), devAmount);
                }

                if (sellTaxes.marketingFee > 0) {
                    uint256 marketingAmount = address(this).balance;
                    (bool success, ) = address(ZeroXShibariumWallets.marketingWallet).call{value: marketingAmount}("");
                    require(success, "Failed to send marketing fee");

                    emit TaxesSent(address(ZeroXShibariumWallets.marketingWallet), marketingAmount);
                }
            }
            swapping = false;
        }

        bool takeFee = !swapping;

         // if any account belongs to _isExcludedFromFee account then remove the fee
        if(_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
            super._transfer(from, to, amount);
        }

        else if(current <= start + end && !_isExcludedFromFees[from] && !_isExcludedFromFees[to] && !pair[to]) {
            require(tx.gasprice <= block.basefee + 7 gwei, "Gas price too high");
            uint256 balance = balanceOf(to);
            require(balance + amount <= ((totalSupply() * 5) / 1000), "Transfer amount exceeds maximum wallet");
        }

        else if(!pair[to] && !pair[from] && !_isExcludedFromFees[from] && !_isExcludedFromFees[to]) {
            takeFee = false;
            super._transfer(from, to, amount);
        }

        if(takeFee) {

            uint256 BuyFees = ((amount * buyTaxes.totalBuyFees) / 1000);
            uint256 SellFees = ((amount * sellTaxes.totalSellFees) / 1000);

            // if sell
            if(pair[to] && sellTaxes.totalSellFees > 0) {
                amount -= SellFees;
                
                super._transfer(from, address(this), SellFees);
                super._transfer(from, to, amount);
            }

            // if buy transfer
            else if(pair[from] && buyTaxes.totalBuyFees > 0) {
                amount -= BuyFees;

                super._transfer(from, address(this), BuyFees);
                super._transfer(from, to, amount);
                }

            else {
                super._transfer(from, to, amount);
            }
        }
    }

    function swapTokensForEth(uint256 tokenAmount) private {

        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }
}