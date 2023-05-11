// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "../interface/IBribe.sol";
import "../interface/IERC721.sol";
import "../interface/IVoter.sol";
import "../interface/IVe.sol";
import "./MultiRewardsPoolBase.sol";

/// @title Bribes pay out rewards for a given pool based on the votes
///        that were received from the user (goes hand in hand with Gauges.vote())
contract Bribe is IBribe, MultiRewardsPoolBase {
    /// @dev Only voter can modify balances (since it only happens on vote())
    address public immutable voter;
    address public immutable ve;

    // Assume that will be created from voter contract through factory
    constructor(
        address _voter,
        address[] memory _allowedRewardTokens
    ) MultiRewardsPoolBase(address(0), _voter, _allowedRewardTokens) {
        voter = _voter;
        ve = IVoter(_voter).ve();
    }

    function getReward(uint256 tokenId, address[] memory tokens) external {
        require(
            IVe(ve).isApprovedOrOwner(msg.sender, tokenId),
            "Not token owner"
        );
        _getReward(_tokenIdToAddress(tokenId), tokens, msg.sender);
    }

    /// @dev Used by Voter to allow batched reward claims
    function getRewardForOwner(
        uint256 tokenId,
        address[] memory tokens
    ) external override {
        require(msg.sender == voter, "Not voter");
        address owner = IERC721(ve).ownerOf(tokenId);
        _getReward(_tokenIdToAddress(tokenId), tokens, owner);
    }

    /// @dev This is an external function, but internal notation is used
    ///      since it can only be called "internally" from Gauges
    function _deposit(uint256 amount, uint256 tokenId) external override {
        require(msg.sender == voter, "Not voter");
        require(amount > 0, "Zero amount");

        address adr = _tokenIdToAddress(tokenId);
        _increaseBalance(adr, amount);
        emit Deposit(adr, amount);
    }

    function _withdraw(uint256 amount, uint256 tokenId) external override {
        require(msg.sender == voter, "Not voter");
        require(amount > 0, "Zero amount");

        address adr = _tokenIdToAddress(tokenId);
        _decreaseBalance(adr, amount);
        emit Withdraw(adr, amount);
    }

    /// @dev Used to notify a gauge/bribe of a given reward,
    ///      this can create griefing attacks by extending rewards
    function notifyRewardAmount(
        address token,
        uint256 amount
    ) external override {
        _notifyRewardAmount(token, amount);
    }

    function tokenIdToAddress(uint256 tokenId) external pure returns (address) {
        return _tokenIdToAddress(tokenId);
    }

    function _tokenIdToAddress(
        uint256 tokenId
    ) internal pure returns (address) {
        address adr = address(uint160(tokenId));
        require(_addressToTokenId(adr) == tokenId, "Wrong convert");
        return adr;
    }

    function addressToTokenId(address adr) external pure returns (uint256) {
        return _addressToTokenId(adr);
    }

    function _addressToTokenId(address adr) internal pure returns (uint256) {
        return uint256(uint160(adr));
    }
}
