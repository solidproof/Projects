//SPDX-License-Identifier: MIT

pragma solidity 0.8.2;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface Aggregator {
   function latestRoundData() external view returns (uint80 roundId, int256 answer, uint256 startedAt, uint256 updatedAt, uint80 answeredInRound);
}

contract Presale is Ownable{
    using SafeERC20 for IERC20;
	
	uint256 public totalTokensSold;
	uint256 public totalTokensToClaim;
    uint256 public usdRaised;
	uint256 public currentRound;
	uint256 public claimStartTime;
	uint256 public monthlyRelease;
	uint256 public roundStartTime;
	
    address public paymentWallet;
	address public INVESTA;
	address public USDT;
	address public USDC;
	Aggregator public aggregatorInterface;
	
	bool public claimStatus;
	bool public preSaleStatus;
	
	uint256[5] public maxAllocation;
	uint256[5] public tokenAmount;
	uint256[5] public tokenPrice;
	uint256[5] public remainingAmount;
	
	struct buyTokenInfo {
	  uint256 usdPaid;
	  uint256 tokenFromBuy; 
	  uint256 tokenFromReferral; 
	  uint256 tokenFromIncentive;
	  uint256 tokenClaimed;
	  string  referralCode;
	  string  sponsorCode;
    }
	
	mapping(address => buyTokenInfo) public mapBuyTokenInfo;
	mapping(string  => address) public referralAddress;
	mapping(string  => uint256) public fundRaisedByReferralCode;
	mapping(address => mapping(uint256 => uint256)) public mapAllocation;
	
    event TokensBought(address user, uint256 tokens, uint256 amount, uint256 timestamp);
    event TokensClaimed(address user, uint256 amount, uint256 timestamp);
	event PreSaleStatusUpdated(bool status);
    event ClaimStatusUpdated(bool status);
	event PaymentWalletUpdated(address newWallet);
	event RoundPriceUpdated(uint256 round, uint256 price);
	
    constructor(address owner, address payment) {
	   USDC = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
	   USDT = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
	   INVESTA = address(0x1067C056303ab509823118f1816cd7925f3F72d3);
	   
	   tokenAmount = [4000000 ether, 4000000 ether, 6000000 ether, 6000000 ether, 5000000 ether];
	   remainingAmount = [4000000 ether, 4000000 ether, 6000000 ether, 6000000 ether, 5000000 ether];
	   tokenPrice = [4 * 10**4, 8 * 10**4, 12 * 10**4, 16 * 10**4, 20 * 10**4];
	   maxAllocation = [20000 * 10**6, 20000 * 10**6, 720000 * 10**6, 960000 * 10**6, 1000000 * 10**6];
	   
	   monthlyRelease = 1500000 * 10**18;
	   aggregatorInterface = Aggregator(0x5f4eC3Df9cbd43714FE2740f5E3616155c5b8419);
	   paymentWallet = address(payment);
	   _transferOwnership(address(owner));
	}
	
	function buyWithUSDT(uint256 amount, string memory rcode, string memory myrcode) external {
	   require(address(msg.sender).code.length == 0, "Only EOA address allowed");
	   require(amount > 0, "Amount must be greater than zero");
	   require(preSaleStatus, "Presale not start yet");
	   require(referralAddress[rcode] != address(msg.sender), "Sponser and sender wallet can't be same");
	   require(IERC20(USDT).balanceOf(address(msg.sender)) >= amount, "USDT amount not available to buy tokens");
	   require(IERC20(USDT).allowance(address(msg.sender), address(this)) >= amount, "Make sure to add enough USDT allowance");
	   require(maxAllocation[currentRound] - mapAllocation[address(msg.sender)][currentRound] >= amount, "Buy limit not available on this stage");
	   
	   uint256 price = tokenPrice[currentRound];
	   uint256 availableToken = remainingAmount[currentRound];
	   uint256 tokens = amount * (10**18) / price;
	   
	   if(tokens > availableToken)
	   {
	       amount = availableToken * price / 10**18;
		   IERC20(USDT).safeTransferFrom(address(msg.sender), address(paymentWallet), amount);
           _buytokens(amount, availableToken, address(msg.sender), rcode, myrcode);		  
	   } 
	   else
	   {
	       IERC20(USDT).safeTransferFrom(address(msg.sender), address(paymentWallet), amount);
		   _buytokens(amount, tokens, address(msg.sender), rcode, myrcode);
	   }
	   emit TokensBought(address(msg.sender), tokens, amount, block.timestamp);
    }
	
	function buyWithUSDC(uint256 amount, string memory rcode, string memory myrcode) external {
	   require(address(msg.sender).code.length == 0, "Only EOA address allowed");
	   require(amount > 0, "Amount must be greater than zero");
	   require(preSaleStatus, "Presale not start yet");
	   require(referralAddress[rcode] != address(msg.sender), "Sponser and sender wallet can't be same");
	   require(IERC20(USDC).balanceOf(address(msg.sender)) >= amount, "USDC amount not available to buy tokens");
	   require(IERC20(USDC).allowance(address(msg.sender), address(this)) >= amount, "Make sure to add enough USDC allowance");
	   require(maxAllocation[currentRound] - mapAllocation[address(msg.sender)][currentRound] >= amount, "Buy limit not available on this stage");
	   
	   uint256 price = tokenPrice[currentRound];
	   uint256 availableToken = remainingAmount[currentRound];
	   uint256 tokens = amount * (10**18) / price;
	   
	   if(tokens > availableToken)
	   {
	       amount = availableToken * price / 10**18;
		   IERC20(USDC).safeTransferFrom(address(msg.sender), address(paymentWallet), amount);
           _buytokens(amount, availableToken, address(msg.sender), rcode, myrcode);		  
	   } 
	   else
	   {
	       IERC20(USDC).safeTransferFrom(address(msg.sender), address(paymentWallet), amount);
		   _buytokens(amount, tokens, address(msg.sender), rcode, myrcode);
	   }
	   emit TokensBought(address(msg.sender), tokens, amount, block.timestamp);
    }
	
	function buyWithETH(string memory rcode, string memory myrcode) external payable {
	   uint256 amount = (getLatestPrice() * msg.value) / (10**30);
	   
	   require(address(msg.sender).code.length == 0, "Only EOA address allowed");
	   require(referralAddress[rcode] != address(msg.sender), "Sponser and sender wallet can't be same");
	   require(amount > 0, "Amount must be greater than zero");
	   require(preSaleStatus, "Presale not start yet");
	   require(maxAllocation[currentRound] - mapAllocation[address(msg.sender)][currentRound] >= amount, "Buy limit not available on this stage");
	   
	   uint256 price = tokenPrice[currentRound];
	   uint256 availableToken = remainingAmount[currentRound];
	   uint256 tokens = amount * (10**18) / price;
	   
	   if(tokens > availableToken)
	   {
	       amount = availableToken * price / 10**18;
		   (bool success, ) = address(paymentWallet).call{value: address(this).balance}("");
           require(success, "ETH Payment failed");
           _buytokens(amount, availableToken, address(msg.sender), rcode, myrcode);		  
	   } 
	   else
	   {
           (bool success, ) = address(paymentWallet).call{value: address(this).balance}("");
           require(success, "ETH Payment failed");
		   _buytokens(amount, tokens, address(msg.sender), rcode, myrcode);
	   }
	   emit TokensBought(address(msg.sender), tokens, amount, block.timestamp);
    }
	
	function buyWithUSD(uint256 tokens, address buyer, string memory rcode, string memory myrcode) external onlyOwner{
	   require(tokens > 0, "Tokens must be greater than zero");
	   require(remainingAmount[currentRound] >= tokens, "Buy limit not available on this stage");
	   require(referralAddress[rcode] != address(msg.sender), "Sponser and sender wallet can't be same");
	   
	   uint256 price = tokenPrice[currentRound];
	   uint256 amount = tokens * price / 10**18;
	   
	   _buytokens(amount, tokens, address(buyer), rcode, myrcode);
	   emit TokensBought(address(buyer), tokens, amount, block.timestamp);
    }
	
	
	function _buytokens(uint256 amount, uint256 tokens, address buyer, string memory rcode, string memory myrcode) internal {
	     
		if(referralAddress[myrcode] == address(0) && bytes(mapBuyTokenInfo[address(buyer)].referralCode).length == 0) 
		{
		   referralAddress[myrcode] = address(buyer);
		   mapBuyTokenInfo[address(buyer)].referralCode = myrcode;
		}
		
		usdRaised += amount; 
		remainingAmount[currentRound] -= tokens;
		totalTokensSold += tokens;
		totalTokensToClaim += tokens;
		
		currentRound = remainingAmount[currentRound] == 0 ? (currentRound + 1) : currentRound;
		if(remainingAmount[currentRound] == 0 && currentRound != 4)
		{
		   currentRound = currentRound + 1;
		   roundStartTime = block.timestamp;
		}
		
		mapBuyTokenInfo[address(buyer)].usdPaid += amount;
		mapBuyTokenInfo[address(buyer)].tokenFromBuy += tokens;
		mapAllocation[address(buyer)][currentRound] += amount;
		
		if(bytes(mapBuyTokenInfo[address(buyer)].sponsorCode).length != 0)
		{
		    uint256 bonus = tokens * 5 / 100;
			mapBuyTokenInfo[referralAddress[mapBuyTokenInfo[address(buyer)].sponsorCode]].tokenFromReferral += bonus;
			mapBuyTokenInfo[address(buyer)].tokenFromIncentive += bonus;
			totalTokensToClaim += bonus + bonus;
			fundRaisedByReferralCode[mapBuyTokenInfo[address(buyer)].sponsorCode] += amount;
		}
		else if(referralAddress[rcode] != address(0))
		{
			uint256 bonus = tokens * 5 / 100;
			mapBuyTokenInfo[referralAddress[rcode]].tokenFromReferral += bonus;
			mapBuyTokenInfo[address(buyer)].sponsorCode = rcode;
			mapBuyTokenInfo[address(buyer)].tokenFromIncentive += bonus;
			totalTokensToClaim += bonus + bonus;
			fundRaisedByReferralCode[rcode] += amount;
		}
	}
	
    function _tokenAvailableToClaim() internal view returns(uint256 tokens) {
	   tokens = ((block.timestamp - claimStartTime) / 30 days) * monthlyRelease; 
	   tokens = tokens > totalTokensToClaim ? totalTokensToClaim : tokens;
	}
	
	function claimToken() external{
		require(claimStatus, "Claim not start yet");
		require(address(msg.sender).code.length == 0, "Only EOA address allowed");
		
		uint256 pending = pendingToClaim(address(msg.sender));
		if(pending > 0) 
		{
		    mapBuyTokenInfo[address(msg.sender)].tokenClaimed += pending;
		    IERC20(INVESTA).safeTransfer(address(msg.sender), pending);
		    emit TokensClaimed(address(msg.sender), pending, block.timestamp);
		}
		else
		{
		    emit TokensClaimed(msg.sender, 0, block.timestamp);
		}
    }
	
	function pendingToClaim(address user) public view returns (uint256) {
	   if(mapBuyTokenInfo[user].tokenFromBuy > 0 && claimStatus) 
	   {
	       uint256 available = _tokenAvailableToClaim();
		   if(available == totalTokensToClaim)
		   {
		       uint256 pending = (mapBuyTokenInfo[user].tokenFromBuy + mapBuyTokenInfo[user].tokenFromReferral + mapBuyTokenInfo[user].tokenFromIncentive) - mapBuyTokenInfo[user].tokenClaimed;
		       return pending;
		   }
		   else
		   {
		      uint256 pending = ((available * (mapBuyTokenInfo[user].tokenFromBuy + mapBuyTokenInfo[user].tokenFromReferral + mapBuyTokenInfo[user].tokenFromIncentive)) / totalTokensToClaim) - mapBuyTokenInfo[user].tokenClaimed;
		      return pending;
		   }
	   }
       else
	   {
	      return 0;
	   } 
    }
	
    function changePaymentWallet(address newPWallet) external onlyOwner {
       require(newPWallet != address(0), "address cannot be zero");
	   
       paymentWallet = newPWallet;
	   emit PaymentWalletUpdated(newPWallet);
    }
	
	function changeRoundPrice(uint256 round, uint256 price) external onlyOwner {
       require(tokenPrice.length > round, "Incorrect token round");
	   
       tokenPrice[round] = price;
	   emit RoundPriceUpdated(round, price);
    }
	
	function updatePreSaleStatus(bool status) external onlyOwner{
        require(preSaleStatus != status, "Presale is already set to that value");
		if(status)
		{
		   roundStartTime = block.timestamp;
		   require(!claimStatus, "Stop the claim to start the presale");
		}
        preSaleStatus = status;
		emit PreSaleStatusUpdated(status);
    }
	
	function startClaim() external onlyOwner {
        require(!claimStatus, "Claim is already set to that value");
		require(!preSaleStatus, "Stop the presale to start the claim");
		
		claimStartTime = block.timestamp + 30 days;
		claimStatus = true;
		require(IERC20(INVESTA).balanceOf(address(this)) >= totalTokensToClaim, "Tokens is not available to claim");
		emit ClaimStatusUpdated(true);
    }
	
	function getLatestPrice() public view returns (uint256) {
       (, int256 price, , , ) = aggregatorInterface.latestRoundData();
       price = (price * (10 ** 10));
       return uint256(price);
    }
}