//SPDX-License-Identifier: LicenseRef-LICENSE
pragma solidity ^0.8.0;

import "./VotingManagerStorage.sol";

interface IVotingManager {
    function voteLedger(uint _idoId) external returns (VotingManagerStorage.VoteRecord memory);

    function addForVoting(uint _idoId) external;

    function vote(uint _idoId, bool _vote) external;

    function finalizeVotes(uint _idoId) external;
}
