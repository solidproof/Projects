// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import '../CBLKUnfixed.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

// Factory contract for deploying CBLKFixed tokens.
contract CBLKUnfixedFactory is Ownable {
    // State variables

    mapping(address => bool) public isCBLKUnfixed;
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
        CBLKUnfixed cblk = new CBLKUnfixed(name, symbol);
        cblk.transferOwnership(msg.sender);
        isCBLKUnfixed[address(cblk)] = true;
        emit Deployment(address(cblk));
        return address(cblk);
    }
}
