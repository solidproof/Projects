// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts/utils/Arrays.sol";

abstract contract Snapshottable {
    using Arrays for uint256[];
    event Snapshot(uint256 id);

    uint256 private _currentSnapshotId;

    function snapshot() public virtual returns (uint256);

    function _snapshot() internal returns (uint256) {
        _currentSnapshotId = block.timestamp;
        emit Snapshot(_currentSnapshotId);
        return _currentSnapshotId;
    }

    function getCurrentSnapshotId() public view returns (uint256) {
        return _currentSnapshotId;
    }

    function _indexAt(
        uint256 snapshotId,
        uint256[] storage ids
    ) internal view returns (bool, uint256) {
        require(snapshotId > 0, "Snapshottable: id is 0");
        require(
            snapshotId <= getCurrentSnapshotId(),
            "Snapshottable: nonexistent id"
        );

        uint256 index = ids.findUpperBound(snapshotId);

        if (index == ids.length) {
            return (false, index);
        } else {
            return (true, index);
        }
    }

    function _lastSnapshotId(
        uint256[] storage ids
    ) internal view returns (uint256) {
        if (ids.length == 0) {
            return 0;
        } else {
            return ids[ids.length - 1];
        }
    }
}
