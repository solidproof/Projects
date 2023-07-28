// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Votes.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

interface IDEXFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IDEXRouter {
   function factory() external pure returns (address);
   function WETH() external pure returns (address);
   function swapExactTokensForETHSupportingFeeOnTransferTokens(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline) external;
}

contract INVESTA is ERC20, ERC20Snapshot, Ownable, ERC20Permit, ERC20Votes {
    using SafeMath for uint256;
	
	address public battleWallet;
	address public teamWallet;
	
	bool private swapping;
	uint256 public swapThreshold;
	
	uint256[] public teamFee;
	uint256[] public battleFee;
	
    uint256 private teamFeeTotal;
	uint256 private battleFeeTotal;
	
	IDEXRouter public router;
    address public pair;
	
	mapping (address => bool) public isFeeExempt;
	mapping (address => bool) public isLiquidityPair;
	
	event BattleWalletUpdated(address newWallet);
	event TeamWalletUpdated(address newWallet);
	event LiquidityPairUpdated(address pair, bool value);
	event WalletExemptFromFee(address wallet, bool value);
	event SwapingThresholdUpdated(uint256 amount);
	event TeamFeeUpdated(uint256 buy, uint256 sell, uint256 p2p);
	event BattleFeeUpdated(uint256 buy, uint256 sell, uint256 p2p);
	
    constructor(address owner) ERC20("InvestaDAO", "INVESTA") ERC20Permit("INVESTA") {
	   router = IDEXRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
       pair = IDEXFactory(router.factory()).createPair(address(this), router.WETH());
		
       isLiquidityPair[pair] = true;
	   
	   isFeeExempt[address(this)] = true;
	   isFeeExempt[address(owner)] = true;
	   
	   battleFee.push(1000);
	   battleFee.push(1000);
	   battleFee.push(0);
	   
	   teamFee.push(0);
	   teamFee.push(0);
	   teamFee.push(0);
	   
	   battleWallet = address(0xd020f7BadaeeF328ed88428D43906f481b9DC54c);
	   teamWallet = address(0x4B7F97064Da8303A53Ff1C9912ED4C8B2aa4a1b5);
	   
	   swapThreshold = 100_000 * (10**18);
       _mint(address(owner), 100_000_000 * (10**18));
	   _transferOwnership(address(owner));
    }
	
	receive() external payable {}
	
	function snapshot() public onlyOwner {
        _snapshot();
    }
	
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override(ERC20, ERC20Snapshot) {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _afterTokenTransfer(address from, address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._afterTokenTransfer(from, to, amount);
    }

    function _mint(address to, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._mint(to, amount);
    }
	
    function _burn(address account, uint256 amount) internal override(ERC20, ERC20Votes) {
        super._burn(account, amount);
    }
	
	function setBattleWallet(address newWallet) external onlyOwner{
        require(address(newWallet) != address(0), "Zero address");
		
		battleWallet = address(newWallet);
        emit BattleWalletUpdated(address(newWallet));
    }
	
	function setTeamWallet(address newWallet) external onlyOwner{
        require(address(newWallet) != address(0), "Zero address");
		
		teamWallet = address(newWallet);
        emit TeamWalletUpdated(address(newWallet));
    }
	
    function walletExemptFromFee(address wallet, bool status) external onlyOwner{
        require(address(wallet) != address(0), "Zero address");
		require(isFeeExempt[address(wallet)] != status, "Wallet is already the value of 'status'");
		
		isFeeExempt[address(wallet)] = status;
        emit WalletExemptFromFee(address(wallet), status);
    }
	
	function setLiquidityPair(address newPair, bool value) external onlyOwner {
        require(address(newPair) != address(0), "Zero address");
		require(isLiquidityPair[address(newPair)] != value, "Pair is already the value of 'value'");
		
        isLiquidityPair[address(newPair)] = value;
        emit LiquidityPairUpdated(address(newPair), value);
    }
	
	function setSwapingThreshold(uint256 amount) external onlyOwner {
  	    require(amount <= totalSupply(), "Amount cannot be over the total supply.");
		require(amount >= (500 * 10**18), "Amount cannot be less than `500` token.");
		
		swapThreshold = amount;
		emit SwapingThresholdUpdated(amount);
  	}
	
	function setTeamFee(uint256 buy, uint256 sell, uint256 p2p) external onlyOwner {
	    require(battleFee[0].add(buy)  <= 2000 , "Max fee limit reached for 'BUY'");
		require(battleFee[1].add(sell) <= 2000 , "Max fee limit reached for 'SELL'");
		require(battleFee[2].add(p2p)  <= 2000 , "Max fee limit reached for 'P2P'");
		
		teamFee[0] = buy;
		teamFee[1] = sell;
		teamFee[2] = p2p;
		emit TeamFeeUpdated(buy, sell, p2p);
	}
	
	function setBattleFee(uint256 buy, uint256 sell, uint256 p2p) external onlyOwner {
	    require(teamFee[0].add(buy)  <= 2000 , "Max fee limit reached for 'BUY'");
		require(teamFee[1].add(sell) <= 2000 , "Max fee limit reached for 'SELL'");
		require(teamFee[2].add(p2p)  <= 2000 , "Max fee limit reached for 'P2P'");
		
		battleFee[0] = buy;
		battleFee[1] = sell;
		battleFee[2] = p2p;
	    emit BattleFeeUpdated(buy, sell, p2p);
	}
	
	function _transfer(address sender, address recipient, uint256 amount) internal override(ERC20) {      
        require(sender != address(0), "transfer from the zero address");
        require(recipient != address(0), "transfer to the zero address");
		
		uint256 contractTokenBalance = balanceOf(address(this));
		bool canSwap = contractTokenBalance >= swapThreshold;
		
		if (!swapping && canSwap && isLiquidityPair[recipient]) 
		{
			uint256 tokenToBattle = battleFeeTotal;
			uint256 tokenToTeam = teamFeeTotal;
			uint256 tokenToSwap = tokenToBattle.add(tokenToTeam);
			
			if(tokenToSwap >= swapThreshold) 
			{
			    swapping = true;
				swapTokensForETH(swapThreshold);
				uint256 newBalance = address(this).balance;
				
				uint256 teamPart = newBalance.mul(tokenToTeam).div(tokenToSwap);
				uint256 battlePart = newBalance.sub(teamPart);
				
				if(teamPart > 0) 
				{
				   (bool success, ) = teamWallet.call{value: teamPart}("");
				   require(success, "Failed to send ETH on team wallet");
				   
				   teamFeeTotal = teamFeeTotal.sub(swapThreshold.mul(tokenToTeam).div(tokenToSwap));
				}
				if(battlePart > 0) 
				{
				   (bool success, ) = battleWallet.call{value: battlePart}("");
				   require(success, "Failed to send ETH on battle wallet");
				   
				   battleFeeTotal = battleFeeTotal.sub(swapThreshold.mul(tokenToBattle).div(tokenToSwap));
				}
				swapping = false; 
			}
		}
		
		if(isFeeExempt[sender] || isFeeExempt[recipient]) 
		{
            super._transfer(sender, recipient, amount);
        }
		else 
		{
		
		    uint256 allFee = collectFee(amount, isLiquidityPair[recipient], !isLiquidityPair[sender] && !isLiquidityPair[recipient]);
			if(allFee > 0) 
			{
			   super._transfer(sender, address(this), allFee);
			}
			super._transfer(sender, recipient, amount.sub(allFee));
        }
    }
	
	function collectFee(uint256 amount, bool sell, bool p2p) private returns (uint256) {
        uint256 newBattleFee = amount * (p2p ? battleFee[2] : sell ? battleFee[1] : battleFee[0]) / 10000;
		uint256 newTeamFee = amount * (p2p ? teamFee[2] : sell ? teamFee[1] : teamFee[0]) / 10000;
		
	    teamFeeTotal += newTeamFee;
		battleFeeTotal += newBattleFee;
        return (newBattleFee + newTeamFee);
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