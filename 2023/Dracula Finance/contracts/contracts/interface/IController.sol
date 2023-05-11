// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

interface IController {
    function governance() external view returns (address);

    function veDist() external view returns (address);

    function voter() external view returns (address);
}
