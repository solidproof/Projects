// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IVoting {
    function createProposal(
        address recipient,
        uint256 amount,
        uint256 endsAt
    ) external;

    function voteFor() external;

    function voteAgainst() external;

    function canTransfer(address sender) external view returns (bool);

    function complete() external;
}
