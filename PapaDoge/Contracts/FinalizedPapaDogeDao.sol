//SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./FinalizedPapaDoge.sol";
import "@openzeppelin/contracts/access/Ownable.sol"; 

// ************************************************************************//
// This DAO allows voters to stake their PAPA while still recieving reward //
// reflections.  User's stake PAPA to receive weigted voting rights to     //
// vote on the next batch of reward tokens and their distribution rankings.//
// ************************************************************************//


contract PapaStake is Ownable {

    IBEP20 public PAPA;
    PapaDogeDAO public papadogeDAO;

    uint public stakerCount;

    //min staking time
    uint stakingPeriod = 90 days; //12 weeks;

    //Vote Weights
    uint public L1 = 1;     //5  - 10 million staked.
    uint public L2 = 10;    //10 - 50 million staked.
    uint public L3 = 50;    //50 - 250 million staked.
    uint public L4 = 100;   //250 - 500 million staked.
    uint public L5 = 400;   //500 million - 2 billion staked.
    uint public L6 = 1000;  //2 billion staked.

    //mapping(address => uint) public voteWeight;

    constructor(address _papaAddress, address _papadogeDAO) {
        PAPA = IBEP20(_papaAddress);
        papadogeDAO = PapaDogeDAO(_papadogeDAO);
        transferOwnership(0x65F7dbC2082A9571f3d49bC27975Ce6F26B60eb7); //Master Wallet
    }

    struct Staker {
        uint amountStaked;
        uint startTime;
        uint endTime;
    }
    
    mapping(address => Staker) public stakers;
    mapping(address => uint) public votes;

    //Stake to get governing rights.
    function stake(uint amount) public {
        require(amount >= 5000000000000000); // 5 million required to become staker.
        //PAPA.approve(address(PAPA), amount);
        PAPA.transferFrom(msg.sender, address(this), amount);
        stakers[msg.sender].amountStaked += amount;
        stakers[msg.sender].startTime = block.timestamp;
        stakers[msg.sender].endTime = block.timestamp + stakingPeriod;
        votes[msg.sender] += 1;
        if(stakers[msg.sender].amountStaked - amount == 0) {
            stakerCount += 1;
        } 
    }
    
    //Receive staked PAPA after the staker has passed the staking endTime.
    function unStake() public {
        require(block.timestamp > stakers[msg.sender].endTime, "You cannot unstake yet.");

        //get total balance of PAPA on this contract and divide by 
        //staker's staked balance to get the ration for reward token allocations.
        uint totalshareheld = getPAPABalance();
        uint userSharePercent = stakers[msg.sender].amountStaked / totalshareheld;
        IBEP20 refToken1 = papadogeDAO.getTok1();
        IBEP20 refToken2 = papadogeDAO.getTok2();
        IBEP20 refToken3 = papadogeDAO.getTok3();
        uint totalshareTok1 = getBalance();
        uint totalshareTok2 = getBalance2();
        uint totalshareTok3 = getBalance3();
        uint userOwed1 = userSharePercent * totalshareTok1;
        uint userOwed2 = userSharePercent * totalshareTok2;
        uint userOwed3 = userSharePercent * totalshareTok3;

        //transfer all associated tokens.
        PAPA.transfer(msg.sender, stakers[msg.sender].amountStaked);
        refToken1.transfer(msg.sender, userOwed1); //DOGE
        refToken2.transfer(msg.sender, userOwed2); //BABYDOGE
        refToken3.transfer(msg.sender, userOwed3); //FLOKI
        stakers[msg.sender].amountStaked = 0; 
        stakerCount -= 1;
    }


    //check voter eligibility
    function hasVotes(address staker) external view returns(bool) {
        if(votes[staker] > 0) {
            return true;
        } else {
            return false; 
        }
    }

    //Calculation for vote weight based on total stake.
    function getVoteWeight(address addr) external view returns(uint) {
        if(stakers[addr].amountStaked < 5000000000000000) {
            return 0;
        } else if(stakers[addr].amountStaked >= 5000000000000000 && stakers[addr].amountStaked < 10000000000000000) {
            return L1; //1 vote
        } else if(stakers[addr].amountStaked >= 10000000000000000 && stakers[addr].amountStaked < 50000000000000000) {
            return L2; //10 votes
        } else if(stakers[addr].amountStaked >= 50000000000000000 && stakers[addr].amountStaked < 250000000000000000) {
            return L3; //50 votes
        } else if(stakers[addr].amountStaked >= 250000000000000000 && stakers[addr].amountStaked < 500000000000000000) {
            return L4; //100 votes
        } else if(stakers[addr].amountStaked >= 500000000000000000 && stakers[addr].amountStaked < 2000000000000000000) {
            return L5; //400 votes
        } else if(stakers[addr].amountStaked >= 2000000000000000000) {
            return L6; //1000 votes
        } 
    }

    //get reward tokens held by DAO
    function getBalance() public view returns(uint) {
        IBEP20 refToken1 = papadogeDAO.getTok1();
        return refToken1.balanceOf(address(this)); 
    }
    function getBalance2() public view returns(uint) {
        IBEP20 refToken2 = papadogeDAO.getTok2();
        return refToken2.balanceOf(address(this)); 
    }
    function getBalance3() public view returns(uint) {
        IBEP20 refToken3 = papadogeDAO.getTok3();
        return refToken3.balanceOf(address(this)); 
    }

    function getPAPABalance() public view returns(uint) {
        return PAPA.balanceOf(address(this));
    }

    function setVoteCount(address addr) external {
        require(msg.sender == address(papadogeDAO));
        votes[addr] -= 1;
    }

    function setStakeSettings(uint timePeriodDays) public onlyOwner {
        stakingPeriod = timePeriodDays * 1 days; 
    }


}

