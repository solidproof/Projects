// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

interface ISeniorVault {
    enum LockType {
        None,
        SoftLock,
        HardLock
    }

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function assetDecimals() external view returns (uint8);

    function getConfig(bytes32 configKey) external view returns (bytes32);

    function setConfig(bytes32 configKey, bytes32 value) external;

    function asset() external view returns (address);

    function depositToken() external view returns (address);

    function totalAssets() external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function borrowable(address receiver) external view returns (uint256 assets);

    function balanceOf(address account) external view returns (uint256);

    function borrows(address account) external view returns (uint256);

    function totalBorrows() external view returns (uint256);

    function convertToShares(uint256 assets) external view returns (uint256 shares);

    function convertToAssets(uint256 shares) external view returns (uint256 assets);

    function lockStatus(address owner) external view returns (LockType lockType, bool isLocked);

    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    function withdraw(
        address caller,
        address owner,
        uint256 shares,
        address receiver
    ) external returns (uint256 assets);

    function borrow(uint256 assets) external;

    function repay(uint256 assets) external;
}
