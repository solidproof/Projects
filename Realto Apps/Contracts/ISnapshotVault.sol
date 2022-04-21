// SPDX-License-Identifier: GPL-3.0

pragma solidity >=0.7.0 <0.9.0;

interface ISnapshotVault {
    /**
     * @notice Vault snapshot `cashflowTokenAddress` transfer `amount` from `from`
     * @dev Creates a new snapshot. Transfers cashflow token to vault.
     * @param cashflowTokenAddress Cashflow token distributed to shareholders for the snapshot (eg. USDC)
     * @param amount amount of cashflow tokens to transfer
     */
    function snapshot(address cashflowTokenAddress, uint256 amount) external;

    /**
     * @dev Get cashflows token for `snapshotId`.
     */
    function snapshotTokenAt(uint256 snapshotId) external view returns (address);

    /**
     * @dev Get cashflows amount for `snapshotId`.
     */
    function snapshotAmountAt(uint256 snapshotId) external view returns (uint256);

    /**
     * @dev Get withdrawn cashflows for `from` at `snapshotId`.
     */
    function withdrawnOfAt(address from, uint256 snapshotId) external view returns (uint256);

    /**
     * @dev Get withdrawable cashflows for `from` at `snapshotId`.
     */
    function withdrawableOfAt(address from, uint256 snapshotId) external view returns (uint256);

    /**
     * @dev Withdraw `amount` cashflows at `snapshotId`.
     */
    function withdraw(uint256 snapshotId, uint256 amount) external;
}