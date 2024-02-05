//SPDX-License-Identifier: MIT

pragma solidity 0.8.2;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Presale is Ownable{
    using SafeERC20 for IERC20;
	
	uint256 public totalTokensSold;
	uint256 public totalTokensToClaim;
    uint256 public usdRaised;
	uint256 public currentRound;
	
    address private paymentWallet;
	address public saleToken;
	address public USDT;
	
	bool public claimStatus;
	bool public preSaleStatus;
	bool public refundStatus;
	
	uint256[18] public maxAllocation;
	uint256[18] public tokenAmount;
	uint256[18] public tokenPrice;
	uint256[18] public remainingAmount;
	
	struct buyTokenInfo {
	  uint256 usdPaid;
	  uint256 tokenFromBuy; 
	  uint256 tokenFromReferral; 
	  uint256 tokenFromIncentive;
	  uint256 tokenClaimed;
	  string referralCode;
	  uint256 referralCodeUsed;
	  bool refund;
    }
	
	mapping(address => buyTokenInfo) public mapBuyTokenInfo;
	mapping(string => address) public referralAddress;
	mapping(string => uint256) public fundRaisedByReferralCode;
	mapping(uint256 => uint256) public fundRaisedByAvatar;
	
    event TokensBought(address user, uint256 tokens, uint256 amount, uint256 timestamp);
    event TokensClaimed(address user, uint256 amount, uint256 timestamp);
	event RefundClaimed(address user, uint256 amount, uint256 timestamp);
	event PreSaleStatusUpdated(bool status);
    event ClaimStatusUpdated(bool status);
	event PaymentWalletUpdated(address newWallet);
	
    constructor(address owner, address payment) {
	   USDT = address(0xC2C527C0CACF457746Bd31B2a698Fe89de2b6d49);
	   saleToken = address(0xb02bb1996E96C780af33F54abCc6c2C534199cCc);
	   tokenAmount = [
	      5000000000000  * 10**18, 
		  8333333333333  * 10**18, 
		  10169491525424 * 10**18, 
		  14893617021277 * 10**18, 
		  17449664429530 * 10**18, 
		  20833333333333 * 10**18, 
		  36649214659686 * 10**18, 
		  42904290429043 * 10**18, 
		  25157232704403 * 10**18, 
		  17711171662125 * 10**18, 
		  18639328984157 * 10**18, 
		  20818875780708 * 10**18, 
		  11806375442739 * 10**18, 
		  15843675732770 * 10**18, 
		  9631591620515  * 10**18, 
		  13670539986330 * 10**18, 
		  8699434536755  * 10**18, 
		  12477828817873 * 10**18
	   ];
	   remainingAmount = [
	      5000000000000  * 10**18, 
		  8333333333333  * 10**18, 
		  10169491525424 * 10**18, 
		  14893617021277 * 10**18, 
		  17449664429530 * 10**18, 
		  20833333333333 * 10**18, 
		  36649214659686 * 10**18, 
		  42904290429043 * 10**18, 
		  25157232704403 * 10**18, 
		  17711171662125 * 10**18, 
		  18639328984157 * 10**18, 
		  20818875780708 * 10**18, 
		  11806375442739 * 10**18, 
		  15843675732770 * 10**18, 
		  9631591620515  * 10**18, 
		  13670539986330 * 10**18, 
		  8699434536755  * 10**18, 
		  12477828817873 * 10**18
	   ];
	   
	   maxAllocation = 
	   [
	     10000    * 10**6, 
		 40000    * 10**6,
		 100000   * 10**6, 
		 240000   * 10**6,
		 500000   * 10**6, 
		 1000000  * 10**6,
		 2400000  * 10**6, 
		 5000000  * 10**6, 
		 7400000  * 10**6, 
		 10000000 * 10**6, 
		 14000000 * 10**6, 
		 20000000 * 10**6, 
		 24000000 * 10**6, 
		 30000000 * 10**6, 
		 34000000 * 10**6, 
		 40000000 * 10**6, 
		 44000000 * 10**6, 
		 50000000 * 10**6
	   ];
	   
	   tokenPrice = 
	   [
	     2000000000, 
		 3600000000,
		 5900000000, 
		 9400000000,
		 14900000000, 
		 24000000000,
		 38200000000, 
		 60600000000, 
		 95400000000, 
		 146800000000, 
		 214600000000, 
		 288200000000, 
		 338800000000, 
		 378700000000, 
		 415300000000, 
		 438900000000, 
		 459800000000, 
		 480852886153
	   ];
	   paymentWallet = address(payment);
	   _transferOwnership(address(owner));
	}
	
	function buyWithUSDT(uint256 amount, string memory rcode, string memory myrcode, uint256 avatar) external {
	   amount = ((amount / 10**6) * 10**6);
	   require(amount > 0, "Amount must be greater than zero");
	   require(avatar <= 3, "Avatar must be less than 4");
	   require(maxAllocation[currentRound] - mapBuyTokenInfo[address(msg.sender)].usdPaid >= amount, "Limit not available on this round");
	   require(preSaleStatus, "Presale not start yet");
	   require(referralAddress[rcode] != address(msg.sender), "Sponser and sender wallet can't be same");
	   require(IERC20(USDT).balanceOf(address(msg.sender)) >= amount, "USDT amount not available to buy Tokens");
	   require(IERC20(USDT).allowance(address(msg.sender), address(this)) >= amount, "Make sure to add enough USDT allowance");
	   
	   if(referralAddress[myrcode] == address(0))
	   {
	       referralAddress[myrcode] = address(msg.sender);
		   mapBuyTokenInfo[address(msg.sender)].referralCode = myrcode;
	   }
	   uint256 newAmount = amount * 10**12;
	   uint256 price = tokenPrice[currentRound];
	   uint256 availableToken = remainingAmount[currentRound];
	   uint256 tokens = newAmount * 10**18 / price;
	   
	   if(tokens > availableToken)
	   {
	      amount = ((availableToken * price) * 10**6) / 10**36;
		  IERC20(USDT).safeTransferFrom(address(msg.sender), address(paymentWallet), amount);
		  
		  usdRaised += amount; 
		  remainingAmount[currentRound] = 0;
		  currentRound += 1;
		  totalTokensSold += availableToken;
	      totalTokensToClaim += availableToken;
		  fundRaisedByAvatar[avatar] += amount;
		  
		  mapBuyTokenInfo[address(msg.sender)].tokenFromBuy += availableToken;
		  mapBuyTokenInfo[address(msg.sender)].usdPaid += amount;
          if(referralAddress[rcode] != address(0))
		  {
		      uint256 bonus = availableToken * 5 / 100;
			  mapBuyTokenInfo[address(referralAddress[rcode])].tokenFromReferral += bonus;
			  mapBuyTokenInfo[address(referralAddress[rcode])].referralCodeUsed += 1;
              mapBuyTokenInfo[address(msg.sender)].tokenFromIncentive += bonus;
			  totalTokensToClaim += bonus + bonus;
			  fundRaisedByReferralCode[rcode] += amount;
		  }	
	   }
	   else
	   {
	      IERC20(USDT).safeTransferFrom(address(msg.sender), address(paymentWallet), amount);
	      usdRaised += amount; 
          remainingAmount[currentRound] -= tokens;
		  totalTokensSold += tokens;
	      totalTokensToClaim += tokens;
		  fundRaisedByAvatar[avatar] += amount;
          if((1* 10**18) > remainingAmount[currentRound])
		  {
		    remainingAmount[currentRound] = 0;
		    currentRound += 1;
		  }	
		  mapBuyTokenInfo[address(msg.sender)].usdPaid += amount;
          mapBuyTokenInfo[address(msg.sender)].tokenFromBuy += tokens;
          if(referralAddress[rcode] != address(0))
		  {
		      uint256 bonus = tokens * 5 / 100;
			  mapBuyTokenInfo[address(referralAddress[rcode])].tokenFromReferral += bonus;
			  mapBuyTokenInfo[address(referralAddress[rcode])].referralCodeUsed += 1;
              mapBuyTokenInfo[address(msg.sender)].tokenFromIncentive += bonus;
			  totalTokensToClaim += bonus + bonus;
			  fundRaisedByReferralCode[rcode] += amount;
		  }	
	   }
	   emit TokensBought(address(msg.sender), tokens, amount, block.timestamp);
    }
	
	function claimToken() external{
		require(claimStatus, "Claim not start yet");
		
		uint256 pending = pendingToClaim(address(msg.sender));
		if(pending > 0) 
		{
		   totalTokensToClaim -= pending;
		   mapBuyTokenInfo[address(msg.sender)].tokenClaimed += pending;
		   IERC20(saleToken).safeTransfer(address(msg.sender), pending);
		   emit TokensClaimed(address(msg.sender), pending, block.timestamp);
		}
		else
		{
		   emit TokensClaimed(msg.sender, 0, block.timestamp);
		}
    }
	
	function claimRefund() external{
		require(refundStatus, "Refund not available to claim");
		
		uint256 amount = mapBuyTokenInfo[address(msg.sender)].usdPaid;
		if(amount > 0 && !mapBuyTokenInfo[address(msg.sender)].refund) 
		{
		   mapBuyTokenInfo[address(msg.sender)].refund = true;
		   IERC20(USDT).safeTransfer(address(msg.sender), amount);
		   emit RefundClaimed(address(msg.sender), amount, block.timestamp);
		}
    }
	
	function pendingToClaim(address user) public view returns (uint256) {
	   if(mapBuyTokenInfo[user].tokenFromBuy > 0) 
	   {
	       uint256 pending = (mapBuyTokenInfo[user].tokenFromBuy + mapBuyTokenInfo[user].tokenFromReferral + mapBuyTokenInfo[user].tokenFromIncentive) - mapBuyTokenInfo[user].tokenClaimed;
		   return pending;
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
	
	function updatePreSaleStatus(bool status) external onlyOwner{
        require(preSaleStatus != status, "Presale is already set to that value");
		require(!refundStatus, "Sale already cancel");
		if(status)
		{
		   require(!claimStatus, "Stop the claim to start the presale");
		}
        preSaleStatus = status;
		emit PreSaleStatusUpdated(status);
    }
	
	function startClaim() external onlyOwner{
        require(!claimStatus, "Claim already start");
		require(!refundStatus, "Sale already cancel");
		require(!preSaleStatus, "Stop the presale to start the claim");
		require(IERC20(saleToken).balanceOf(address(this)) >= totalTokensToClaim, "Tokens is not available to claim");
		
		claimStatus = true;
		emit ClaimStatusUpdated(true);
    }
	
	function cancelSale() external onlyOwner {
       require(!refundStatus, "Sale already cancel");
	   require(!claimStatus, "Claim already start");
	   require(!preSaleStatus, "Stop the presale to start the claim");
	   
	   refundStatus = true;
	   require(IERC20(USDT).balanceOf(address(this)) >= usdRaised, "USDT is not available to claim");
    }
}