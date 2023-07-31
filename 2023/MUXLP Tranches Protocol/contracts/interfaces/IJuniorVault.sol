// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

interface IJuniorVault {
    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);

    function assetDecimals() external view returns (uint8);

    function totalSupply() external view returns (uint256);

    function getConfig(bytes32 configKey) external view returns (bytes32);

    function setConfig(bytes32 configKey, bytes32 value) external;

    function asset() external view returns (address assetTokenAddress);

    function depositToken() external view returns (address depositTokenAddress);

    function totalAssets() external view returns (uint256 totalManagedAssets);

    function balanceOf(address owner) external view returns (uint256);

    function leverage(
        uint256 totalBorrows,
        uint256 juniorPrice,
        uint256 seniorPrice
    ) external view returns (uint256);

    function deposit(uint256 assets, address receiver) external returns (uint256 shares);

    function withdraw(
        address caller,
        address owner,
        uint256 shares,
        address receiver
    ) external returns (uint256 assets);

    function collectRewards(address owner) external;

    function adjustVesting() external;

    function transferIn(uint256 assets) external;

    function transferOut(uint256 assets) external;
}
