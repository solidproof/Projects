// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

interface IConfigurable {
    function hasRole(bytes32 role, address account) external view returns (bool);

    function getConfig(bytes32 configKey) external view returns (bytes32);

    function setConfig(bytes32 configKey, bytes32 value) external;
}