contract PapaDogeDAO is Ownable {

    //Dispatch functions for front-end and Distributors in PapaDoge contracts.
    function getTok1() public view returns(IBEP20) {
        return refToken1;
    }
    function getTok2() public view returns(IBEP20) {
        return refToken2;
    }
    function getTok3() public view returns(IBEP20) {
        return refToken3;
    }

    //References to the reflection tokens.  
    IBEP20 public refToken1; //Distributor1
    IBEP20 public refToken2; //Distributor2
    IBEP20 public refToken3; //Distributor3

    IBEP20 public PAPA;
    PapaStake public papaStake;

    function getPapaStake() public view returns(address) {
        return address(papaStake);
    }

    event VoteResults(address winner, address runnerUp, address loser);

    ///tracks the current vote status.
    bool public voteInProgress;
    uint public counter;
    uint public voteEnd;

    //track individual voter status for the current vote.
    mapping(uint => mapping(address => bool)) public voted;

    constructor(address _papaAddress) {
        counter = 1;
        PAPA = IBEP20(_papaAddress);
        papaStake = new PapaStake(_papaAddress, address(this));

       // PapaDoge papadoge = PapaDoge(_papaAddress);
        refToken1 = IBEP20(0xba2ae424d960c26247dd6c32edc70b295c744c43); //DOGE     0xba2ae424d960c26247dd6c32edc70b295c744c43
        refToken2 = IBEP20(0xc748673057861a797275CD8A068AbB95A902e8de); //BABYDOGE 0xc748673057861a797275cd8a068abb95a902e8de
        refToken3 = IBEP20(0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7); //FLOKI    0x2b3f34e9d4b127797ce6244ea341a83733ddd6e4
        transferOwnership(0x65F7dbC2082A9571f3d49bC27975Ce6F26B60eb7);  //Transfer ownership to the Master Wallet
       // papadoge.authorize(papadoge.owner());
    }

    //Vote data
    struct TokenCandidates {
        address token1;
        address token2;
        address token3;
        uint token1count;
        uint token2count;
        uint token3count;
        uint id;
    }

    mapping(uint => TokenCandidates) public candidates;

    //choose 3 candidates for a vote and set the time frame.
    //@@ add time period.
    function openTokenVote(address _token1, address _token2, address _token3, uint _days) public onlyOwner {
        require(voteInProgress == false, "Vote in progress.");

        //3 choices to vote for
        candidates[counter].token1 = _token1;
        candidates[counter].token2 = _token2;
        candidates[counter].token3 = _token3;
        candidates[counter].id = counter;

        //vote has a variable time limit
        voteEnd = block.timestamp + (_days * 1 days); 
        //only one vote at a time
        voteInProgress = true; 
    }

    //Choose from 3 tokens, tallies will rank which ones get the higher percentages for PAPA distribution.
    //address _token1(1), address _token2(2), address _token3(3).
    //1 vote per staker, multiplied by their Vote Weight class (calculated by amount PAPA staked).
    function vote(uint _choice) public { 
        require(papaStake.hasVotes(msg.sender) == true && voted[counter][msg.sender] == false, "You are not allowed."); //voter is eligible
        require(voteInProgress == true && block.timestamp <= voteEnd, "No voting now."); //vote is still going
        require(_choice > 0 && _choice <= 3, "Choose from the list."); //choices 1-3
        uint voteWeight = papaStake.getVoteWeight(msg.sender);
        if(_choice == 1) {
            candidates[counter].token1count += (1 * voteWeight);
        }else if(_choice == 2) {
            candidates[counter].token2count += (1 * voteWeight);
        }else if(_choice == 3) {
            candidates[counter].token3count += (1 * voteWeight);
         }
        voted[counter][msg.sender] = true; //staker can only vote once
        papaStake.setVoteCount(msg.sender);  //staker used 1 of total eligible votes
    }

    //get voting results
    function tallyUp() public view returns(address, address, address) {
        address winner = tallyVoteWinner();
        address runnerUp = tallyRunnerUp();
        address loser = tallyVoteLoser();
        return(winner, runnerUp, loser);
    }

    function tallyVoteWinner() public view returns(address) {
        uint token1 = candidates[counter].token1count;
        uint token2 = candidates[counter].token2count;
        uint token3 = candidates[counter].token3count;
        if(token1 > token2 && token1 > token3) {
            return candidates[counter].token1;
        } else if(token2 > token1 && token2 > token3) {
            return candidates[counter].token2;
        } else if(token3 > token1 && token3 > token2) {
            return candidates[counter].token3; 
        }
    }

    function tallyVoteLoser() public view returns(address) {
        uint token1 = candidates[counter].token1count;
        uint token2 = candidates[counter].token2count;
        uint token3 = candidates[counter].token3count;
        if(token1 < token2 && token1 < token3) {
            return candidates[counter].token1;
        } else if(token2 < token1 && token2 < token3) {
            return candidates[counter].token2;
        } else if(token3 < token1 && token3 < token2) { 
            return candidates[counter].token3; 
        }
    }

    function tallyRunnerUp() public view returns(address) {
        uint token1 = candidates[counter].token1count;
        uint token2 = candidates[counter].token2count;
        uint token3 = candidates[counter].token3count;
        if(token1 < token2 && token1 > token3 || token1 > token2 && token1 < token3) {
            return candidates[counter].token1;
        } else if(token2 < token1 && token2 > token3 || token2 > token1 && token2 < token3) {
            return candidates[counter].token2;
        } else if(token3 < token1 && token3 > token2 || token3 > token1 && token3 < token2) { 
            return candidates[counter].token3; 
        }
    }

    //Calculate vote results and change reward tokens
    function execute() public onlyOwner {
        require(block.timestamp > voteEnd, "Vote is not over.");
        require(voteInProgress = true, "No vote to execute.");
        
        //get results and rank them for Reward tokens allocation.
        address winner = tallyVoteWinner();
        address loser = tallyVoteLoser();
        address runnerUp = tallyRunnerUp();
        refToken1 = IBEP20(winner);
        refToken2 = IBEP20(runnerUp);
        refToken3 = IBEP20(loser);

        //end the vote and increases the ID for the next vote .
        //(No need to reset individual voting rights for the past ID).
        voteInProgress = false;
        counter++;
        emit VoteResults(winner, runnerUp, loser);
    } 

    //Set reward tokens manually.
    function emergencySetTokens(address token1, address token2, address token3) public onlyOwner {
        refToken1 = IBEP20(token1);
        refToken2 = IBEP20(token2);
        refToken3 = IBEP20(token3);
    } 

}

