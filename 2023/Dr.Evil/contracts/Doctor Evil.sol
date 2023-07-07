// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router01.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract DoctorEvil is Context, ERC20, Ownable {
    using SafeERC20 for IERC20;
    using Address for address;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    _Tax public Tax;

    mapping(address => bool) public pair;
    mapping (address => bool) public _isExcludedFromFees;

    uint256 private start;
    uint256 private end;
    uint256 private started;

    bool public starting;
    bool public swapping;

    uint256 private maxWalletTimer;
    uint256 public maxWallet;
    uint256 public swapTokensAtAmount;

    uint256 private _supply;

    address payable marketingWallet;

    struct _Tax {
        uint256 buyFee;
        uint256 sellFee;
        uint256 maxBuyFee;
        uint256 maxSellFee;
        uint256 taxPhaseOneTimer;
        uint256 taxPhaseTwoTimer;
        uint256 taxPhase;
        bool taxesDisabled;
    }

    event TaxDisabled(
        bool taxDisabled
    );

    event TaxUpdated(
        uint256 buyFee,
        uint256 sellFee
    );

    constructor(address payable _marketingWallet, uint256 _end) ERC20("Doctor Evil", "EVIL") {

        uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D); // Router address for Uniswap

        _supply = 1 * 10 ** 9 * 10 ** decimals(); // 1 billion total supply

        maxWallet = (_supply * 94) / 10000; // 0.94% of total supply
        swapTokensAtAmount = (_supply * 25) / 10000; // 0.25% of total supply
        maxWalletTimer = 12 hours; // 12 hours
        end = _end;
        Tax.taxesDisabled = false;
        Tax.taxPhaseOneTimer = 2 days;
        Tax.taxPhaseTwoTimer = 7 days;

        marketingWallet = payable(_marketingWallet);

        _isExcludedFromFees[address(this)] = true;
        _isExcludedFromFees[owner()] = true;

        _mint(owner(), ((_supply * 931) / 1000)); // 93.1% of total supply for initial liquidity
        _mint(_marketingWallet, ((_supply * 69) / 1000)); // Tokens to be sent to marketing wallet 6.9% of total supply
    }

    receive() external payable {

  	}

    function setTaxPhase() internal { // Sets the tax phase
        require(!Tax.taxesDisabled, "Taxes are disabled");

        if(block.timestamp < (started + Tax.taxPhaseOneTimer) && Tax.taxPhase != 1) { // If the current time is less than the start time + the tax phase one timer and the tax phase is not 1
            Tax.buyFee = 50;
            Tax.sellFee = 100;
            Tax.maxBuyFee = 50;
            Tax.maxSellFee = 100;

            Tax.taxPhase = 1;
        } else if(block.timestamp < (started + Tax.taxPhaseTwoTimer) && Tax.taxPhase != 2) { // If the current time is less than the start time + the tax phase two timer and the tax phase is not 2
            Tax.buyFee = 50;
            Tax.sellFee = 50;
            Tax.maxBuyFee = 50;
            Tax.maxSellFee = 50;

            Tax.taxPhase = 2;
        } else if(block.timestamp >= (started + Tax.taxPhaseTwoTimer) && Tax.taxPhase != 3) { // If the current time is greater than the start time + the tax phase two timer and the tax phase is not 3
            Tax.buyFee = 25;
            Tax.sellFee = 50;
            Tax.maxBuyFee = 25;
            Tax.maxSellFee = 50;

            Tax.taxPhase = 3;
        }
    }

    function disableTax() external onlyOwner { // Disables taxes
        Tax.buyFee = 0;
        Tax.sellFee = 0;
        Tax.maxBuyFee = 0;
        Tax.maxSellFee = 0;

        Tax.taxesDisabled = true;
    }

    function updateTax(uint256 _buyFee, uint256 _sellFee) external onlyOwner{ // 100 = 1%
        require(!Tax.taxesDisabled, "Taxes are disabled");
        require(_buyFee <= Tax.maxBuyFee, "Buy fee is too high");
        require(_sellFee <= Tax.maxSellFee, "Sell fee is too high");
        require(Tax.taxPhase == 3, "Tax phase is not 3");

        Tax.buyFee = _buyFee;
        Tax.sellFee = _sellFee;

        emit TaxUpdated(_buyFee, _sellFee);
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount * 10 ** decimals());
    }

    function addPair(address toPair) public onlyOwner {
        require(!pair[toPair], "This pair already exists");

        pair[toPair] = true;
        uniswapV2Pair = toPair;

        starting = false;
        started = block.timestamp;
        start = block.number;
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        if(starting) {
            require(from == owner() || to == owner(), "Trading is not yet enabled");
        }

        uint256 current = block.number;

        if((block.timestamp < (started + maxWalletTimer)) && to != address(0) && to != uniswapV2Pair && !_isExcludedFromFees[to] && !_isExcludedFromFees[from]) {
            uint256 balance = balanceOf(to);
            require(balance + amount <= maxWallet, "Transfer amount exceeds maximum wallet");
        }

		uint256 contractTokenBalance = balanceOf(address(this));
        bool canSwap = contractTokenBalance >= swapTokensAtAmount;
		
		if(canSwap && !swapping && pair[to] && from != address(uniswapV2Router) && from != owner() && to != owner() && !_isExcludedFromFees[to] && !_isExcludedFromFees[from]) {

		    contractTokenBalance = swapTokensAtAmount;
            
            swapping = true;
                
            swapTokensForEth(contractTokenBalance);

            (bool success, ) = address(marketingWallet).call{value: address(this).balance}("");
            require(success, "Failed to send marketing fee");
			
            swapping = false;
        } else if(!canSwap && Tax.taxesDisabled && contractTokenBalance > 0) {
            _burn(address(this), contractTokenBalance);
        }

        bool takeFee = !swapping;

         // if any account belongs to _isExcludedFromFee account then remove the fee
        if(_isExcludedFromFees[from] || _isExcludedFromFees[to]) {
            takeFee = false;
            super._transfer(from, to, amount);
        }

        else if(current <= start + end && from != owner() && to != owner()) {
                uint256 send = (amount * 10) / 1000;
                amount -= send;
                super._transfer(from, to, send);
                super._transfer(from, address(this), amount);
        }

        else if(!pair[to] && !pair[from] && !_isExcludedFromFees[from] && !_isExcludedFromFees[to]) {
            takeFee = false;
            super._transfer(from, to, amount);
        }

        if(takeFee) {
            
            if(Tax.taxPhase != 3) { // If tax phase is not 3, check if it should be
                setTaxPhase();
            }

            uint256 BuyFees = ((amount * Tax.buyFee) / 1000);
            uint256 SellFees = ((amount * Tax.sellFee) / 1000);

            // if sell
            if(pair[to] && Tax.sellFee > 0) {
                amount -= SellFees;
                
                super._transfer(from, address(this), SellFees);
                super._transfer(from, to, amount);
            }

            // if buy transfer
            else if(pair[from] && Tax.buyFee > 0) {
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