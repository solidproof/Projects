// Turbo Treats :: Crypto Culinary Sensation!

// Decentralized DAO & Staking
// Fixed Supply
// Staking With No Time Limit Bound
// Staking APR Based on Trading Volume
// Harvest Staking Reward Any Time
// Zero Fee on Stake, Unstake and Harvest
// Submit Proposal and Earn ETH by DAO

// Website  : https://turbotreats.xyz
// Staking  : https://turbotreats.xyz/staking
// DAO      : https://turbotreats.xyz/dao
// Twitter  : https://twitter.com/turbo_treats
// Discord  : https://discord.com/invite/DjzNgj5T
// YouTube  : https://www.youtube.com/@Turbo-iy9nv
// Email    : info@turbotreats.xyz

// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

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

interface IStaking {
   function updatePool(uint256 amount) external;
}

contract TurboTreats is ERC20, Ownable {

	uint256 public marketingFee;
	uint256 public DAOFee;
	uint256 public stakingFee;
	
	uint256 public swapThreshold;
	uint256 public holdingLimit;
	
	bool private swapping;
	IDEXRouter public router;
	IStaking public TurboTreatsStaking;
	address public TurboTreatsDAO;
	
	address public pair;
	address public marketingWallet;
	
	mapping(address => bool) public isWalletTaxFree;
	mapping(address => bool) public isLiquidityPair;
	mapping(address => bool) public isWalletExemptFromHoldingLimit;
	
	event WalletExemptFromHoldingLimit(address wallet, bool value);
	event SwapingThresholdUpdated(uint256 amount);
	event TokenHoldingLimitUpdated(uint256 amount);
	event WalletExemptFromFee(address wallet, bool value);
	event MarketingWalletUpdated(address wallet);
	event StakingContractUpdated(address wallet);
	event DAOContractUpdated(address wallet);
	
    constructor() ERC20("Turbo Treats", "Turbo Treats") {
	   router = IDEXRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
       pair = IDEXFactory(router.factory()).createPair(address(this), router.WETH());
	   
	   marketingWallet = address(msg.sender);
	   
	   marketingFee = 100;
	   DAOFee = 100;
	   stakingFee = 100;
	   
	   isWalletTaxFree[address(this)] = true;
	   isWalletTaxFree[address(msg.sender)] = true;
	   
	   isWalletExemptFromHoldingLimit[address(this)] = true;
	   isWalletExemptFromHoldingLimit[address(pair)] = true;
	   isWalletExemptFromHoldingLimit[address(msg.sender)] = true;
	   
	   swapThreshold = 5_00_000 ether;
	   holdingLimit = 10_000_000 ether;
       _mint(address(msg.sender), 1_000_000_000 ether);
    }
	
	receive() external payable {}
	
	function exemptWalletFromHoldingLimit(address wallet, bool status) external onlyOwner {
	   require(wallet != address(0), "Wallet address is not correct");
	   
	   isWalletExemptFromHoldingLimit[wallet] = status;
	   emit WalletExemptFromHoldingLimit(wallet, status);
	}
	
	function exemptWalletFromFee(address wallet, bool status) external onlyOwner {
        require(wallet != address(0), "Wallet address is not correct");
		
		isWalletTaxFree[wallet] = status;
        emit WalletExemptFromFee(wallet, status);
    }
	
	function updateSwapingThreshold(uint256 amount) external onlyOwner {
  	    require(amount <= totalSupply(), "Amount is greater than total supply.");
		require(amount >= (1000 ether), "Amount is less than 1000 Turbo Treats.");
		
		swapThreshold = amount;
		emit SwapingThresholdUpdated(amount);
  	}
	
	function updateHoldingLimit(uint256 amount) external onlyOwner {
	    require(amount <= totalSupply(), "Amount cannot be over the total supply.");
		require(amount >= 10000000 ether, "Minimum `10000000` token per wallet required");
		
		holdingLimit = amount;
		emit TokenHoldingLimitUpdated(amount);
	}
	
	function updateStakingContract(IStaking stakingContract) external onlyOwner {
	   require(address(stakingContract) != address(0), "Staking contract is not correct");
	   require(address(TurboTreatsStaking) == address(0), "Staking contract already updated");
	   
	   TurboTreatsStaking = IStaking(stakingContract);
	   
	   isWalletExemptFromHoldingLimit[address(TurboTreatsStaking)] = true;
	   isWalletTaxFree[address(TurboTreatsStaking)] = true;
	   emit StakingContractUpdated(address(TurboTreatsStaking));
    }
	
	function updateDAOContract(address DAOContract) external onlyOwner {
	    require(address(DAOContract) != address(0), "DAO contract is not correct");
	    require(address(TurboTreatsDAO) == address(0), "DAO contract already updated");
		
	    TurboTreatsDAO = DAOContract;
		emit DAOContractUpdated(address(TurboTreatsDAO));
    }
	
	function updateMarketingWallet(address newWallet) external onlyOwner {
        require(address(newWallet) != address(0), "Marketing wallet is not correct");
		require(!isContract(address(newWallet)), "Contract address is not allowed");
		
		marketingWallet = address(newWallet);
        emit MarketingWalletUpdated(address(newWallet));
    }
	
	function _transfer(address sender, address recipient, uint256 amount) internal override(ERC20) {    
	
		bool canSwap = balanceOf(address(this)) >= swapThreshold;
		
		if(!swapping && canSwap && address(recipient) == address(pair)) 
		{
			swapping = true;
			swapTokensForETH(swapThreshold);
			uint256 ETH = address(this).balance;
			uint256 totalFee = DAOFee + marketingFee; 
			
			uint256 DAOShare = (ETH * DAOFee) / (totalFee);
			uint256 marketingShare = ETH - DAOShare;
			
			if(DAOShare > 0) 
			{
			   (bool success, ) = TurboTreatsDAO.call{value: DAOShare}("");
			   require(success, "Failed to send ETH on DAO contract");
			}
			if(marketingShare > 0) 
			{
			   (bool success, ) = marketingWallet.call{value: marketingShare}("");
			   require(success, "Failed to send ETH on marketing wallet");
			}
			swapping = false; 
		}
		
		if(isWalletTaxFree[sender] || isWalletTaxFree[recipient])
		{
		    if(!isWalletExemptFromHoldingLimit[recipient])
		    {
		        require((balanceOf(recipient) + amount) <= holdingLimit, "Transfer amount exceeds the `holdingLimit`.");   
		    }
		    super._transfer(sender, recipient, amount);
		}
		else
		{
			
			uint256 contractShare = (amount * (DAOFee + marketingFee)) / 10000;
			uint256 stakingShare = (amount * stakingFee) / 10000;
			
			if(!isWalletExemptFromHoldingLimit[recipient])
		    {
		       require(((balanceOf(recipient) + amount) - (contractShare + stakingShare)) <= holdingLimit, "Transfer amount exceeds the `holdingLimit`.");   
		    }
		    if(contractShare > 0) 
		    {
			   super._transfer(sender, address(this), contractShare);
		    }
			if(stakingShare > 0) 
		    {
			   super._transfer(sender, address(TurboTreatsStaking), stakingShare);
			   TurboTreatsStaking.updatePool(stakingShare);
		    }
		    super._transfer(sender, recipient, amount - (contractShare + stakingShare));
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
	
	function isContract(address account) internal view returns (bool) {
        return account.code.length > 0;
    }
}