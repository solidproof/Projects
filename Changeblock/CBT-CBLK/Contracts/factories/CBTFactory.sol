// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import '../CBT.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract CBTFactory is Ownable {
    // State variables

    mapping(address => bool) public isCBT;
    mapping(address => bool) approvals;

    // Events

    event Deployment(address CBLK);

    event ApprovalSet(address target, bool approval);

    // Methods

    function approve(address target, bool approval) public onlyOwner {
        approvals[target] = approval;
        emit ApprovalSet(target, approval);
    }

    function deploy(string calldata name, string calldata symbol) public returns (address) {
        require(approvals[msg.sender] || msg.sender == owner(), 'Deployment approval required');
        CBT cbt = new CBT(name, symbol);
        cbt.transferOwnership(msg.sender);
        isCBT[address(cbt)] = true;
        emit Deployment(address(cbt));
        return address(cbt);
    }
}
