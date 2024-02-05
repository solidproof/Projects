// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import "../../../lib/openzeppelin-contracts-upgradeable/contracts/proxy/utils/Initializable.sol";
import "../../../lib/openzeppelin-contracts-upgradeable/contracts/utils/structs/EnumerableSetUpgradeable.sol";
import "../../../lib/openzeppelin-contracts-upgradeable/contracts/utils/structs/EnumerableMapUpgradeable.sol";

import "./Types.sol";

contract Storage is Initializable {
    uint256 internal constant EXCHANGE_ID = 1;

    uint32 internal _localexchangeVersion;
    mapping(address => uint32) _localAssetVersions;

    address internal _factory;
    bytes32 internal _gmxPositionKey;

    ExchangeConfigs internal _exchangeConfigs;

    AccountState internal _account;
    EnumerableSetUpgradeable.Bytes32Set internal _pendingOrders;
    EnumerableMapUpgradeable.Bytes32ToBytes32Map internal _openTpslOrderIndexes;
    EnumerableSetUpgradeable.Bytes32Set internal _closeTpslOrderIndexes;


    //ToDo - Do we need these gaps?
    //bytes32[50] private __gaps;

    //Position Market order constant flag
    uint8 constant POSITION_MARKET_ORDER = 0x40;
    uint8 constant POSITION_TPSL_ORDER = 0x08;
}