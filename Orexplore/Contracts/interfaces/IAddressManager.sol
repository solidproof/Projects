//SPDX-License-Identifier: SimPL-2.0
pragma solidity ^0.8.9;

interface IAddressManager {
    function setAddress(string calldata key, address addr) external;

    function getAddress(string calldata key) external view returns (address);

    function getAddressPayable(string calldata key) external view returns (address payable);
}
