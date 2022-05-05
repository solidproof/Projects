//SPDX-License-Identifier: LicenseRef-LICENSE
pragma solidity ^0.8.0;

library VotingManagerStorage {
    struct VoteRecord {
        uint votingStartedAt; // for in case vote started after the vote start time, in that case to calculate head start

        uint positiveVoteWeight;
        uint positiveVoteCount;

        uint negativeVoteWeight;
        uint negativeVoteCount;
    }
}
