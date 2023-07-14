// SPDX-License-Identifier: MIT

pragma solidity 0.8.2;

import "./SafeERC20.sol";

interface IReferrals {
   function addMember(address member, address parent) external;
   function getSponsor(address account) external view returns (address);
   function getTeam(address sponsor, uint256 level) external view returns (uint256);
}

contract InvestmentPlan {
	using SafeERC20 for IERC20;
	
	address public TUSD;
	address public FundWallet;
	address public ownerWallet;
	IReferrals public Referrals;
	
	struct UserInfo {
       uint256 investedAmount;
	   uint256 levelIncome;
	   uint256 foreignTour;
	   uint256 monthlyReward;
	   uint256 workingBonus;
	   uint256 royaltyBonus;
	   uint256 claimedAmount;
	   uint256 claimedTBC;
	   bool royalty;
    }
	
	struct Earning{
      uint256 levelEarning;
    }
	
	uint256 public communityIncentives; 
    uint256 public extraIncentives;
	uint256 public royaltyIncentive;
	uint256 public nextRewardDrain;
	
	bool[6] public statusPerStage;
	bool public saleEnable;
	uint256[5] public indexPerStage;
	
	uint256[5]  public pricePerStage;
	uint256[6]  public TBCPerStage;
	uint256[6]  public usersTBCPerStage;
	uint256[6]  public investmentPackages;
	uint256[10] public referrerBonus;
	uint256[10] public teamRequiredForBonus;
	
	uint256[] public stage2UserTBC;
	uint256[] public stage3UserTBC;
	uint256[] public stage4UserTBC;
	uint256[] public stage5UserTBC;
	uint256[] public stage6UserTBC;
	
	address[] public stage2UserWallet;
	address[] public stage3UserWallet;
	address[] public stage4UserWallet;
	address[] public stage5UserWallet;
	address[] public stage6UserWallet;
	
	mapping(address => UserInfo) public mapUserInfo;
	mapping(address => Earning[10]) public mapLevelEarning;
	mapping(address => uint256) public totalBusiness;
	mapping(address => uint256) public workingBonus;
	mapping(address => mapping(uint256 => uint256)) public monthlySale;
	mapping(address => mapping(uint256 => bool)) public monthlySaleClaimed;
	mapping(address => mapping(uint256 => uint256)) public stageWiseTBC;
	mapping(address => mapping(uint256 => uint256)) public stageWiseTBCSold;
	
    event Deposit(address user, uint256 amount);
    event Withdraw(address user, uint256 amount);
	event PoolUpdated(uint256 amount);
	event StageStatusUpdated(bool stage1Status, bool stage2Status, bool stage3Status, bool stage4Status, bool stage5Status, bool stage6Status);
	
    constructor() {
	
		investmentPackages[0] =  100 * 10**18;
		investmentPackages[1] =  500 * 10**18;
		investmentPackages[2] =  1000 * 10**18;
		investmentPackages[3] =  2500 * 10**18;
		investmentPackages[4] =  5000 * 10**18;
		investmentPackages[5] =  10000 * 10**18;
		
		referrerBonus[0]  = 500;
		referrerBonus[1]  = 300;
		referrerBonus[2]  = 200;
		referrerBonus[3]  = 100;
		referrerBonus[4]  = 100;
		referrerBonus[5]  = 50;
		referrerBonus[6]  = 50;
		referrerBonus[7]  = 50;
		referrerBonus[8]  = 50;
		referrerBonus[9]  = 50;
		
		teamRequiredForBonus[0]  = 0;
		teamRequiredForBonus[1]  = 3;
		teamRequiredForBonus[2]  = 3;
		teamRequiredForBonus[3]  = 3;
		teamRequiredForBonus[4]  = 3;
		teamRequiredForBonus[5]  = 3;
		teamRequiredForBonus[6]  = 3;
		teamRequiredForBonus[7]  = 3;
		teamRequiredForBonus[8]  = 3;
		teamRequiredForBonus[9]  = 3;
		
		pricePerStage[0] = 1 * 10**18;
		pricePerStage[1] = 10 * 10**18;
		pricePerStage[2] = 100 * 10**18;
		pricePerStage[3] = 1000 * 10**18;
		pricePerStage[4] = 10000 * 10**18;
		
		TBCPerStage[0] = 2000000 * 10**18;
		TBCPerStage[1] = 2000000 * 10**18; 
		TBCPerStage[2] = 2000000 * 10**18; 
		TBCPerStage[3] = 2000000 * 10**18; 
		TBCPerStage[4] = 2000000 * 10**18;
		
		usersTBCPerStage[0] = 0;
		usersTBCPerStage[1] = 0; 
		usersTBCPerStage[2] = 0; 
		usersTBCPerStage[3] = 0; 
		usersTBCPerStage[4] = 0;
		
		statusPerStage[0] = true;
		statusPerStage[1] = false;
		statusPerStage[2] = false; 
		statusPerStage[3] = false;  
		statusPerStage[4] = false;   
		statusPerStage[5] = false; 	
		
		communityIncentives = 4000; 
		extraIncentives = 1000;
		royaltyIncentive = 1000;		
		
		nextRewardDrain = block.timestamp + 30 days;
		
		Referrals = IReferrals(0x62D9021d8E6F189D154360b469407cE21dE407e4);
		TUSD = address(0x62D9021d8E6F189D154360b469407cE21dE407e4);
		FundWallet = address(0x62D9021d8E6F189D154360b469407cE21dE407e4);
		ownerWallet = address(0x62D9021d8E6F189D154360b469407cE21dE407e4);
    }
	
	function buy(uint256 packages, uint256 stage, address investor, address sponsor, uint256 stage2Share, uint256 stage3Share, uint256 stage4Share, uint256 stage5Share, uint256 stage6Share) external {
	   require(packages < investmentPackages.length, "Staking packages not found");
	   require(IERC20(TUSD).balanceOf(msg.sender) >= investmentPackages[packages], "balance not available for staking");
	   require(sponsor != address(0), 'zero address');
	   require(sponsor != msg.sender, "ERR: referrer different required");
	   if(!saleEnable) 
	   {
	      saleEnable = true;
	   }
	   
	   uint256 TUSDAmount = investmentPackages[packages];
	   IERC20(TUSD).safeTransferFrom(address(msg.sender), address(this), TUSDAmount);
	   
	   if(Referrals.getSponsor(investor) == address(0)) 
	   {
		  Referrals.addMember(investor, sponsor);
	   }
	   else
	   {
	      sponsor = Referrals.getSponsor(investor);
	   }
	   
	   if(stage == 0)
	   {  
	       uint256 totalTBC = TUSDAmount * 10**18 / pricePerStage[0];
		   require(TBCPerStage[0] >= totalTBC, "TBC not available for sale");
		   require(stage2Share + stage3Share + stage4Share + stage5Share + stage6Share == totalTBC, "Stagewise coin distrubation is not correct");
	       require(statusPerStage[0], "Stage is closed");
		   
		   if(stage2Share > 0)
		   {
		       stage2UserTBC.push(stage2Share);
			   stage2UserWallet.push(investor);
			   
			   TBCPerStage[1] += stage2Share;
			   usersTBCPerStage[1] += stage2Share; 
			   stageWiseTBC[address(msg.sender)][1] += stage2Share;
		   }
		   if(stage3Share > 0)
		   {
		       stage3UserTBC.push(stage3Share);
			   stage3UserWallet.push(investor);
			   
			   TBCPerStage[2] += stage3Share;
			   usersTBCPerStage[2] += stage3Share;
			   stageWiseTBC[address(msg.sender)][2] += stage3Share;
		   }
		   if(stage4Share > 0)
		   {
		       stage4UserTBC.push(stage4Share);
			   stage4UserWallet.push(investor);
			   
			   TBCPerStage[3] += stage4Share;
			   usersTBCPerStage[3] += stage4Share;
			   stageWiseTBC[address(msg.sender)][3] += stage4Share;
		   }
		   if(stage5Share > 0)
		   {
		       stage5UserTBC.push(stage5Share);
			   stage5UserWallet.push(investor);
			   
			   TBCPerStage[4] += stage5Share;
			   usersTBCPerStage[4] += stage5Share;
			   stageWiseTBC[address(msg.sender)][4] += stage5Share;
		   }
		   if(stage6Share > 0)
		   {
		       stage6UserTBC.push(stage6Share);
			   stage6UserWallet.push(investor);
			   
			   TBCPerStage[5] += stage6Share;
			   usersTBCPerStage[5] += stage6Share;
			   stageWiseTBC[address(msg.sender)][5] += stage6Share;
		   }
		   TBCPerStage[0] -= totalTBC;
		   if(TBCPerStage[0] == 0)
		   {
		      statusPerStage[0] = false;
			  statusPerStage[1] = true;
		   }
	   }
	   else if(stage == 1)
	   {
	       uint256 totalTBC = TUSDAmount * 10**18 / pricePerStage[1];
		   
		   require(TBCPerStage[1] >= totalTBC, "TBC not available for sale");
		   require(stage3Share + stage4Share + stage5Share + stage6Share == totalTBC, "Stagewise coin distrubation is not correct");
	       require(statusPerStage[1], "Stage is closed");
		   
		   uint256 sponsorShare = totalTBC * 20 / 100;
		   uint256 userShare  = totalTBC * 40 / 100;
		   
		   uint256 start = indexPerStage[1];
		   for(uint256 i=start; i < stage2UserTBC.length; i++) 
		   {
				uint256 indexTBC = stage2UserTBC[i];
				if(indexTBC >= userShare)
				{
				   stage2UserTBC[i] -= userShare;
				   uint256 userFund = totalTBC * pricePerStage[1] / 10**18;
				   uint256 communityFee = userFund * communityIncentives / 10000;
				   IERC20(TUSD).safeTransfer(address(stage2UserWallet[i]), userFund - communityFee);
				   break;
				}
				else
				{
					uint256 userFund = stage2UserTBC[i] * pricePerStage[1] / 10**18;
					uint256 communityFee = userFund * communityIncentives / 10000;
					IERC20(TUSD).safeTransfer(address(stage2UserWallet[i]), userFund - communityFee);
					userShare -= stage2UserTBC[i];
					stage2UserTBC[i] = 0;
					indexPerStage[1] = i;
				}
			}
		   
		    start = indexPerStage[1];
			for(uint256 i=start; i < stage2UserTBC.length; i++) 
			{
			    if(stage2UserWallet[i] == address(sponsor))
				{
					uint256 indexTBC = stage2UserTBC[i];
					if(indexTBC >= sponsorShare)
					{
					   stage2UserTBC[i] -= sponsorShare;
					   uint256 userFund = totalTBC * pricePerStage[1] / 10**18;
					   uint256 communityFee = userFund * communityIncentives / 10000;
					   IERC20(TUSD).safeTransfer(address(stage2UserWallet[i]), userFund - communityFee);
					   break;
					}
					else
					{
						uint256 userFund = stage2UserTBC[i] * pricePerStage[1] / 10**18;
						uint256 communityFee = userFund * communityIncentives / 10000;
						IERC20(TUSD).safeTransfer(address(stage2UserWallet[i]), userFund - communityFee);
						sponsorShare -= stage2UserTBC[i];
						stage2UserTBC[i] = 0;
					}
				}
			}
		   
		   if(stage3Share > 0)
		   {
		       stage3UserTBC.push(stage3Share);
			   stage3UserWallet.push(investor);
			   
			   TBCPerStage[2] += stage3Share;
			   usersTBCPerStage[2] += stage3Share;
			   stageWiseTBC[address(msg.sender)][2] += stage3Share;
		   }
		   if(stage4Share > 0)
		   {
		       stage4UserTBC.push(stage4Share);
			   stage4UserWallet.push(investor);
			   
			   TBCPerStage[3] += stage4Share;
			   usersTBCPerStage[3] += stage4Share;
			   stageWiseTBC[address(msg.sender)][3] += stage4Share;
		   }
		   if(stage5Share > 0)
		   {
		       stage5UserTBC.push(stage5Share);
			   stage5UserWallet.push(investor);
			   
			   TBCPerStage[4] += stage5Share;
			   usersTBCPerStage[4] += stage5Share;
			   stageWiseTBC[address(msg.sender)][4] += stage5Share;
		   }
		   if(stage6Share > 0)
		   {
		       stage6UserTBC.push(stage6Share);
			   stage6UserWallet.push(investor);
			   
			   TBCPerStage[5] += stage6Share;
			   usersTBCPerStage[5] += stage6Share;
			   stageWiseTBC[address(msg.sender)][5] += stage6Share;
		   }
		   TBCPerStage[1] -= totalTBC;
		   if(TBCPerStage[1] == 0)
		   {
		      statusPerStage[1] = false;
			  statusPerStage[2] = true;
		   }
	   }
	   else if(stage == 2)
	   {
	       uint256 totalTBC = TUSDAmount * 10**18 / pricePerStage[2];
		   
		   require(TBCPerStage[2] >= totalTBC, "TBC not available for sale");
		   require(stage4Share + stage5Share + stage6Share == totalTBC, "Stagewise coin distrubation is not correct");
	       require(statusPerStage[2], "Stage is closed");
		   
		   uint256 sponsorShare = totalTBC * 20 / 100;
		   uint256 userShare  = totalTBC * 40 / 100;
		   
		   uint256 start = indexPerStage[2];
		   for(uint256 i=start; i < stage3UserTBC.length; i++) 
		   {
				uint256 indexTBC = stage3UserTBC[i];
				if(indexTBC >= userShare)
				{
				   stage3UserTBC[i] -= userShare;
				   uint256 userFund = totalTBC * pricePerStage[2] / 10**18;
				   uint256 communityFee = userFund * communityIncentives / 10000;
				   IERC20(TUSD).safeTransfer(address(stage3UserWallet[i]), userFund - communityFee);
				   break;
				}
				else
				{
					uint256 userFund = stage3UserTBC[i] * pricePerStage[2] / 10**18;
					uint256 communityFee = userFund * communityIncentives / 10000;
					IERC20(TUSD).safeTransfer(address(stage3UserWallet[i]), userFund - communityFee);
					userShare -= stage3UserTBC[i];
					stage3UserTBC[i] = 0;
					indexPerStage[1] = i;
				}
			}
		   
		    start = indexPerStage[2];
			for(uint256 i=start; i < stage3UserTBC.length; i++) 
			{
			    if(stage3UserWallet[i] == address(sponsor))
				{
					uint256 indexTBC = stage3UserTBC[i];
					if(indexTBC >= sponsorShare)
					{
					   stage3UserTBC[i] -= sponsorShare;
					   uint256 userFund = totalTBC * pricePerStage[1] / 10**18;
					   uint256 communityFee = userFund * communityIncentives / 10000;
					   IERC20(TUSD).safeTransfer(address(stage3UserWallet[i]), userFund - communityFee);
					   break;
					}
					else
					{
						uint256 userFund = stage3UserTBC[i] * pricePerStage[1] / 10**18;
						uint256 communityFee = userFund * communityIncentives / 10000;
						IERC20(TUSD).safeTransfer(address(stage3UserWallet[i]), userFund - communityFee);
						sponsorShare -= stage3UserTBC[i];
						stage3UserTBC[i] = 0;
					}
				}
			}
		   
		   if(stage4Share > 0)
		   {
		       stage4UserTBC.push(stage4Share);
			   stage4UserWallet.push(investor);
			   
			   TBCPerStage[3] += stage4Share;
			   usersTBCPerStage[3] += stage4Share;
			   stageWiseTBC[address(msg.sender)][3] += stage4Share;
		   }
		   if(stage5Share > 0)
		   {
		       stage5UserTBC.push(stage5Share);
			   stage5UserWallet.push(investor);
			   
			   TBCPerStage[4] += stage5Share;
			   usersTBCPerStage[4] += stage5Share;
			   stageWiseTBC[address(msg.sender)][4] += stage5Share;
		   }
		   if(stage6Share > 0)
		   {
		       stage6UserTBC.push(stage6Share);
			   stage6UserWallet.push(investor);
			   
			   TBCPerStage[5] += stage6Share;
			   usersTBCPerStage[5] += stage6Share;
			   stageWiseTBC[address(msg.sender)][5] += stage6Share;
		   }
		   
		   TBCPerStage[2] -= totalTBC;
		   if(TBCPerStage[2] == 0)
		   {
		      statusPerStage[2] = false;
			  statusPerStage[3] = true;
		   }
	   }
	   else if(stage == 3)
	   {
	       uint256 totalTBC = TUSDAmount * 10**18 / pricePerStage[3];
		   
		   require(TBCPerStage[3] >= totalTBC, "TBC not available for sale");
		   require(stage5Share + stage6Share == totalTBC, "Stagewise coin distrubation is not correct");
	       require(statusPerStage[3], "Stage is closed");
		   
		   uint256 sponsorShare = totalTBC * 20 / 100;
		   uint256 userShare  = totalTBC * 40 / 100;
		   
		   uint256 start = indexPerStage[3];
		   for(uint256 i=start; i < stage4UserTBC.length; i++) 
		   {
				uint256 indexTBC = stage4UserTBC[i];
				if(indexTBC >= userShare)
				{
				   stage4UserTBC[i] -= userShare;
				   uint256 userFund = totalTBC * pricePerStage[3] / 10**18;
				   uint256 communityFee = userFund * communityIncentives / 10000;
				   IERC20(TUSD).safeTransfer(address(stage4UserWallet[i]), userFund - communityFee);
				   break;
				}
				else
				{
					uint256 userFund = stage4UserTBC[i] * pricePerStage[3] / 10**18;
					uint256 communityFee = userFund * communityIncentives / 10000;
					IERC20(TUSD).safeTransfer(address(stage4UserWallet[i]), userFund - communityFee);
					userShare -= stage4UserTBC[i];
					stage4UserTBC[i] = 0;
					indexPerStage[1] = i;
				}
			}
		   
		    start = indexPerStage[3];
			for(uint256 i=start; i < stage4UserTBC.length; i++) 
			{
			    if(stage4UserWallet[i] == address(sponsor))
				{
					uint256 indexTBC = stage4UserTBC[i];
					if(indexTBC >= sponsorShare)
					{
					   stage4UserTBC[i] -= sponsorShare;
					   uint256 userFund = totalTBC * pricePerStage[3] / 10**18;
					   uint256 communityFee = userFund * communityIncentives / 10000;
					   IERC20(TUSD).safeTransfer(address(stage4UserWallet[i]), userFund - communityFee);
					   break;
					}
					else
					{
						uint256 userFund = stage4UserTBC[i] * pricePerStage[3] / 10**18;
						uint256 communityFee = userFund * communityIncentives / 10000;
						IERC20(TUSD).safeTransfer(address(stage4UserWallet[i]), userFund - communityFee);
						sponsorShare -= stage4UserTBC[i];
						stage4UserTBC[i] = 0;
					}
				}
			}
		   
		   if(stage5Share > 0)
		   {
		       stage5UserTBC.push(stage5Share);
			   stage5UserWallet.push(investor);
			   
			   TBCPerStage[4] += stage5Share;
			   usersTBCPerStage[4] += stage5Share;
			   stageWiseTBC[address(msg.sender)][4] += stage5Share;
		   }
		   if(stage6Share > 0)
		   {
		       stage6UserTBC.push(stage6Share);
			   stage6UserWallet.push(investor);
			   
			   TBCPerStage[5] += stage6Share;
			   usersTBCPerStage[5] += stage6Share;
			   stageWiseTBC[address(msg.sender)][5] += stage6Share;
		   }
		   TBCPerStage[3] -= totalTBC;
		   if(TBCPerStage[3] == 0)
		   {
		      statusPerStage[3] = false;
			  statusPerStage[4] = true;
		   }
	   }
	   else if(stage == 4)
	   {
	       uint256 totalTBC = TUSDAmount * 10**18 / pricePerStage[4];
		   
		   require(TBCPerStage[4] >= totalTBC, "TBC not available for sale");
		   require(stage6Share == totalTBC, "Stagewise coin distrubation is not correct");
	       require(statusPerStage[4], "Stage is closed");
		   
		   uint256 sponsorShare = totalTBC * 20 / 100;
		   uint256 userShare = totalTBC * 40 / 100;
		   
		   uint256 start = indexPerStage[4];
		   for(uint256 i=start; i < stage5UserTBC.length; i++) 
		   {
				uint256 indexTBC = stage5UserTBC[i];
				if(indexTBC >= userShare)
				{
				   stage5UserTBC[i] -= userShare;
				   uint256 userFund = totalTBC * pricePerStage[4] / 10**18;
				   uint256 communityFee = userFund * communityIncentives / 10000;
				   IERC20(TUSD).safeTransfer(address(stage5UserWallet[i]), userFund - communityFee);
				   break;
				}
				else
				{
					uint256 userFund = stage5UserTBC[i] * pricePerStage[4] / 10**18;
					uint256 communityFee = userFund * communityIncentives / 10000;
					IERC20(TUSD).safeTransfer(address(stage5UserWallet[i]), userFund - communityFee);
					userShare -= stage5UserTBC[i];
					stage5UserTBC[i] = 0;
					indexPerStage[1] = i;
				}
			}
		   
		    start = indexPerStage[4];
			for(uint256 i=start; i < stage5UserTBC.length; i++) 
			{
			    if(stage5UserWallet[i] == address(sponsor))
				{
					uint256 indexTBC = stage5UserTBC[i];
					if(indexTBC >= sponsorShare)
					{
					   stage5UserTBC[i] -= sponsorShare;
					   uint256 userFund = totalTBC * pricePerStage[4] / 10**18;
					   uint256 communityFee = userFund * communityIncentives / 10000;
					   IERC20(TUSD).safeTransfer(address(stage5UserWallet[i]), userFund - communityFee);
					   break;
					}
					else
					{
						uint256 userFund = stage5UserTBC[i] * pricePerStage[4] / 10**18;
						uint256 communityFee = userFund * communityIncentives / 10000;
						IERC20(TUSD).safeTransfer(address(stage5UserWallet[i]), userFund - communityFee);
						sponsorShare -= stage5UserTBC[i];
						stage5UserTBC[i] = 0;
					}
				}
			}
		   
		   if(stage6Share > 0)
		   {
		       stage6UserTBC.push(stage6Share);
			   stage6UserWallet.push(investor);
			   
			   TBCPerStage[5] += stage6Share;
			   usersTBCPerStage[5] += stage6Share;
			   stageWiseTBC[address(msg.sender)][5] += stage6Share;
		   }
		   
		   TBCPerStage[4] -= totalTBC;
		   if(TBCPerStage[4] == 0)
		   {
		      statusPerStage[4] = false;
			  statusPerStage[5] = true;
		   }
	   }
	   
	   if(block.timestamp >= nextRewardDrain)
	   {
	      nextRewardDrain += 30 days;
	   }
	   mapUserInfo[msg.sender].investedAmount += TUSDAmount;
	   totalBusiness[sponsor] += TUSDAmount;
	   uint256 myDirect = Referrals.getTeam(address(sponsor), 0);
	   
	   if(myDirect >= 3 && totalBusiness[sponsor] >= 1500 * 10**18 && !mapUserInfo[sponsor].royalty)
	   {
	      mapUserInfo[sponsor].royalty = true;
	   }
	   
	   referralBonusDistribution(investor, TUSDAmount);
	   workingBonusDistribution(investor, TUSDAmount);
	   foreignTourBonusDistribution(sponsor, totalBusiness[sponsor]);
	   monthlyBonusDistribution(investor, TUSDAmount);
	   
	   IERC20(TUSD).safeTransfer(address(ownerWallet), IERC20(TUSD).balanceOf(address(this)));
    }
	
	function monthlyBonusDistribution(address sponsor, uint256 amount) private {
	    address nextReferrer = Referrals.getSponsor(sponsor);
		for(uint256 i=0; i < 512; i++) 
		{
			if(nextReferrer != address(0)) 
			{ 
			   monthlySale[nextReferrer][nextRewardDrain] += amount;
			}
			else 
			{
		       break;
			}
		    nextReferrer = Referrals.getSponsor(nextReferrer);
		}
	}
	
	function foreignTourBonusDistribution(address sponsor, uint256 amount) private {
	
	   uint256 incentiveAmount = (amount / 3000 * 10**18) * (300 * 10**18);
	   if(incentiveAmount > mapUserInfo[sponsor].foreignTour)
	   {
	       uint256 payableAmount = incentiveAmount - mapUserInfo[sponsor].foreignTour;
		   if(mapUserInfo[Referrals.getSponsor(sponsor)].royalty)
		   {
			  royaltyBonusDistribution(Referrals.getSponsor(sponsor), ((payableAmount * royaltyIncentive) / 10000));
		   }
		   if(IERC20(TUSD).balanceOf(address(this)) >= payableAmount)
		   {
		       mapUserInfo[sponsor].foreignTour += payableAmount;
			   mapUserInfo[sponsor].claimedAmount += payableAmount;
		       IERC20(TUSD).safeTransfer(address(sponsor), payableAmount);
		   }
		   else if(IERC20(TUSD).allowance(address(FundWallet), address(this)) >= payableAmount && IERC20(TUSD).balanceOf(address(FundWallet)) >= payableAmount)
		   {
		       mapUserInfo[sponsor].foreignTour += payableAmount;
			   mapUserInfo[sponsor].claimedAmount += payableAmount;
               IERC20(TUSD).safeTransferFrom(address(FundWallet), address(sponsor), payableAmount);
		   }
		   else
		   {
		      mapUserInfo[sponsor].foreignTour += payableAmount;
		   }
	   }
	}
	
	function workingBonusDistribution(address sponsor, uint256 amount) private {
	    address nextReferrer = Referrals.getSponsor(sponsor);
		for(uint256 i=0; i < 512; i++) 
		{
			if(nextReferrer != address(0)) 
			{   
				if(workingBonus[nextReferrer] > 0)
				{
				    uint256 payableAmount = amount * (workingBonus[nextReferrer]) / 10000;
					if(IERC20(TUSD).balanceOf(address(this)) >= payableAmount)
					{
					    mapUserInfo[nextReferrer].workingBonus += payableAmount;
					    mapUserInfo[sponsor].claimedAmount += payableAmount;
					    IERC20(TUSD).safeTransfer(address(sponsor), payableAmount);
					    break;
					}
					else if(IERC20(TUSD).allowance(address(FundWallet), address(this)) >= payableAmount && IERC20(TUSD).balanceOf(address(FundWallet)) >= payableAmount)
					{
					    mapUserInfo[nextReferrer].workingBonus += payableAmount;
					    mapUserInfo[sponsor].claimedAmount += payableAmount;
					    IERC20(TUSD).safeTransferFrom(address(FundWallet), address(nextReferrer), payableAmount);
					    break;
					}
					else
					{
					    mapUserInfo[nextReferrer].workingBonus += payableAmount;
					    break;
					}
				}
			}
			else 
			{
		       break;
			}
		    nextReferrer = Referrals.getSponsor(nextReferrer);
		}
	}
	
	function referralBonusDistribution(address sponsor, uint256 amount) private {
		address nextReferrer = Referrals.getSponsor(sponsor);
		for(uint256 i=0; i < 10; i++) 
		{
			if(nextReferrer != address(0)) 
			{   
			    uint256 myDirect = Referrals.getTeam(address(nextReferrer), 0);
			    if(myDirect >= teamRequiredForBonus[i])
				{
				   address sponsorWallet = Referrals.getSponsor(nextReferrer);
				   if(i==0 && myDirect >= 5)
				   {
				        uint256 reward = amount * referrerBonus[i] * 2 / 10000;
						if(mapUserInfo[sponsorWallet].royalty)
						{
						    royaltyBonusDistribution(sponsorWallet, ((reward * royaltyIncentive) / 10000));
						}
					    mapLevelEarning[nextReferrer][i].levelEarning += reward;
					    mapUserInfo[nextReferrer].levelIncome += reward;
			            mapUserInfo[nextReferrer].claimedAmount += reward;
					    IERC20(TUSD).safeTransfer(address(nextReferrer), reward);
				   }
				   else
				   {
     				   if(i==0)
					   {
					        uint256 reward = amount * referrerBonus[i] / 10000;
							if(mapUserInfo[sponsorWallet].royalty)
							{
							   royaltyBonusDistribution(sponsorWallet, ((reward * royaltyIncentive) / 10000));
							}
						    mapLevelEarning[nextReferrer][i].levelEarning += reward;
						    mapUserInfo[nextReferrer].levelIncome += reward;
			                mapUserInfo[nextReferrer].claimedAmount += reward;
						    IERC20(TUSD).safeTransfer(address(nextReferrer), reward);
					   }
					   else if(totalBusiness[address(nextReferrer)] >= 1500 * 10**18)
					   { 
					       uint256 reward = amount * referrerBonus[i] / 10000;
						   if(mapUserInfo[sponsorWallet].royalty)
						   {
							  royaltyBonusDistribution(sponsorWallet, ((reward * royaltyIncentive) / 10000));
						   }
						   mapLevelEarning[nextReferrer][i].levelEarning += reward;
						   mapUserInfo[nextReferrer].levelIncome += reward;
			               mapUserInfo[nextReferrer].claimedAmount += reward;
						   IERC20(TUSD).safeTransfer(address(nextReferrer), reward);
					   }
				   }
				}
			}
			else 
			{
		       break;
			}
		    nextReferrer = Referrals.getSponsor(nextReferrer);
		}
    }
	
	function royaltyBonusDistribution(address sponsor, uint256 payableAmount) private {
		if(IERC20(TUSD).balanceOf(address(this)) >= payableAmount)
		{
			mapUserInfo[sponsor].royaltyBonus += payableAmount;
			mapUserInfo[sponsor].claimedAmount += payableAmount;
			IERC20(TUSD).safeTransfer(address(sponsor), payableAmount);
		}
		else if(IERC20(TUSD).allowance(address(FundWallet), address(this)) >= payableAmount && IERC20(TUSD).balanceOf(address(FundWallet)) >= payableAmount)
		{
			mapUserInfo[sponsor].royaltyBonus += payableAmount;
			mapUserInfo[sponsor].claimedAmount += payableAmount;
			IERC20(TUSD).safeTransferFrom(address(FundWallet), address(sponsor), payableAmount);
		}
		else
		{
		    mapUserInfo[sponsor].royaltyBonus += payableAmount;
		} 
	}
	
	function claimMonthlyReward(address topSponsor, uint256 month) external {
	    require(monthlySaleClaimed[address(msg.sender)][month] == false, "Already claimed");
	    require(Referrals.getSponsor(topSponsor) == address(msg.sender), "Incorrect top sponsor");
		
	    uint256 topSponsorSale = monthlySale[address(topSponsor)][month];
	    uint256 allSale = monthlySale[address(msg.sender)][month];
	    uint256 remainingTeamSale = allSale - topSponsorSale;
		
	    uint256 payableAmount = 0;
		if(topSponsorSale >= 10000000 * 10**18 && remainingTeamSale >=10000000 * 10**18)
		{
		    payableAmount = 1000000 * 10**18;
		}
		else if(topSponsorSale >= 5000000 * 10**18 && remainingTeamSale >=5000000 * 10**18)
		{
			payableAmount = 400000 * 10**18;
		}
		else if(topSponsorSale >= 2000000 * 10**18 && remainingTeamSale >=2000000 * 10**18)
		{
			payableAmount = 150000 * 10**18;
		}
		else if(topSponsorSale >= 500000 * 10**18 && remainingTeamSale >=500000 * 10**18)
		{
			payableAmount = 35000 * 10**18;
		}
		else if(topSponsorSale >= 125000 * 10**18 && remainingTeamSale >=125000 * 10**18)
		{
			payableAmount = 8500 * 10**18;
		}
		else if(topSponsorSale >= 50000 * 10**18 && remainingTeamSale >=50000 * 10**18)
		{
			payableAmount = 3000 * 10**18;
		}
		else if(topSponsorSale >= 15000 * 10**18 && remainingTeamSale >=15000 * 10**18)
		{
			payableAmount = 800 * 10**18;
		}
		else if(topSponsorSale >=5000 * 10**18 && remainingTeamSale >=5000 * 10**18)
		{
			payableAmount = 250 * 10**18;
		}
		else
		{
			payableAmount = 0;
		}
		
		if(payableAmount > 0 && IERC20(TUSD).allowance(address(FundWallet), address(this)) >= payableAmount && IERC20(TUSD).balanceOf(address(FundWallet)) >= payableAmount)
		{
		    monthlySaleClaimed[address(msg.sender)][month] = true;
		    address sponsor = Referrals.getSponsor(address(msg.sender));
		    if(mapUserInfo[sponsor].royalty)
		    {
			  royaltyBonusDistribution(sponsor, ((payableAmount * royaltyIncentive) / 10000));
		    }
		    IERC20(TUSD).safeTransferFrom(address(FundWallet), address(msg.sender), payableAmount);
		}
	}
	
	function withdrawEarning() external {
	    require(mapUserInfo[address(msg.sender)].investedAmount > 0, "Incorrect request");
		
		uint256 payableAmount = pendingReward(address(msg.sender));
		if(payableAmount > 0 && IERC20(TUSD).allowance(address(FundWallet), address(this)) >= payableAmount && IERC20(TUSD).balanceOf(address(FundWallet)) >= payableAmount)
		{
		    mapUserInfo[address(msg.sender)].claimedAmount += payableAmount;
		    IERC20(TUSD).safeTransferFrom(address(FundWallet), address(msg.sender), payableAmount);
		}
	}
	
	function pendingReward(address user) public view returns (uint256) 
	{
	    if(mapUserInfo[address(user)].investedAmount > 0) 
	    {
		    uint256 pending = (mapUserInfo[user].levelIncome + mapUserInfo[user].foreignTour + mapUserInfo[user].workingBonus + mapUserInfo[user].royaltyBonus) - (mapUserInfo[user].claimedAmount);
		    return pending;
		}
		else
		{
		   return 0;
		}
	}
	
	function setWorkingBonus(address user, uint256 bonus) external {
	   require(msg.sender == address(FundWallet), "Incorrect request");
	   require(bonus <= 500, "Working bonus can't be more than 30%");
	   workingBonus[address(user)] = bonus;
  	}
	
	function setTeam(uint256[8] memory userStats, bool royalty, address investor, address sponsor, uint256 stage2Share, uint256 stage3Share, uint256 stage4Share, uint256 stage5Share, uint256 stage6Share) external {
	   require(msg.sender == address(FundWallet), "Incorrect request");
	   require(!saleEnable, "Sale already enable");
	   
	   if(Referrals.getSponsor(investor) == address(0)) 
	   {
		  Referrals.addMember(investor, address(sponsor));
	   }
	   
	   uint256 totalTBC = stage2Share + stage3Share + stage4Share + stage5Share + stage6Share;
	   if(stage2Share > 0)
	   {
		   stage2UserTBC.push(stage2Share);
		   stage2UserWallet.push(investor);
		   
		   TBCPerStage[1] += stage2Share;
		   usersTBCPerStage[1] += stage2Share; 
		   stageWiseTBC[address(investor)][1] += stage2Share;
	   }
	   if(stage3Share > 0)
	   {
		   stage3UserTBC.push(stage3Share);
		   stage3UserWallet.push(investor);
		   
		   TBCPerStage[2] += stage3Share;
		   usersTBCPerStage[2] += stage3Share;
		   stageWiseTBC[address(investor)][2] += stage3Share;
	   }
	   if(stage4Share > 0)
	   {
		   stage4UserTBC.push(stage4Share);
		   stage4UserWallet.push(investor);
		   
		   TBCPerStage[3] += stage4Share;
		   usersTBCPerStage[3] += stage4Share;
		   stageWiseTBC[address(investor)][3] += stage4Share;
	   }
	   if(stage5Share > 0)
	   {
		   stage5UserTBC.push(stage5Share);
		   stage5UserWallet.push(investor);
		   
		   TBCPerStage[4] += stage5Share;
		   usersTBCPerStage[4] += stage5Share;
		   stageWiseTBC[address(investor)][4] += stage5Share;
	   }
	   if(stage6Share > 0)
	   {
		   stage6UserTBC.push(stage6Share);
		   stage6UserWallet.push(investor);
		   
		   TBCPerStage[5] += stage6Share;
		   usersTBCPerStage[5] += stage6Share;
		   stageWiseTBC[address(investor)][5] += stage6Share;
	   }
	   
	   TBCPerStage[0] -= totalTBC;
	   mapUserInfo[address(investor)].investedAmount = userStats[0];
	   mapUserInfo[address(investor)].levelIncome  = userStats[1];
	   mapUserInfo[address(investor)].foreignTour  = userStats[2];
	   mapUserInfo[address(investor)].monthlyReward  = userStats[3];
	   mapUserInfo[address(investor)].workingBonus  = userStats[4];
	   mapUserInfo[address(investor)].royaltyBonus  = userStats[5];
	   mapUserInfo[address(investor)].claimedAmount  = userStats[6];
	   monthlySale[address(investor)][nextRewardDrain] = userStats[7];
	   mapUserInfo[address(investor)].royalty = royalty;
  	}
	
	function claimTBC() external {
	   require(statusPerStage[5], "Exchange stage is not start yet");

	   uint256 claimableTBC = stageWiseTBC[address(msg.sender)][5] - mapUserInfo[address(msg.sender)].claimedTBC;
	   if(claimableTBC > 0)
	   {
	      payable(msg.sender).transfer(claimableTBC);
		  mapUserInfo[address(msg.sender)].claimedTBC += claimableTBC;
	   }
  	}
}