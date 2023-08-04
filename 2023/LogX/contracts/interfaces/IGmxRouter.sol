// SPDX-License-Identifier: MIT

pragma solidity 0.8.19;

interface IGmxRouter {
    function approvedPlugins(address, address) external view returns (bool);

    function approvePlugin(address _plugin) external;

    function denyPlugin(address _plugin) external;
}