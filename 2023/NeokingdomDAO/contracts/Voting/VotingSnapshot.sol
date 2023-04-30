// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "@openzeppelin/contracts/utils/Arrays.sol";
import "../extensions/Snapshottable.sol";
import "./VotingBase.sol";

abstract contract VotingSnapshot is VotingBase, Snapshottable {
    using Arrays for uint256[];

    struct SnapshotsDelegates {
        uint256[] ids;
        address[] delegates;
    }

    struct SnapshotsValues {
        uint256[] ids;
        uint256[] values;
    }

    mapping(address => SnapshotsDelegates) internal _delegationSnapshots;
    mapping(address => SnapshotsValues) internal _votingPowerSnapshots;
    SnapshotsValues internal _totalVotingPowerSnapshots;

    function snapshot()
        public
        virtual
        override(Snapshottable, ISnapshot)
        returns (uint256);

    function getDelegateAt(
        address account,
        uint256 snapshotId
    ) public view virtual returns (address) {
        SnapshotsDelegates storage snapshots = _delegationSnapshots[account];
        (bool valid, uint256 index) = _indexAt(snapshotId, snapshots.ids);

        return valid ? snapshots.delegates[index] : getDelegate(account);
    }

    function canVoteAt(
        address account,
        uint256 snapshotId
    ) public view virtual returns (bool) {
        SnapshotsDelegates storage snapshots = _delegationSnapshots[account];
        (bool valid, uint256 index) = _indexAt(snapshotId, snapshots.ids);

        return
            valid ? snapshots.delegates[index] != address(0) : canVote(account);
    }

    function getVotingPowerAt(
        address account,
        uint256 snapshotId
    ) public view virtual returns (uint256) {
        SnapshotsValues storage snapshots = _votingPowerSnapshots[account];
        (bool valid, uint256 index) = _indexAt(snapshotId, snapshots.ids);

        return valid ? snapshots.values[index] : getVotingPower(account);
    }

    function getTotalVotingPowerAt(
        uint256 snapshotId
    ) public view virtual returns (uint256) {
        (bool valid, uint256 index) = _indexAt(
            snapshotId,
            _totalVotingPowerSnapshots.ids
        );

        return
            valid
                ? _totalVotingPowerSnapshots.values[index]
                : getTotalVotingPower();
    }

    /*
     * Snapshots update logic
     */

    function _updateSnaphshotDelegation(
        SnapshotsDelegates storage snapshots,
        address currentDelegate
    ) internal virtual {
        uint256 currentId = getCurrentSnapshotId();
        if (_lastSnapshotId(snapshots.ids) < currentId) {
            snapshots.ids.push(currentId);
            snapshots.delegates.push(currentDelegate);
        }
    }

    function _updateSnaphshotValues(
        SnapshotsValues storage snapshots,
        uint256 currentValue
    ) internal virtual {
        uint256 currentId = getCurrentSnapshotId();
        if (_lastSnapshotId(snapshots.ids) < currentId) {
            snapshots.ids.push(currentId);
            snapshots.values.push(currentValue);
        }
    }

    /*
     * Callbacks
     */

    function _beforeDelegate(address delegator) internal virtual override {
        super._beforeDelegate(delegator);
        _updateSnaphshotDelegation(
            _delegationSnapshots[delegator],
            getDelegate(delegator)
        );
    }

    function _beforeMoveVotingPower(address account) internal virtual override {
        super._beforeMoveVotingPower(account);
        _updateSnaphshotValues(
            _votingPowerSnapshots[account],
            getVotingPower(account)
        );
    }

    function _beforeUpdateTotalVotingPower() internal virtual override {
        super._beforeUpdateTotalVotingPower();
        _updateSnaphshotValues(
            _totalVotingPowerSnapshots,
            getTotalVotingPower()
        );
    }
}
