// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IMinter {
    function active_period() external view returns(uint);
    function update_period() external returns (uint);
}