// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

contract PlaceHolder {
    fallback() external {}

    address public rewardToken;
    uint256 public pendingMlpRewards;
    uint256 public votingEscrowedRate;

    constructor(address rewardToken_) {
        rewardToken = rewardToken_;
    }

    function setVotingEscrowedRate(uint256 rate) external {
        votingEscrowedRate = rate;
    }
}
