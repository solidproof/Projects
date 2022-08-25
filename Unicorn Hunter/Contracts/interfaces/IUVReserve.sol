// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IUVReserve {
    function initialize(uint8 _orderNumber, address _poolStake) external;

    function sellToken(
        uint256 _amountIn,
        uint256 _amountOutMin,
        address[] calldata _path,
        uint256 _deadline
    ) external;

    function sellNativeToken(
        uint256 _amountIn,
        uint256 _amountMinOut,
        address[] calldata _path,
        uint256 _deadline
    ) external;

    function transferTokenToTPPool(address token, uint256 amount) external;

    function getPoolReserve() external view returns (address);

    function addManager(address _manager) external;

    function removeManager(address _manager) external;
}
