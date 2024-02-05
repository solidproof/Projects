// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IDEXFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IDEXRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);
    function swapExactTokensForETHSupportingFeeOnTransferTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external;
}

contract VOCARE is ERC20, Ownable {
	address private growthWallet;
	address private pair;
	
	uint256 public growthBuyFee;
	uint256 public growthSellFee;
	
	uint256 public swapThreshold;
	uint256 public tokenLimitPerWallet;
	
	bool private swapping;
	IDEXRouter public router;
	
	mapping(address => bool) public isWalletTaxFree;
	mapping(address => bool) public isLiquidityPair;
	mapping(address => bool) public isWalletExemptFromLimit;
	
	event BuyFeeUpdated(uint256 newFee);
	event SellFeeUpdated(uint256 newFee);
	event WalletExemptFromTokenLimit(address wallet, bool value);
	event SwapingThresholdUpdated(uint256 amount);
	event TokenPerWalletLimitUpdated(uint256 amount);
	event NewLiquidityPairUpdated(address pair, bool value);
	event WalletExemptFromFee(address wallet, bool value);
	event GrowthWalletUpdated(address wallet);
	
    constructor(address owner, address growth) ERC20("Vocare ex Machina", "VOCARE") {
	   router = IDEXRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
       pair = IDEXFactory(router.factory()).createPair(address(this), router.WETH());
	   
	   growthWallet = address(growth);
	   
	   growthBuyFee = 500;
	   growthSellFee = 500;
	   
	   isLiquidityPair[address(pair)] = true;
	   
	   isWalletTaxFree[address(this)] = true;
	   isWalletTaxFree[address(owner)] = true;
	   isWalletTaxFree[address(growthWallet)] = true;
	   
	   isWalletExemptFromLimit[address(this)] = true;
	   isWalletExemptFromLimit[address(owner)] = true;
	   isWalletExemptFromLimit[address(growthWallet)] = true;
	   isWalletExemptFromLimit[address(pair)] = true;
	   
	   swapThreshold = 10000 * (10**18);
	   tokenLimitPerWallet = 200000 * (10**18);
	   
       _mint(address(owner), 10000000 * (10**18));
	   _transferOwnership(address(owner));
    }
	
	receive() external payable {}
	
	function updateSellFee(uint256 newSellFee) external onlyOwner {
	   require(newSellFee  <= 8000 , "Max fee limit reached for 'Sell'");
	   
	   growthSellFee = newSellFee;
	   emit SellFeeUpdated(newSellFee);
	}
	
	function updateBuyFee(uint256 newBuyFee) external onlyOwner {
	   require(newBuyFee  <= 8000 , "Max fee limit reached for 'Buy'");
	   
	   growthBuyFee = newBuyFee;
	   emit BuyFeeUpdated(newBuyFee);
	}
	
	function exemptWalletFromTokenLimit(address wallet, bool status) external onlyOwner {
	   require(wallet != address(0), "Zero address");
	   require(isWalletExemptFromLimit[wallet] != status, "Wallet is already the value of 'status'");
	   
	   isWalletExemptFromLimit[wallet] = status;
	   emit WalletExemptFromTokenLimit(wallet, status);
	}
	
	function exemptWalletFromFee(address wallet, bool status) external onlyOwner{
        require(wallet != address(0), "Zero address");
		require(isWalletTaxFree[wallet] != status, "Wallet is already the value of 'status'");
		
		isWalletTaxFree[wallet] = status;
        emit WalletExemptFromFee(wallet, status);
    }
	
	function updateSwapingThreshold(uint256 amount) external onlyOwner {
  	    require(amount <= totalSupply(), "Amount cannot be over the total supply.");
		require(amount >= (100 * 10**18), "Amount cannot be less than `100` token.");
		
		swapThreshold = amount;
		emit SwapingThresholdUpdated(amount);
  	}
	
	function updateLiquidityPair(address newPair, bool value) external onlyOwner {
        require(newPair != address(0), "Zero address");
		require(isLiquidityPair[newPair] != value, "Pair is already the value of 'value'");
		
        isLiquidityPair[newPair] = value;
        emit NewLiquidityPairUpdated(newPair, value);
    }
	
	function updateTokenLimitPerWallet(uint256 amount) external onlyOwner {
		require(amount <= totalSupply(), "Amount cannot be over the total supply.");
		require(amount >= 100 * (10**18), "Minimum `100` token per wallet required");
		
		tokenLimitPerWallet = amount;
		emit TokenPerWalletLimitUpdated(amount);
	}
	
	function updateGrowthWallet(address newWallet) external onlyOwner{
        require(address(newWallet) != address(0), "Zero address");
		
		growthWallet = address(newWallet);
        emit GrowthWalletUpdated(address(newWallet));
    }
	
	function _transfer(address sender, address recipient, uint256 amount) internal override(ERC20) {      
        require(sender != address(0), "transfer from the zero address");
        require(recipient != address(0), "transfer to the zero address");
		
		uint256 contractTokenBalance = balanceOf(address(this));
		bool canSwap = contractTokenBalance >= swapThreshold;
		
		if(!swapping && canSwap && isLiquidityPair[recipient]) 
		{
			swapping = true;
			
			swapTokensForETH(swapThreshold);
			uint256 ethBalance = address(this).balance;
			payable(growthWallet).transfer(ethBalance);
			
			swapping = false; 
		}
		
		if(isWalletTaxFree[sender] || isWalletTaxFree[recipient])
		{
		    super._transfer(sender, recipient, amount);
		}
		else
		{
		    uint256 fees;
		    if(isLiquidityPair[recipient])
		    {
		        fees = ((amount * growthSellFee) / 10000);
		    }
		    else if(isLiquidityPair[sender] && recipient != address(router))
		    {
               fees = ((amount * growthBuyFee) / 10000);	   
		    }
			
			if(!isWalletExemptFromLimit[recipient])
		    {
		       require(((balanceOf(recipient) + amount) - fees) <= tokenLimitPerWallet, "Transfer amount exceeds the `tokenLimitPerWallet`.");   
		    }
			
		    if(fees > 0) 
		    {
			   super._transfer(sender, address(this), fees);
		    }
		    super._transfer(sender, recipient, amount - fees);
		}
    }
	
	function swapTokensForETH(uint256 amount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();
		
        _approve(address(this), address(router), amount);
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }
}