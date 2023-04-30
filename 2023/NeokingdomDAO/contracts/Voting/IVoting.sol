// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "../extensions/ISnapshot.sol";

interface IVoting is ISnapshot {
    function beforeRemoveContributor(address account) external;

    function afterAddContributor(address account) external;

    function afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) external;

    function getDelegate(address account) external view returns (address);

    function getDelegateAt(
        address account,
        uint256 snapshotId
    ) external view returns (address);

    function canVote(address account) external view returns (bool);

    function canVoteAt(
        address account,
        uint256 snapshotId
    ) external view returns (bool);

    function getVotingPower(address account) external view returns (uint256);

    function getVotingPowerAt(
        address account,
        uint256 snapshotId
    ) external view returns (uint256);

    function getTotalVotingPower() external view returns (uint256);

    function getTotalVotingPowerAt(
        uint256 snapshotId
    ) external view returns (uint256);

    function delegate(address newDelegate) external;

    function delegateFrom(address delegator, address newDelegate) external;
}
