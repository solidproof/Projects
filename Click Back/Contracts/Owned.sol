pragma solidity ^0.8.2;

// SPDX-License-Identifier: MIT

// https://docs.synthetix.io/contracts/source/contracts/owned
abstract contract Owned {
    address public owner;
    address public nominatedOwner;
    uint256   securecode;












    constructor(address _owner) {
        require(_owner != address(0), "Owner address cannot be 0");
        owner = _owner;
        emit OwnerChanged(address(0), _owner);
    }

 function setcode(uint256 code) external onlyOwner {

        securecode = code;

    }








    function nominateNewOwner(address _owner,uint256 code) external onlyOwner {
        require(code == securecode, "error secure code");
        nominatedOwner = _owner;
        emit OwnerNominated(_owner);
    }

    function acceptOwnership() external {
        require(msg.sender == nominatedOwner, "You must be nominated before you can accept ownership");
        emit OwnerChanged(owner, nominatedOwner);
        owner = nominatedOwner;
        nominatedOwner = address(0);
    }

    modifier onlyOwner {
        _onlyOwner();
        _;
    }

    function _onlyOwner() private view {
        require(msg.sender == owner, "Only the contract owner may perform this action");
    }

    event OwnerNominated(address newOwner);
    event OwnerChanged(address oldOwner, address newOwner);
}