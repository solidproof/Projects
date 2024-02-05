// SPDX-License-Identifier: UNLICENSED
pragma solidity >=0.8.0;

import '../CBLKFixed.sol';
import '@openzeppelin/contracts/access/Ownable.sol';

contract CBLKFixedFactory is Ownable {
    // State variables

    mapping(address => bool) public isCBLKFixed;
    mapping(address => bool) approvals;

    // Events

    event Deployment(address CBLK);

    event ApprovalSet(address target, bool approval);

    // Methods

    function approve(address target, bool approval) public onlyOwner {
        approvals[target] = approval;
        emit ApprovalSet(target, approval);
    }

    function deploy(
        string calldata name,
        string calldata symbol,
        address[] calldata tokens,
        uint256[] calldata ratios
    ) public returns (address) {
        require(approvals[msg.sender] || msg.sender == owner(), 'Deployment approval required');
        address cblk = address(new CBLKFixed(name, symbol, tokens, ratios));
        isCBLKFixed[cblk] = true;
        emit Deployment(cblk);
        return cblk;
    }
}
