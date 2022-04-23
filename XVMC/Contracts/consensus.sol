// SPDX-License-Identifier: BUSL-1.1

pragma solidity 0.8.0;

import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "../files/libs/custom/IERC20.sol";
import "../files/libs/standard/Address.sol";
import "../files/libs/custom/SafeERC20.sol";

interface IXVMCgovernor {
    function costToVote() external returns (uint256);
    function maximumVoteTokens() external returns (uint256);
    function delayBeforeEnforce() external returns (uint256);
    function eventFibonacceningActive() external returns (bool);

    function fibonacciDelayed() external returns (bool);
    function delayFibonacci(bool _arg) external;
    function eligibleNewGovernor() external returns (address);
    function changeGovernorActivated() external returns (bool);
    function setNewGovernor(address beneficiary) external;
    function executeWithdraw(uint256 withdrawID) external;
    function treasuryRequest(address _tokenAddr, address _recipient, uint256 _amountToSend) external;
    function newGovernorRequestBlock() external returns (uint256);
    function enforceGovernor() external;

    function acPool1() external view returns (address);
    function acPool2() external view returns (address);
    function acPool3() external view returns (address);
    function acPool4() external view returns (address);
    function acPool5() external view returns (address);
    function acPool6() external view returns (address);
}

interface IMasterChef {
    function XVMCPerBlock() external view returns (uint256);
    function owner() external view returns (address);
}

interface IacPool {
    function totalShares() external view returns (uint256);
    function totalVotesForID(uint256 proposalID) external view returns (uint256);
    function getPricePerFullShare() external view returns (uint256);
}

interface IToken {
    function governor() external view returns (address);
}

