// SPDX-License-Identifier: MIT
pragma solidity 0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";

// @title address management
// @notice place to store user addresses on other chains for distribution of tokens deployed on those chains
contract AddressManagement is Ownable {
    string[] public chains = [
        "Solana",
        "Cardano",
        "Cosmos",
        "Tezos",
        "Terra",
        "Elrond"
    ];

    mapping(address => mapping(uint256 => string)) public mySubmittedAddress;

    function submitMyAddress(uint256 index, string memory _address) external {
        mySubmittedAddress[msg.sender][index] = _address;
    }

    function addChain(string memory chain) external onlyOwner {
        chains.push(chain);
    }

    function getNumberOfChain() external view returns (uint256) {
        return chains.length;
    }
}
