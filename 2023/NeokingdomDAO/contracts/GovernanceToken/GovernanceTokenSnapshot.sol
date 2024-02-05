// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts/utils/Arrays.sol";
import "./IGovernanceToken.sol";
import "./GovernanceTokenBase.sol";
import "../extensions/Snapshottable.sol";

abstract contract GovernanceTokenSnapshot is
    GovernanceTokenBase,
    Snapshottable
{
    using Arrays for uint256[];

    struct Snapshots {
        uint256[] ids;
        uint256[] values;
    }

    mapping(address => Snapshots) internal _accountBalanceSnapshots;
    Snapshots internal _totalSupplySnapshots;

    /**
     * @dev Retrieves the balance of `account` at the time `snapshotId` was created.
     */
    function balanceOfAt(
        address account,
        uint256 snapshotId
    ) public view virtual returns (uint256) {
        (bool snapshotted, uint256 value) = _valueAt(
            snapshotId,
            _accountBalanceSnapshots[account]
        );

        return snapshotted ? value : balanceOf(account);
    }

    /**
     * @dev Retrieves the total supply at the time `snapshotId` was created.
     */
    function totalSupplyAt(
        uint256 snapshotId
    ) public view virtual returns (uint256) {
        (bool snapshotted, uint256 value) = _valueAt(
            snapshotId,
            _totalSupplySnapshots
        );

        return snapshotted ? value : totalSupply();
    }

    // Update balance and/or total supply snapshots before the values are modified. This is implemented
    // in the _beforeTokenTransfer hook, which is executed for _mint, _burn, and _transfer operations.
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);

        if (from == address(0)) {
            // mint
            _updateAccountSnapshot(to);
            _updateTotalSupplySnapshot();
        } else if (to == address(0)) {
            // burn
            _updateAccountSnapshot(from);
            _updateTotalSupplySnapshot();
        } else {
            // transfer
            _updateAccountSnapshot(from);
            _updateAccountSnapshot(to);
        }
    }

    function _valueAt(
        uint256 snapshotId,
        Snapshots storage snapshots
    ) internal view virtual returns (bool snapshotted, uint256 value) {
        uint256 index;
        (snapshotted, index) = _indexAt(snapshotId, snapshots.ids);

        if (snapshotted) {
            value = snapshots.values[index];
        }
    }

    function _updateAccountSnapshot(address account) internal virtual {
        _updateSnapshot(_accountBalanceSnapshots[account], balanceOf(account));
    }

    function _updateTotalSupplySnapshot() internal virtual {
        _updateSnapshot(_totalSupplySnapshots, totalSupply());
    }

    function _updateSnapshot(
        Snapshots storage snapshots,
        uint256 currentValue
    ) internal virtual {
        uint256 currentId = getCurrentSnapshotId();
        if (_lastSnapshotId(snapshots.ids) < currentId) {
            snapshots.ids.push(currentId);
            snapshots.values.push(currentValue);
        }
    }

    function snapshot()
        public
        virtual
        override(ISnapshot, Snapshottable)
        returns (uint256);
}