contract XVMCconsensus is Ownable {
    using SafeERC20 for IERC20;

	struct HaltFibonacci {
		bool valid;
		bool enforced;
		uint256 consensusVoteID;
		uint256 startTimestamp;
		uint256 delayInSeconds;
	}
    struct TreasuryTransfer {
        bool valid;
        uint256 firstCallTimestamp;
        uint256 valueSacrificedForVote;
		uint256 valueSacrificedAgainst;
		uint256 delay;
		address tokenAddress;
        address beneficiary;
		uint256 amountToSend;
		uint256 consensusProposalID;
    }
	struct ConsensusVote {
        uint16 typeOfChange; // 0 == governor change, 1 == treasury transfer, 2 == halt fibonaccening
        address beneficiaryAddress;
		uint256 timestamp;
    }
	struct GovernorInvalidated {
        bool isInvalidated;
        bool hasPassed;
    }

	HaltFibonacci[] public haltProposal;
	TreasuryTransfer[] public treasuryProposal;
	ConsensusVote[] public consensusProposal;

	uint256 public immutable goldenRatio = 1618; //1.618 is the golden ratio
    address public immutable token; //XVMC token (address)

    //masterchef address
    address public masterchef;

    //addresses for time-locked deposits(autocompounding pools)
    address public acPool1;
    address public acPool2;
    address public acPool3;
    address public acPool4;
    address public acPool5;
    address public acPool6;


    mapping(address => GovernorInvalidated) public isGovInvalidated;

	constructor(address _XVMC) {
            consensusProposal.push(ConsensusVote(0, address(this), block.timestamp)); //0 is an invalid proposal(is default / neutral position)
			token = _XVMC;
    }


	event ProposalAgainstCommonEnemy(uint256 HaltID, uint256 consensusProposalID, uint256 startTimestamp, uint256 delayInSeconds, address indexed enforcer);
	event EnforceDelay(uint256 consensusProposalID, address indexed enforcer);
	event RemoveDelay(uint256 consensusProposalID, address indexed enforcer);

	event TreasuryProposal(uint256 proposalID, uint256 sacrificedTokens, address tokenAddress, address recipient, uint256 amount, uint256 consensusVoteID, address indexed enforcer, uint256 delay);
	event TreasuryProposalVeto(uint256 proposalID, address indexed enforcer);
	event TreasuryProposalRequested(uint256 proposalID, address indexed enforcer);

    event ProposeGovernor(uint256 proposalID, address newGovernor, address indexed enforcer);
    event ChangeGovernor(uint256 proposalID, address indexed enforcer, bool status);

	event AddVotes(uint256 _type, address indexed voter, uint256 tokensSacrificed, bool _for);


	/*
	* If XVMC is to be listed on margin trading exchanges
	* As a lot of supply is printed during Fibonaccening events
	* It could provide "free revenue" for traders shorting XVMC
	* This is a mechanism meant to give XVMC holders an opportunity
	* to unite against the common enemy(shorters).
	* The function effectively delays the fibonaccening event
	* Requires atleast 15% votes, with less than 50% voting against
	*/
	function uniteAgainstTheCommonEnemy(uint256 startTimestamp, uint256 delayInSeconds) external {
		require(startTimestamp >= (block.timestamp + 3600) && delayInSeconds <= 72 * 3600); //no less than an hour before the event and can't last more than 3 days

		IERC20(token).safeTransferFrom(msg.sender, owner(), 50 * IXVMCgovernor(owner()).costToVote());

		uint256 _consensusID = consensusProposal.length;

		//need to create consensus proposal because the voting is done by voting for a proposal ID(inside pool contracts)
		consensusProposal.push(
		    ConsensusVote(2, address(this), block.timestamp)
		    ); // vote for
    	consensusProposal.push(
    	    ConsensusVote(2, address(this), block.timestamp)
    	    ); // vote against

		 haltProposal.push(
    	    HaltFibonacci(true, false, _consensusID, startTimestamp, delayInSeconds)
    	   );

        emit ProposalAgainstCommonEnemy(haltProposal.length - 1, _consensusID, startTimestamp, delayInSeconds, msg.sender);
	}
    function enforceDelay(uint256 fibonacciHaltID) external {
		require(haltProposal[fibonacciHaltID].valid && !haltProposal[fibonacciHaltID].enforced &&
		    haltProposal[fibonacciHaltID].startTimestamp <= block.timestamp &&
		    block.timestamp < haltProposal[fibonacciHaltID].startTimestamp + haltProposal[fibonacciHaltID].delayInSeconds);
		uint256 consensusID = haltProposal[fibonacciHaltID].consensusVoteID;

        uint256 _tokensCasted = tokensCastedPerVote(consensusID);
		 require(
            _tokensCasted >= totalXVMCStaked() * 15 / 100,
				"Atleast 15% of staked(weighted) tokens required"
        );

        require(
            tokensCastedPerVote(consensusID + 1) <= _tokensCasted / 2,
				"More than 50% are voting against!"
        );

		haltProposal[fibonacciHaltID].enforced = true;
		IXVMCgovernor(owner()).delayFibonacci(true);

		emit EnforceDelay(consensusID, msg.sender);
	}
	function removeDelay(uint256 haltProposalID) external {
		require(IXVMCgovernor(owner()).fibonacciDelayed() && haltProposal[haltProposalID].enforced && haltProposal[haltProposalID].valid);
		require(block.timestamp >= haltProposal[haltProposalID].startTimestamp + haltProposal[haltProposalID].delayInSeconds, "not yet expired");

		haltProposal[haltProposalID].valid = false;
		IXVMCgovernor(owner()).delayFibonacci(false);

		emit RemoveDelay(haltProposalID, msg.sender);
	}

     /**
     * Initiates a request to transfer tokens from the treasury wallet
	 * Can be voted against during the "delay before enforce" period
	 * For extra safety
	 * Requires vote from long term stakers to enforce the transfer
	 * Requires 25% of votes to pass
	 * If only 5% of voters disagree, the proposal is rejected
	 *
	 * The possibilities here are endless
	 *
	 * Could act as a NFT marketplace too, could act as a treasury that pays "contractors",..
	 * Since it's upgradeable, this can be added later on anyways....
	 * Should probably make universal private function for Consensus Votes
     */
	function initiateTreasuryTransferProposal(uint256 depositingTokens,  address tokenAddress, address recipient, uint256 amountToSend, uint256 delay) external {
    	require(depositingTokens >= IXVMCgovernor(owner()).costToVote() * 10,
    	    "atleast x10minCostToVote"
    	    );
		require(delay <= IXVMCgovernor(owner()).delayBeforeEnforce(), "must be shorter than Delay before enforce");

    	IERC20(token).safeTransferFrom(msg.sender, owner(), depositingTokens);

		uint256 _consensusID = consensusProposal.length + 1;

		consensusProposal.push(
		    ConsensusVote(1, address(this), block.timestamp)
		    ); // vote for
    	consensusProposal.push(
    	    ConsensusVote(1, address(this), block.timestamp)
    	    ); // vote against

		 treasuryProposal.push(
    	    TreasuryTransfer(true, block.timestamp, depositingTokens, 0, delay, tokenAddress, recipient, amountToSend, _consensusID)
    	   );

        emit TreasuryProposal(
            treasuryProposal.length - 1, depositingTokens, tokenAddress, recipient, amountToSend, _consensusID, msg.sender, delay
            );
    }
	//can only vote with tokens during the delay+delaybeforeenforce period(then this period ends, and to approve the transfer, must be voted through voting with locked shares)
	function voteTreasuryTransferProposalY(uint256 proposalID, uint256 withTokens) external {
		require(treasuryProposal[proposalID].valid, "invalid");
		require(
			treasuryProposal[proposalID].firstCallTimestamp + treasuryProposal[proposalID].delay + IXVMCgovernor(owner()).delayBeforeEnforce() > block.timestamp,
			"can already be enforced"
		);

		IERC20(token).safeTransferFrom(msg.sender, owner(), withTokens);

		treasuryProposal[proposalID].valueSacrificedForVote+= withTokens;

		emit AddVotes(0, msg.sender, withTokens, true);
	}
	function voteTreasuryTransferProposalN(uint256 proposalID, uint256 withTokens, bool withAction) external {
		require(treasuryProposal[proposalID].valid, "invalid");
		require(
			treasuryProposal[proposalID].firstCallTimestamp + treasuryProposal[proposalID].delay + IXVMCgovernor(owner()).delayBeforeEnforce() > block.timestamp,
			"can already be enforced"
		);

		IERC20(token).safeTransferFrom(msg.sender, owner(), withTokens);

		treasuryProposal[proposalID].valueSacrificedAgainst+= withTokens;
		if(withAction) { vetoTreasuryTransferProposal(proposalID); }

		emit AddVotes(0, msg.sender, withTokens, false);
	}
    function vetoTreasuryTransferProposal(uint256 proposalID) public {
        require(proposalID != 0, "Invalid proposal ID");
    	require(treasuryProposal[proposalID].valid == true, "Proposal already invalid");
		require(
			treasuryProposal[proposalID].firstCallTimestamp + treasuryProposal[proposalID].delay + IXVMCgovernor(owner()).delayBeforeEnforce() >= block.timestamp,
			"past the point of no return"
		);
    	require(treasuryProposal[proposalID].valueSacrificedForVote < treasuryProposal[proposalID].valueSacrificedAgainst, "needs more votes");

    	treasuryProposal[proposalID].valid = false;

    	emit TreasuryProposalVeto(proposalID, msg.sender);
    }
    /*
    * After delay+delayBeforeEnforce , the proposal effectively passes to be voted through consensus (token voting stops, voting with locked shares starts)
	* Another delayBeforeEnforce period during which users can vote with locked shares
    */
	function approveTreasuryTransfer(uint256 proposalID) public {
		require(proposalID != 0, "invalid proposal ID");
		require(treasuryProposal[proposalID].valid, "Proposal already invalid");
		uint256 consensusID = treasuryProposal[proposalID].consensusProposalID;
		require(
			treasuryProposal[proposalID].firstCallTimestamp + treasuryProposal[proposalID].delay + 2 * IXVMCgovernor(owner()).delayBeforeEnforce() <= block.timestamp,
			"Enough time must pass before enforcing"
		);

		uint256 _totalStaked = totalXVMCStaked();
		if(treasuryProposal[proposalID].valueSacrificedForVote >= treasuryProposal[proposalID].valueSacrificedAgainst) {
			uint256 _castedInFavor = tokensCastedPerVote(consensusID);
			require(
				_castedInFavor >= _totalStaked * 15 / 100,
					"15% weigted vote required to approve the proposal"
			);

			if(tokensCastedPerVote(consensusID+1) >= _castedInFavor * 33 / 100) { //just third of votes voting against kills the treasury withdrawal
				treasuryProposal[proposalID].valid = false;
			} else {
				IXVMCgovernor(owner()).treasuryRequest(
					treasuryProposal[proposalID].tokenAddress, treasuryProposal[proposalID].beneficiary, treasuryProposal[proposalID].amountToSend
				   );
				treasuryProposal[proposalID].valid = false;

				emit TreasuryProposalRequested(proposalID, msg.sender);
			}
		} else {
			treasuryProposal[proposalID].valid = false;

			emit TreasuryProposalVeto(proposalID, msg.sender);
		}
	}

	 /**
     * Kills treasury transfer proposal if more than 10% of weighted vote
     */
	function killTreasuryTransferProposal(uint256 proposalID) external {
		require(!treasuryProposal[proposalID].valid, "Proposal already invalid");
		uint256 consensusID = treasuryProposal[proposalID].consensusProposalID;

        require(
            tokensCastedPerVote(consensusID+1) >= totalXVMCStaked() * 10 / 100,
				"10% weigted vote (voting against) required to kill the proposal"
        );

    	treasuryProposal[proposalID].valid = false;

    	emit TreasuryProposalVeto(proposalID, msg.sender);
	}


    function proposeGovernor(address _newGovernor) external {
        IERC20(token).safeTransferFrom(msg.sender, owner(), IXVMCgovernor(owner()).costToVote() * 100);

		consensusProposal.push(
    	    ConsensusVote(0, _newGovernor, block.timestamp)
    	    );
    	consensusProposal.push(
    	    ConsensusVote(0, _newGovernor, block.timestamp)
    	    ); //even numbers are basically VETO (for voting against)

    	emit ProposeGovernor(consensusProposal.length - 2, _newGovernor, msg.sender);
    }

    /**
     * Atleast 33% of voters required
     * with 75% agreement required to reach consensus
	 * After proposing Governor, a period of time(delayBeforeEnforce) must pass
	 * During this time, the users can vote in favor(proposalID) or against(proposalID+1)
	 * If voting succesfull, it can be submitted
	 * And then there is a period of roughly 6 days(specified in governing contract) before the change can be enforced
	 * During this time, users can still vote and reject change
	 * Unless rejected, governing contract can be updated and changes enforced
     */
    function changeGovernor(uint256 proposalID) external {
		require(block.timestamp >= (consensusProposal[proposalID].timestamp + IXVMCgovernor(owner()).delayBeforeEnforce()), "Must wait delay before enforce");
        require(!(isGovInvalidated[consensusProposal[proposalID].beneficiaryAddress].isInvalidated), " alreadyinvalidated");
		require(consensusProposal.length > proposalID && proposalID % 2 == 1, "invalid proposal ID"); //can't be 0 either, but %2 solves that
        require(!(IXVMCgovernor(owner()).changeGovernorActivated()));
		require(consensusProposal[proposalID].typeOfChange == 0);

        require(
            tokensCastedPerVote(proposalID) >= totalXVMCStaked() * 33 / 100,
				"Requires atleast 33% of staked(weighted) tokens"
        );

        //requires 75% agreement
        if(tokensCastedPerVote(proposalID+1) >= tokensCastedPerVote(proposalID) / 4) {

                isGovInvalidated[consensusProposal[proposalID].beneficiaryAddress].isInvalidated = true;

				emit ChangeGovernor(proposalID, msg.sender, false);

            } else {
                IXVMCgovernor(owner()).setNewGovernor(consensusProposal[proposalID].beneficiaryAddress);

                isGovInvalidated[consensusProposal[proposalID].beneficiaryAddress].hasPassed = true;

                emit ChangeGovernor(proposalID, msg.sender, true);
            }
    }

    /**
     * After approved, still roughly 6 days to cancle the new governor, if less than 75% votes agree
     */
    function vetoGovernor(uint256 proposalID) external {
        require(proposalID % 2 == 1, "Invalid proposal ID");
        require(isGovInvalidated[consensusProposal[proposalID].beneficiaryAddress].hasPassed);

        if(tokensCastedPerVote(proposalID+1) >= tokensCastedPerVote(proposalID) / 4) {
              isGovInvalidated[consensusProposal[proposalID].beneficiaryAddress].isInvalidated = true;
			  emit ChangeGovernor(proposalID, msg.sender, false);
        }
    }
	//even if not approved, can be cancled at any time if 20% of weighted votes go AGAINST
    function vetoGovernor2(uint256 proposalID) external {
        require(proposalID % 2 == 1, "Invalid proposal ID");

        if(tokensCastedPerVote(proposalID+1) >= totalXVMCStaked() * 25 / 100) { //25% of weighted total vote AGAINST kills the proposal as well
              isGovInvalidated[consensusProposal[proposalID].beneficiaryAddress].isInvalidated = true;
			  emit ChangeGovernor(proposalID, msg.sender, false);
        }
    }
    function enforceGovernor(uint256 proposalID) external {
        require(proposalID % 2 == 1, "invalid proposal ID"); //proposal ID = 0 is neutral position and not allowed(%2 applies)
        require(!isGovInvalidated[consensusProposal[proposalID].beneficiaryAddress].isInvalidated, "invalid");

        require(consensusProposal[proposalID].beneficiaryAddress == IXVMCgovernor(owner()).eligibleNewGovernor());

	  	IXVMCgovernor(owner()).enforceGovernor();

        isGovInvalidated[consensusProposal[proposalID].beneficiaryAddress].isInvalidated = true;
    }

    /**
     * Updates pool addresses and token addresses from the governor
     */
    function updatePools() external {
        acPool1 = IXVMCgovernor(owner()).acPool1();
        acPool2 = IXVMCgovernor(owner()).acPool2();
        acPool3 = IXVMCgovernor(owner()).acPool3();
        acPool4 = IXVMCgovernor(owner()).acPool4();
        acPool5 = IXVMCgovernor(owner()).acPool5();
        acPool6 = IXVMCgovernor(owner()).acPool6();
    }

  function setMasterchef() external {
		address _chefo = IMasterChef(token).owner();

        masterchef = _chefo;
    }

    //transfers ownership of this contract to new governor
    //masterchef is the token owner, governor is the owner of masterchef
    function changeGovernor() external {
		_transferOwnership(IToken(token).governor());
    }

    /**
     * Returns total XVMC staked accross all pools.
     */
    function totalXVMCStaked() public view returns(uint256) {
    	return IERC20(token).balanceOf(acPool1) + IERC20(token).balanceOf(acPool2) + IERC20(token).balanceOf(acPool3) +
                 IERC20(token).balanceOf(acPool4) + IERC20(token).balanceOf(acPool5) + IERC20(token).balanceOf(acPool6);
    }

    /**
     * Gets XVMC allocated per vote with ID for each pool
     * Process:
     * Gets votes for ID and calculates XVMC equivalent
     * ...and assigns weights to votes
     * Pool1(20%), Pool2(30%), Pool3(50%), Pool4(75%), Pool5(115%), Pool6(150%)
     */
    function tokensCastedPerVote(uint256 _forID) public view returns(uint256) {
        return (
            IacPool(acPool1).totalVotesForID(_forID) * IacPool(acPool1).getPricePerFullShare() / 1e19 * 2 +
                IacPool(acPool2).totalVotesForID(_forID) * IacPool(acPool2).getPricePerFullShare() / 1e19 * 3 +
                    IacPool(acPool3).totalVotesForID(_forID) * IacPool(acPool3).getPricePerFullShare() / 1e19 * 5 +
                        IacPool(acPool4).totalVotesForID(_forID) * IacPool(acPool4).getPricePerFullShare() / 1e20 * 75 +
                            IacPool(acPool5).totalVotesForID(_forID) * IacPool(acPool5).getPricePerFullShare() / 1e20 * 115 +
                                IacPool(acPool6).totalVotesForID(_forID) * IacPool(acPool6).getPricePerFullShare() / 1e19 * 15
        );
    }
}
