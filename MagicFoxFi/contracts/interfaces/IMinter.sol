// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IMinter {
    function update_period() external returns (uint);
    function check() external view returns(bool);
    function period() external view returns(uint);
    function active_period() external view returns(uint);
}
