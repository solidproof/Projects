pragma solidity ^0.8.14;

// SPDX-License-Identifier: MIT

interface IDarwinCommunity {

    enum ProposalState {
        Pending,
        Active,
        Canceled,
        Defeated,
        Queued,
        Expired,
        Executed
    }

    /// @notice Ballot receipt record for a voter
    struct Receipt {
        bool hasVoted;
        bool inSupport;
        uint256 darwinAmount;
    }

    struct Proposal {
        uint256 id;
        address proposer;
        address[] targets;
        uint256[] values;
        string[] signatures;
        bytes[] calldatas;
        uint256 darwinAmount;
        uint256 startTime;
        uint256 endTime;
        uint256 forVotes;
        uint256 againstVotes;
        bool canceled;
        bool executed;
    }

    struct CommunityFundCandidate {
        uint256 id;
        address valueAddress;
        bool isActive;
    }

    struct LockInfo {
        uint darwinAmount;
        uint lockEnd;
    }

    /// @notice An event emitted when a vote has been cast on a proposal
    event VoteCast(address indexed voter, uint256 indexed proposalId, bool inSupport);
    /// @notice An event emitted when a proposal has been canceled
    event ProposalCanceled(uint256 indexed id);
    /// @notice An event emitted when a proposal has been executed
    event ProposalExecuted(uint256 indexed id);
    /// @notice An event emitted when a user withdraws the StakedDarwin they previously locked in to cast votes
    event Withdraw(address indexed user, uint256 indexed darwinAmount);
    event ActiveFundCandidateRemoved(uint256 indexed id);
    event ActiveFundCandidateAdded(uint256 indexed id);
    event NewFundCandidate(uint256 indexed id, address valueAddress, string proposal);
    event FundCandidateDeactivated(uint256 indexed id);
    event ProposalCreated(
        uint256 indexed id,
        address indexed proposer,
        uint256 startTime,
        uint256 endTime,
        string title,
        string description,
        string other
    );
    event ExecuteTransaction(
        uint256 indexed id,
        bytes32 indexed txHash,
        address indexed target,
        uint256 value,
        string signature,
        bytes data
    );
    event CommunityFundDistributed(uint256 fundWeek, uint256[] candidates, uint256[] tokens);

    function setDarwinAddress(address account) external;
    function lockedStakedDarwin(uint proposalId, address user) external returns (LockInfo memory);
}
