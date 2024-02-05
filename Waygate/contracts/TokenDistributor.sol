import "hardhat/console.sol";

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

abstract contract TokenDistributor {
    uint256 constant NUMERATOR = 1000;
    uint256 totalAllocations;

    mapping(address => bool) internal isRecipient;
    mapping(address => uint256) internal recipientAllocationsPercentage;
    address[] internal recipients;

    event ReceipientAdded(
        address recipientAddress,
        uint256 recipientAllocationsPercentage,
        uint256 timestamp
    );

    event ReceipientRemoved(address recipientAddress, uint256 timestamp);

    function _addReceipient(address _recipient, uint256 _allocationPercent)
        internal
    {
        require(
            NUMERATOR >= totalAllocations + _allocationPercent,
            "Distributor: Total allocations exceeded"
        );
        require(
            _allocationPercent > 0,
            "Distributor: Allocation % cannot be zero"
        );

        isRecipient[_recipient] = true;
        recipientAllocationsPercentage[_recipient] = _allocationPercent;
        totalAllocations += _allocationPercent;
        recipients.push(_recipient);

        emit ReceipientAdded(_recipient, _allocationPercent, block.timestamp);
    }

    function _removeReceipient(address _recipient) internal {
        require(isRecipient[_recipient], "Distributor: No a recipient");

        isRecipient[_recipient] = false;
        totalAllocations -= recipientAllocationsPercentage[_recipient];
        recipientAllocationsPercentage[_recipient] = 0;

        emit ReceipientRemoved(_recipient, block.timestamp);
    }
}
