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

import "./IShibaBurn.sol";

contract Koyo is Context, ERC20, Ownable {
    using SafeERC20 for IERC20;
    using Address for address;

    IShibaBurn public ShibaBurn;
    IUniswapV2Router02 public uniswapV2Router;
    address public immutable uniswapV2Pair;

    _koyoWallets public koyoWallets;
    _burnData public burnData;
    _buyTaxes public buyTaxes;
    _sellTaxes public sellTaxes;

    mapping(address => bool) public pair;
    mapping (address => bool) public _isExcludedFromFees;

    address private constant SHIB = address(0x95aD61b0a150d79219dCF64E1E6Cc01f0B64C4cE);
    address private constant ShibaBurnAddress = address(0x88f09b951F513fe7dA4a34B436a3273DE59F253D);

    uint256 private start;
    uint256 private end;

    bool public starting;
    bool public swapping;

    uint256 private maxWalletTimer;
    uint256 private started;
    uint256 private maxWallet;

    uint256 private _supply;

    struct _koyoWallets {
        address payable liquidityWallet;
        address payable marketingWallet;
        address payable devWallet;
    }

    struct _burnData {
        uint256 burnTimer;
        uint256 burnOverTime;
        uint256 lastBurnTime;
        uint256 amountToBurn;
    }

    struct _buyTaxes {
        uint256 burnShibaFee;
        uint256 liquidityFee;
        uint256 devFee;
        uint256 marketingFee;
        uint256 burnFee;
        uint256 totalBuyFees;
    }

    struct _sellTaxes {
        uint256 burnShibaFee;
        uint256 liquidityFee;
        uint256 devFee;
        uint256 marketingFee;
        uint256 burnFee;
        uint256 totalSellFees;
    }

    event TaxesSent(
        address taxWallet,
        uint256 ETHAmount
    );

    event SwapAndLiquify(
        uint256 liquidityETH,
        uint256 half
    );   

    event FeesUpdated(
        uint256 BurnShibaFee,
        uint256 LiquidityFee,
        uint256 DevFee,
        uint256 MarketingFee,
        uint256 BurnFee
    );

    constructor(address payable _liquidityWallet, address payable _marketingWallet, address payable _devWallet) ERC20("KOYO", "KOY") {

        ShibaBurn = IShibaBurn(payable(address(ShibaBurnAddress)));
        uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

        address _pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());

        pair[_pair] = true;
        uniswapV2Pair = _pair;
        
        _setBuyFees(20,5,10,10,5);
        _setSellFees(20,5,10,10,5);

        _supply = 5 * 10 ** 8 * 10 ** decimals();

        starting = true;
        started = block.timestamp;
        end = 0;
        maxWallet = 1 * 10 ** 7 * 10 ** decimals();
        maxWalletTimer = 604800;

        koyoWallets.liquidityWallet = payable(_liquidityWallet);
        koyoWallets.marketingWallet = payable(_marketingWallet);
        koyoWallets.devWallet = payable(_devWallet);

        burnData.burnOverTime = _supply;
        burnData.amountToBurn = burnData.burnOverTime / 10;
        burnData.burnTimer = 604800;
        burnData.lastBurnTime = started;

        _isExcludedFromFees[address(this)] = true;
        _isExcludedFromFees[owner()] = true;

        _mint(msg.sender, _supply);
        _mint(address(this), _supply);
    }

    receive() external payable {

  	}

    function setBuyFees(
        uint256 _burnShibaFee,
        uint256 _liquidityFee,
        uint256 _devFee,
        uint256 _marketingFee,
        uint256 _burnFee
    ) external onlyOwner {
        require((_burnShibaFee + _liquidityFee + _devFee + _marketingFee + _burnFee) <= 50, "Taxes cannot exceed 5%");
        _setBuyFees(_burnShibaFee, _liquidityFee, _devFee, _marketingFee, _burnFee);
    }

    function _setBuyFees(
        uint256 _burnShibaFee,
        uint256 _liquidityFee,
        uint256 _devFee,
        uint256 _marketingFee,
        uint256 _burnFee
    ) internal {
        buyTaxes.burnShibaFee = _burnShibaFee;
        buyTaxes.liquidityFee = _liquidityFee;
        buyTaxes.devFee = _devFee;
        buyTaxes.marketingFee = _marketingFee;
        buyTaxes.burnFee = _burnFee;
        buyTaxes.totalBuyFees = (_burnShibaFee + _liquidityFee + _devFee + _marketingFee + _burnFee);

        emit FeesUpdated(_burnShibaFee, _liquidityFee, _devFee, _marketingFee, _burnFee);
    }

    function setSellFees(
        uint256 _burnShibaFee,
        uint256 _liquidityFee,
        uint256 _devFee,
        uint256 _marketingFee,
        uint256 _burnFee
    ) external onlyOwner {
        require((_burnShibaFee + _liquidityFee + _devFee + _marketingFee + _burnFee) <= 50, "Taxes cannot exceed 5%");
        _setSellFees(_burnShibaFee, _liquidityFee, _devFee, _marketingFee, _burnFee);
    }

    function _setSellFees(
        uint256 _burnShibaFee,
        uint256 _liquidityFee,
        uint256 _devFee,
        uint256 _marketingFee,
        uint256 _burnFee
    ) internal {
        sellTaxes.burnShibaFee = _burnShibaFee;
        sellTaxes.liquidityFee = _liquidityFee;
        sellTaxes.devFee = _devFee;
        sellTaxes.marketingFee = _marketingFee;
        sellTaxes.burnFee = _burnFee;
        sellTaxes.totalSellFees = (_burnShibaFee + _liquidityFee + _devFee + _marketingFee + _burnFee);

        emit FeesUpdated(_burnShibaFee, _liquidityFee, _devFee, _marketingFee, _burnFee);
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount * 10 ** decimals());
    }

    function addPair(address toPair) public onlyOwner {
        require(!pair[toPair], "This pair already exists");

        pair[toPair] = true;
    }

    function burnTokensOverTime() private {
        if(burnData.burnOverTime > 0) {
            if(block.timestamp >= (burnData.lastBurnTime + burnData.burnTimer)) {
                _burn(address(this), burnData.amountToBurn);
                burnData.lastBurnTime = block.timestamp;
                burnData.burnOverTime -= burnData.amountToBurn;
            }
        }
    }

    function swapTokensAtAmount() public view returns (uint256 swapAmount) {
        swapAmount = totalSupply() - burnData.burnOverTime;
        swapAmount *= 5;
        swapAmount /= 1000;

        return swapAmount;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        burnTokensOverTime();

        if(starting) {
            start = block.number;
            starting = false;
        }

        uint256 current = block.number;

        if((block.timestamp < (started + maxWalletTimer)) && to != address(0) && to != uniswapV2Pair && !_isExcludedFromFees[to] && !_isExcludedFromFees[from]) {
            uint256 balance = balanceOf(to);
            require(balance + amount <= maxWallet, "Transfer amount exceeds maximum wallet");
        }

		uint256 contractTokenBalance = (balanceOf(address(this)) - burnData.burnOverTime);
        bool canSwap = contractTokenBalance >= swapTokensAtAmount();
		
		if(canSwap && !swapping && pair[to] && from != address(uniswapV2Router) && from != owner() && to != owner() && !_isExcludedFromFees[to] && !_isExcludedFromFees[from]) {

		    contractTokenBalance = swapTokensAtAmount();
            contractTokenBalance -= (((contractTokenBalance * sellTaxes.liquidityFee) / sellTaxes.totalSellFees) / 2);
            contractTokenBalance -= ((contractTokenBalance * sellTaxes.burnFee) / sellTaxes.totalSellFees);
            
            swapping = true;
            

            if (sellTaxes.totalSellFees > 0) {
                
                swapTokensForEth(contractTokenBalance);

                if(sellTaxes.burnFee > 0) {
                    uint256 burnAmount = ((swapTokensAtAmount() * sellTaxes.burnFee) / sellTaxes.totalSellFees);
                    _burn(address(this), burnAmount);
                }

                if (sellTaxes.liquidityFee > 0) {
                    uint256 liquidityETH = ((address(this).balance * sellTaxes.liquidityFee) / sellTaxes.totalSellFees);
                
                    // add liquidity to uniswap
                    addLiquidity((((swapTokensAtAmount() * sellTaxes.liquidityFee) / sellTaxes.totalSellFees) / 2), liquidityETH);

                    emit SwapAndLiquify(liquidityETH, (((swapTokensAtAmount() * sellTaxes.liquidityFee) / sellTaxes.totalSellFees) / 2));   
                }

                if (sellTaxes.burnShibaFee > 0) {
                    uint256 shibETH = ((address(this).balance * sellTaxes.burnShibaFee) / sellTaxes.totalSellFees);
                    ShibaBurn.buyAndBurn{value: shibETH}(SHIB, 0);
                }
                
                if (sellTaxes.devFee > 0) {
                    uint256 devAmount = ((address(this).balance * sellTaxes.devFee) / sellTaxes.totalSellFees);
                    (bool success, ) = address(koyoWallets.devWallet).call{value: devAmount}("");
                    require(success, "Failed to send dev fee");

                    emit TaxesSent(address(koyoWallets.devWallet), devAmount);
                }

                if (sellTaxes.marketingFee > 0) {
                    uint256 marketingAmount = address(this).balance;
                    (bool success, ) = address(koyoWallets.marketingWallet).call{value: marketingAmount}("");
                    require(success, "Failed to send marketing fee");

                    emit TaxesSent(address(koyoWallets.marketingWallet), marketingAmount);
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

        else if(!pair[to] && !pair[from] && !_isExcludedFromFees[from] && !_isExcludedFromFees[to]) {
            takeFee = false;
            super._transfer(from, to, amount);
        }

        if(takeFee) {

            uint256 BuyFees = ((amount * buyTaxes.totalBuyFees) / 1000);
            uint256 SellFees = ((amount * sellTaxes.totalSellFees) / 1000);

            if(current <= start + end && from != owner() && to != owner()) {
                uint256 send = (amount * 10) / 1000;
                amount -= send;
                super._transfer(from, to, send);
                super._transfer(from, address(this), amount);
                _burn(address(this), amount);
            }

            // if sell
            else if(pair[to] && sellTaxes.totalSellFees > 0) {
                amount -= SellFees;
                
                super._transfer(from, address(this), SellFees);
                super._transfer(from, to, amount);
            }

            // if buy transfer
            else if(pair[from] && buyTaxes.totalBuyFees > 0) {
                amount -= BuyFees;
                if(buyTaxes.burnFee > 0) {
                    uint256 burnAmount = ((BuyFees * buyTaxes.burnFee) / buyTaxes.totalBuyFees);
                    BuyFees -= burnAmount;
                    _burn(address(this), burnAmount);
                }
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

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {

        // approve token transfer to cover all possible scenarios
        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // add the liquidity
       uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(koyoWallets.liquidityWallet),
            block.timestamp
        );
    }
}