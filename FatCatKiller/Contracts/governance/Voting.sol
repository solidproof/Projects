// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "../token/IFCKToken.sol";
import "./IVoting.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract Voting is IVoting, Ownable {
    event ProposalCreated(
        uint256 id,
        address indexed creator,
        address indexed recipient,
        uint256 amount
    );
    event ProposalCompleted(
        uint256 id,
        address indexed creator,
        address indexed recipient,
        uint256 amount,
        bool success
    );

    struct Proposal {
        uint256 id;
        address creator;
        address recipient;
        uint256 amount;
        bool active;
        mapping(uint256 => mapping(address => uint256)) voters;
        uint256 votersCount;
        uint256 tokensFor;
        uint256 tokensAgainst;
        uint256 createdAt;
        uint256 endsAt;
    }

    IFCKToken private _token;

    Proposal public proposal;

    constructor(IFCKToken token_) {
        _token = token_;
    }

    function createProposal(
        address recipient,
        uint256 amount,
        uint256 endsAt
    ) external override onlyOwner {
        require(
            !proposal.active,
            "Voting: Active proposal should be completed"
        );
        require(
            endsAt > block.timestamp + 23 * 1 hours,
            "Voting: Should be active more than 23 hours"
        );
        require(
            _token.allowance(msg.sender, address(this)) >= amount,
            "Voting: Insufficient funds"
        );
        require(recipient != address(0), "Voting: Wrong recipient address");
        proposal.id += 1;
        proposal.creator = msg.sender;
        proposal.recipient = recipient;
        proposal.amount = amount;
        proposal.active = true;
        proposal.createdAt = block.timestamp;
        proposal.endsAt = endsAt;
        proposal.tokensFor = 0;
        proposal.tokensAgainst = 0;
        proposal.votersCount = 0;
        emit ProposalCreated(
            proposal.id,
            proposal.creator,
            proposal.recipient,
            proposal.amount
        );
    }

    function voteFor() external override {
        _vote(msg.sender, true);
    }

    function voteAgainst() external override {
        _vote(msg.sender, false);
    }

    function canTransfer(address sender) external view override returns (bool) {
        return
            !proposal.active ||
            (proposal.active && proposal.voters[proposal.id][sender] == 0);
    }

    function complete() external override onlyOwner {
        require(
            proposal.active && proposal.endsAt <= block.timestamp,
            "Voting: There is no active proposal"
        );
        proposal.active = false;
        bool success = proposal.tokensFor > proposal.tokensAgainst;
        if (success) {
            _token.transferFrom(
                proposal.creator,
                proposal.recipient,
                proposal.amount
            );
        }
        emit ProposalCompleted(
            proposal.id,
            proposal.creator,
            proposal.recipient,
            proposal.amount,
            success
        );
    }

    function _vote(address account_, bool for_) internal {
        require(_token.balanceOf(msg.sender) > 0, "Voting: Insufficient funds");
        require(
            proposal.endsAt >= block.timestamp,
            "Voting: There is no active proposal"
        );
        require(
            proposal.voters[proposal.id][account_] == 0,
            "Voting: This address has already voted"
        );
        proposal.votersCount += 1;
        proposal.voters[proposal.id][account_] = 1;
        uint256 amount = _token.balanceOf(account_);
        if (for_) {
            proposal.tokensFor += amount;
        } else {
            proposal.tokensAgainst += amount;
        }
    }
}
