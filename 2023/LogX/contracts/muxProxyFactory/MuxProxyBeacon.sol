// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.19;

import "../../lib/openzeppelin-contracts/contracts/proxy/beacon/IBeacon.sol";
import "../../lib/openzeppelin-contracts/contracts/proxy/beacon/BeaconProxy.sol";

import "./MuxStorage.sol";

contract MuxProxyBeacon is  MuxStorage, IBeacon{
    event Upgraded(uint256 exchangeId, address indexed implementation);
    event CreateProxy(
        uint256 exchangeId,
        bytes32 proxyId,
        address owner,
        address proxy,
        uint8 assetId,
        uint8 collateralId,
        bool isLong
    );

    function implementation() external view virtual override returns (address) {
        require(_isCreatedProxy(msg.sender), "NotProxy");
        return _implementations[_proxyExchangeIds[msg.sender]];
    }

    function _isCreatedProxy(address proxy_) internal view returns (bool) {
        return _proxyExchangeIds[proxy_] != 0;
    }

    function _setImplementation(uint256 exchangeId, address newImplementation_) internal {
        require(newImplementation_ != address(0), "ZeroImplementationAddress");
        _implementations[exchangeId] = newImplementation_;
    }

    function _upgradeTo(uint256 exchangeId, address newImplementation_) internal virtual {
        _setImplementation(exchangeId, newImplementation_);
        emit Upgraded(exchangeId, newImplementation_);
    }

    function _createProxy(
        uint256 exchangeId,
        bytes32 proxyId,
        bytes memory bytecode
    ) internal returns (address proxy) {
        proxy = _getAddress(bytecode, proxyId);
        _proxyExchangeIds[proxy] = exchangeId; // IMPORTANT
        assembly {
            proxy := create2(0x0, add(0x20, bytecode), mload(bytecode), proxyId)
        }
        require(proxy != address(0), "CreateFailed");
    }

    function _createBeaconProxy(
        uint256 exchangeId,
        address account,
        address collateralToken,
        uint8 assetId,
        uint8 collateralId,
        bool isLong
    ) internal returns (address) {
        bytes32 proxyId = _makeProxyId(exchangeId, account, collateralToken, collateralId, assetId, isLong);
        require(_tradingProxies[proxyId] == address(0), "AlreadyCreated");
        bytes memory initData = abi.encodeWithSignature(
            "initialize(uint256,address,address,uint8,uint8,bool)",
            exchangeId,
            account,
            collateralToken,
            collateralId,
            assetId,
            isLong
        );
        bytes memory bytecode = abi.encodePacked(type(BeaconProxy).creationCode, abi.encode(address(this), initData));
        address proxy = _createProxy(exchangeId, proxyId, bytecode);
        _tradingProxies[proxyId] = proxy;
        _ownedProxies[account].push(proxy);
        emit CreateProxy(exchangeId, proxyId, account, proxy, assetId, collateralId, isLong);
        return proxy;
    }

    function _getAddress(bytes memory bytecode, bytes32 proxyId) internal view returns (address) {
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), address(this), proxyId, keccak256(bytecode)));
        return address(uint160(uint256(hash)));
    }

    function _makeProxyId(
        uint256 exchangeId_,
        address account_,
        address collateralToken,
        uint8 collateralId_,
        uint8 assetId_,
        bool isLong_
    ) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(exchangeId_, account_, collateralToken,collateralId_, assetId_, isLong_));
    }
}