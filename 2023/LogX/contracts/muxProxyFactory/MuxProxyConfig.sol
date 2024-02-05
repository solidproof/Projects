// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import "./MuxStorage.sol";

contract MuxProxyConfig is MuxStorage{

    event SetExchangeConfig(uint256 ExchangeId, uint256[] values, uint256 version);

    function _getLatestVersions(uint256 ExchangeId)
        internal
        view
        returns (uint32 ExchangeConfigVersion)
    {
        ExchangeConfigVersion = _exchangeConfigs[ExchangeId].version;
    }

    function _setExchangeConfig(uint256 ExchangeId, uint256[] memory values) internal {
        _exchangeConfigs[ExchangeId].values = values;
        _exchangeConfigs[ExchangeId].version += 1;
        emit SetExchangeConfig(ExchangeId, values, _exchangeConfigs[ExchangeId].version);
    }
}