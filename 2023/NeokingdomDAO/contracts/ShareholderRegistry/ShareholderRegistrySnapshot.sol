// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.1 (token/ERC20/extensions/ERC20Snapshot.sol)

pragma solidity ^0.8.16;

import "./ShareholderRegistryBase.sol";
import "../extensions/Snapshottable.sol";

abstract contract ShareholderRegistrySnapshot is
    ShareholderRegistryBase,
    Snapshottable
{
    struct TotalSupplySnapshots {
        uint256[] ids;
        uint256[] values;
    }

    TotalSupplySnapshots internal _totalSupplySnapshots;

    struct StatusAndBalance {
        bytes32 status;
        uint256 balance;
    }

    struct StatusAndBalanceSnapshots {
        uint256[] ids;
        StatusAndBalance[] values;
    }

    mapping(address => StatusAndBalanceSnapshots)
        internal _accountStatusAndBalanceSnapshots;

    /**
     * @dev Retrieves the total supply at the time `snapshotId` was created.
     */
    function totalSupplyAt(
        uint256 snapshotId
    ) public view virtual returns (uint256) {
        (bool snapshotted, uint256 index) = _indexAt(
            snapshotId,
            _totalSupplySnapshots.ids
        );

        return
            snapshotted ? _totalSupplySnapshots.values[index] : totalSupply();
    }

    /**
     * @dev Retrieves the balance of `account` at the time `snapshotId` was created.
     */
    function balanceOfAt(
        address account,
        uint256 snapshotId
    ) public view virtual returns (uint256 balance) {
        (balance, ) = getBalanceAndStatusAt(account, snapshotId);
        return balance;
    }

    function getStatusAt(
        address account,
        uint256 snapshotId
    ) public view virtual returns (bytes32 status) {
        (, status) = getBalanceAndStatusAt(account, snapshotId);
        return status;
    }

    function getBalanceAndStatusAt(
        address account,
        uint256 snapshotId
    ) public view virtual returns (uint256, bytes32) {
        StatusAndBalanceSnapshots
            storage snapshots = _accountStatusAndBalanceSnapshots[account];
        (bool snapshotted, uint256 index) = _indexAt(snapshotId, snapshots.ids);

        return
            snapshotted
                ? (
                    snapshots.values[index].balance,
                    snapshots.values[index].status
                )
                : (balanceOf(account), getStatus(account));
    }

    function isAtLeastAt(
        bytes32 status,
        address account,
        uint256 snapshotId
    ) public view virtual returns (bool) {
        (uint256 balanceAt, bytes32 statusAt) = getBalanceAndStatusAt(
            account,
            snapshotId
        );
        return _isAtLeast(balanceAt, statusAt, status);
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

    function _updateAccountSnapshot(address account) internal virtual {
        uint256 currentId = getCurrentSnapshotId();
        StatusAndBalanceSnapshots
            storage snapshots = _accountStatusAndBalanceSnapshots[account];
        if (_lastSnapshotId(snapshots.ids) < currentId) {
            snapshots.ids.push(currentId);
            snapshots.values.push(
                StatusAndBalance(getStatus(account), balanceOf(account))
            );
        }
    }

    function _updateTotalSupplySnapshot() internal virtual {
        uint256 currentId = getCurrentSnapshotId();
        TotalSupplySnapshots storage snapshots = _totalSupplySnapshots;
        if (_lastSnapshotId(snapshots.ids) < currentId) {
            snapshots.ids.push(currentId);
            snapshots.values.push(totalSupply());
        }
    }

    function _beforeSetStatus(
        address account,
        bytes32 statusBefore,
        bytes32 statusAfter
    ) internal virtual override {
        _updateAccountSnapshot(account);
        super._beforeSetStatus(account, statusBefore, statusAfter);
    }
}
