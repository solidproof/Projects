// SPDX-License-Identifier: MIT

pragma solidity 0.8.2;

contract Referrals {

    address investmentPlan;
	
	struct mapMyTeam {
	   address sponsor;
    }
	
	struct sponsoredTeam {
	   address referrer;
	   uint256 joinTime;
    }

	struct Team{
      uint256 member;
    }
	
	mapping(address => mapping(uint256 => sponsoredTeam)) public mapSponsoredTeam;
	mapping(address => mapMyTeam) public mapTeamAllData;
	mapping(address => Team[10]) public mapTeam;
    mapping(address => bool) public moderators;
	mapping(address => uint256) public downline;
    
	event TeamMember(address sponsor, address user);
	
    constructor(address plan) {
	    investmentPlan = address(plan);
	}
	
    function addMember(address teamMember, address sponsor) external {
	   require(address(msg.sender) == address(investmentPlan), "Incorrect request");
	   require(teamMember != address(0) && sponsor != address(0), "Zero address");
	   require(teamMember != sponsor, "Referrer different required");
	   require(mapTeamAllData[teamMember].sponsor == address(0), "Member already added in list");
	   
	   mapSponsoredTeam[sponsor][mapTeam[sponsor][0].member].referrer = teamMember;
	   mapSponsoredTeam[sponsor][mapTeam[sponsor][0].member].joinTime = block.timestamp;
	   
	   mapTeamAllData[teamMember].sponsor = sponsor;
	   enterTeam(teamMember);
	   emit TeamMember(sponsor, teamMember);
    }
    
	function getSponsor(address teamMember) external view returns (address) {
       return mapTeamAllData[teamMember].sponsor;
    }
	
    function enterTeam(address sender) internal {
		address nextSponsor = mapTeamAllData[sender].sponsor;
		uint256 i;
        for(i=0; i < 10; i++) {
			if(nextSponsor != address(0)) 
			{
				downline[nextSponsor] += 1;
				mapTeam[nextSponsor][i].member += 1; 
			}
			else 
			{
				 break;
			}
			nextSponsor = mapTeamAllData[nextSponsor].sponsor;
		}
	}
	
    function getTeam(address sponsor, uint256 level) external view returns(uint256){
       return mapTeam[sponsor][level].member;
    }   
}