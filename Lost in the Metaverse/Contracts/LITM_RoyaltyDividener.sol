// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";

contract RoyaltyDividener is Ownable {
  address[] public holders;
  mapping(address=>bool) public isHolder;
  mapping(address=>uint) public claimed;
  mapping(address=>uint) public accumulated;

  uint private _totalReceived;
  uint private _totalDistributed;

  address public NFT;

  constructor(address _NFT) {
    require (_NFT != address(0), "Invalid NFT address");
    NFT = _NFT;
  }

  receive() external payable {
    _totalReceived += msg.value;
  }

  function withdraw() external onlyOwner {
    uint bal = address(this).balance;

    uint i;
    for (i = 0; i < holders.length; i+=1) {
      Address.sendValue(payable(holders[i]), bal / holders.length);
    }
  }

  function setNftAddress(address _nft) external onlyOwner {
    require (_nft != address(0), "Invalid NFT address");
    NFT = _nft;
  }

  function _updateRewards() internal {
    uint distribute = (_totalReceived - _totalDistributed) / holders.length;

    if (distribute > 0) {
      uint i;

      for (i = 0; i < holders.length; i+=1) {
        accumulated[holders[i]] += distribute;
      }

      _totalDistributed += distribute * holders.length;
    }
  }

  function addHolder(address _holder) external {
    require (msg.sender == owner() || msg.sender == NFT, "Access denied");

    if (holders.length > 0) {
      _updateRewards();
    }

    holders.push(_holder);
    isHolder[_holder] = true;
  }

  function pendingReward(address _holder) public view returns (uint) {
    if (!isHolder[_holder]) {
      return 0;
    }

    return accumulated[_holder] + (_totalReceived - _totalDistributed) / holders.length - claimed[_holder];
  }

  function claim() external {
    require (isHolder[msg.sender], "You are not a royalty holder");
    
    _updateRewards();

    uint reward = accumulated[msg.sender] - claimed[msg.sender];
    require (reward > 0, "You have no share to claim");

    Address.sendValue(payable(msg.sender), reward);
    claimed[msg.sender] = accumulated[msg.sender];
  }
}
