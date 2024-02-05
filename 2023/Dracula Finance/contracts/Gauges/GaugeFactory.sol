// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "../interface/IGaugeFactory.sol";
import "./Gauge.sol";

contract GaugeFactory is IGaugeFactory {
    address public lastGauge;

    event GaugeCreated(address value);

    function createGauge(
        address _pool,
        address _bribe,
        address _ve,
        address[] memory _allowedRewardTokens
    ) external override returns (address) {
        address _lastGauge = address(
            new Gauge(_pool, _bribe, _ve, msg.sender, _allowedRewardTokens)
        );
        lastGauge = _lastGauge;
        emit GaugeCreated(_lastGauge);
        return _lastGauge;
    }

    function createGaugeSingle(
        address _pool,
        address _bribe,
        address _ve,
        address _voter,
        address[] memory _allowedRewardTokens
    ) external override returns (address) {
        address _lastGauge = address(
            new Gauge(_pool, _bribe, _ve, _voter, _allowedRewardTokens)
        );
        lastGauge = _lastGauge;
        emit GaugeCreated(_lastGauge);
        return _lastGauge;
    }
}
