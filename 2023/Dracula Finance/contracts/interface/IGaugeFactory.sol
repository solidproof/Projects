// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

interface IGaugeFactory {
    function createGauge(
        address _pool,
        address _bribe,
        address _ve,
        address[] memory _allowedRewardTokens
    ) external returns (address);

    function createGaugeSingle(
        address _pool,
        address _bribe,
        address _ve,
        address _voter,
        address[] memory _allowedRewardTokens
    ) external returns (address);
}
