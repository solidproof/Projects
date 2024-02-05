//SPDX-License-Identifier: LicenseRef-LICENSE
pragma solidity ^0.8.0;

import "./../RoleManager/IRoleManager.sol";
import "./../ContractsManager/IContractsManager.sol";

import "./../IDOFactory/IIDOFactory.sol";

import "./../IDODetails/IIDODetails.sol";
import "./../Constants.sol";
import "./../IDOStates.sol";

import "./../StakingManager/IStakingManager.sol";
import "./VotingManagerStorage.sol";

import "./../FundingManager/IFundingManager.sol";

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";


contract VotingManager is Initializable {
    IContractsManager contractsManager;

    mapping (uint => VotingManagerStorage.VoteRecord) public voteLedger;
    mapping (uint => mapping (address => bool)) votes;

    function initialize(address _contractsManager) public initializer {
        contractsManager = IContractsManager(_contractsManager);
    }

    modifier onlyIDOManager() {
        IRoleManager roleManager = IRoleManager(contractsManager.roleManager());
        require(roleManager.isIDOManager(msg.sender), 'VotingManager: Only IDO Managers allowed');
        _;
    }

    modifier onlyIDOOwner(uint _idoId) {
        IIDOFactory idoFactory = IIDOFactory(contractsManager.idoFactory());
        IIDODetails idoDetails = IIDODetails(idoFactory.idoIdToIDODetailsContract(_idoId));
        require(idoDetails.ownerAddress() == msg.sender, 'VotingManager: Only IDO Owner allowed');
        _;
    }

    function addForVoting(uint _idoId) public onlyIDOOwner(_idoId) {
        IIDOFactory idoFactory = IIDOFactory(contractsManager.idoFactory());
        IIDODetails idoDetails = IIDODetails(idoFactory.idoIdToIDODetailsContract(_idoId));

        require(idoDetails.votingDetails().voteStartTime <= block.timestamp, 'VotingManager: Voting can only start at or after voting start time');
        require(idoDetails.votingDetails().voteEndTime >= block.timestamp + Constants.HOUR * 5, 'VotingManager: Voting can only start at-least 5 hour before end time');
        idoDetails.updateState(IDOStates.IDOState.IN_VOTING);

        VotingManagerStorage.VoteRecord storage voteRecord = voteLedger[_idoId];
        voteRecord.votingStartedAt = idoDetails.votingDetails().voteStartTime >= block.timestamp ? idoDetails.votingDetails().voteStartTime : block.timestamp;
    }

    function vote(uint _idoId, bool _vote) public {
        IIDOFactory idoFactory = IIDOFactory(contractsManager.idoFactory());
        IIDODetails idoDetails = IIDODetails(idoFactory.idoIdToIDODetailsContract(_idoId));

        require(idoDetails.state() == IDOStates.IDOState.IN_VOTING, 'VotingManager: Voting is not available');
        require(idoDetails.votingDetails().voteEndTime >= block.timestamp, 'VotingManager: Voting period is over');

        IStakingManager _stakingManager = IStakingManager(contractsManager.stakingManager());
        uint votingPower = _stakingManager.getVotingPower(msg.sender);

        require(votingPower > 0, 'VotingManager: You cannot vote with 0 voting power.');

        VotingManagerStorage.VoteRecord storage voteRecord = voteLedger[_idoId];

        require(!votes[_idoId][msg.sender], 'VotingManager: You have already voted');

        if (_vote) {
            // Positive Vote
            voteRecord.positiveVoteWeight += votingPower;
            voteRecord.positiveVoteCount++;
        } else {
            // Negative Vote
            voteRecord.negativeVoteWeight += votingPower;
            voteRecord.negativeVoteCount++;
        }

        votes[_idoId][msg.sender] = true;
    }

    function finalizeVotes(uint _idoId) public {
        IFundingManager fundingManager = IFundingManager(contractsManager.fundingManager());

        fundingManager.addForFunding(_idoId);
    }
}
