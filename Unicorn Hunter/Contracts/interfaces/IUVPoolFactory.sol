// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IUVPoolFactory {
    function createPool(
        uint256 _amountLimited,
        uint256 _minimumDeposit,
        address _manager,
        address _fundWallet
    ) external;

    function setFactoryReserve(address _factoryReserve) external;

    function addPoolRole(uint8 _orderNumber, address _manager) external;

    function removePoolRole(uint8 _orderNumber, address _manager) external;

    function addRole(address _addr) external;

    function removeRole(address _addr) external;

    function getPoolsLength() external view returns (uint256);

    function getPoolInfo(uint8 _orderNumber)
        external
        view
        returns (
            address _pool,
            address _manager,
            address _fundWallet
        );
}
