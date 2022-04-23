// SPDX-License-Identifier: UNLICENSED

pragma solidity 0.8.4;

import '@openzeppelin/contracts/access/Ownable.sol';

import './IBusinessLogic.sol';
import './../Membership/IMembership.sol';

contract BusinessLogicV1 is IBusinessLogic, Ownable {
  // The number of seconds before a {@code dropStart} that the presale will be made available
  // default to 48hrs
  uint256 private _presaleOffset = 172800;
  address internal _membershipContractAddress;

  function checkMintAllowed(
    uint256 dropStart,
    uint256 dropEnd,
    address buyer,
    uint256 price,
    uint256 msgValue,
    uint256 minMembershipTier
  ) public view override returns (string memory) {
    uint256 membershipTier = 0;
    if (_membershipContractAddress != address(0)) {
      membershipTier = IMembership(_membershipContractAddress)
        .getHighestMembershipTier(buyer);
    }

    return
      checkMintAllowedWithMembership(
        dropStart,
        dropEnd,
        price,
        msgValue,
        minMembershipTier,
        membershipTier
      );
  }

  function checkMintAllowedWithMembership(
    uint256 dropStart,
    uint256 dropEnd,
    uint256 price,
    uint256 msgValue,
    uint256 minMembershipTier,
    uint256 membershipTier
  ) public view returns (string memory) {
    if (msgValue != price) {
      return 'Please submit the asking price';
    }

    if (membershipTier < minMembershipTier) {
      return 'Insufficient membership tier';
    }

    string memory dropStartErr = checkDropStart(dropStart, membershipTier);
    if (!isEmptyString(dropStartErr)) {
      return dropStartErr;
    }

    if (dropEnd != 0 && block.timestamp >= dropEnd) {
      return 'This drop has ended';
    }

    return '';
  }

  function checkDropStart(uint256 dropStart, uint256 membershipTier)
    public
    view
    returns (string memory)
  {
    uint256 offset = 0;
    if (membershipTier > 0) {
      offset = _presaleOffset;
    }

    if (block.timestamp < dropStart - offset) {
      return 'This drop has not started yet';
    }

    return '';
  }

  function isEmptyString(string memory s) internal pure returns (bool) {
    return bytes(s).length == 0;
  }

  function setPresaleOffset(uint256 presaleOffset) public onlyOwner {
    _presaleOffset = presaleOffset;
  }

  function getPresaleOffset() public view returns (uint256) {
    return _presaleOffset;
  }

  function setMembershipContractAddress(address membershipContractAddress)
    public
    onlyOwner
  {
    _membershipContractAddress = membershipContractAddress;
  }

  function getMembershipContractAddress() public view returns (address) {
    return _membershipContractAddress;
  }
}
