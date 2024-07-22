// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;
import "@openzeppelin/contracts/access/Ownable.sol";
import "./RequestCreation.sol";

/// @title Vountain – ApproveRequest
/// @notice Contract for the approval of requests.

contract ApproveRequest is RequestCreation {
  constructor(address configurationContract, address connectContract)
    RequestCreation(configurationContract, connectContract)
  {}

  event ApprovedRequest(
    uint256 indexed violinId_,
    address indexed sender,
    uint256 indexed requestId
  );

  /// @dev Function [approveRequest]
  /// Function reads the request in storage, because it has to modify the request count.
  /// Several checks are performed to check if the approver is elligible.
  /// @param violinId_ a violin id for which the request should be approved
  function approveRequest(uint256 violinId_, uint256 requestId_) external {
    RCLib.Request storage request = requestByViolinIdAndRequestId[violinId_][requestId_];

    require(request.canBeApproved, "there is nothing to approve!");
    require(request.requestValidUntil > block.timestamp, "request expired.");

    bool alreadyApproved = false;
    for (uint256 i = 0; i < approvedAddresses[violinId_][requestId_].length; i++) {
      if (msg.sender == approvedAddresses[violinId_][requestId_][i]) {
        alreadyApproved = true;
        break;
      }
    }
    require(!alreadyApproved, "you already approved!");

    require(
      checkRole(
        request.approvalType,
        violinId_,
        RCLib.PROCESS_TYPE.IS_APPROVE_PROCESS,
        request.targetAccount,
        request.requesterRole
      ),
      "sorry you have insufficient rights to approve!"
    );

    request.approvalCount = request.approvalCount + 1;
    approvedAddresses[violinId_][requestId_].push(msg.sender);
    request.approvedAddresses = approvedAddresses[violinId_][requestId_];
    emit ApprovedRequest(violinId_, msg.sender, request.requestId);
  }
}
