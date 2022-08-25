// SPDX-License-Identifier: MIT
pragma solidity ^0.8.12;

interface IUVTakeProfit {
    function initialize(
        uint8 _orderNumber,
        address _poolToken,
        address _fundWallet
    ) external;

    function createStakeInfo(
        uint8 _stakeId,
        address _tokenAddress,
        uint256 _amount,
        uint64 _openTime,
        uint64 _closeTime,
        uint8 _feePercent
    ) external;

    // function stakeToken(uint8 _stakeId) external;

    function withdrawToken(uint8 _stakeId) external;

    // function unstakeToken(uint8 _stakeId) external;

    function finishStake() external;

    function addManager(address _manager) external;

    function removeManager(address _manager) external;
}
