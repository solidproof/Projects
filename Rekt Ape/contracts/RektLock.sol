// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./veNFT.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


/// @title $REKT Token Locking Module
/// @notice Locked $REKT Token gives the users governance voting power which can
/// @notice be used to vote on proposals.

contract LockingModule is veNFT {
    error InvalidAmount ();
    error InvalidDuration();
    error InsufficientFunds (uint256 _amount, uint256 _balance);
    error TransferFailed();
    error NotLocked();
    error NotOwner();
    error NotDeadline();

    event RektLocked (uint256 startTime_, uint256 endTime_, uint256 lockedAmount_, uint256 tokenId_);
    event RektUnlocked (uint256 unlockedAmount_, uint256 tokenId_);

    uint256 public MINDURATION = 7_776_000; //3 Months = 7,776,000;
    uint256 public MAXDURATION = 31_104_000; //12 Months = 31104000;

    struct LockedDetails {
        uint256 startTime;
        uint256 endTime;
        uint256 lockedAmount;
        uint256 isLocked; //0 - No, 1 - Yes;
    }

    IERC20 rekt;
    
    mapping (uint256 tokenID => LockedDetails) public tokenIDLockedDetails;

    constructor (string memory _baseURI, address _rekt) 
    payable veNFT (_baseURI) {
        rekt = IERC20(_rekt);
    }

    modifier validateDuration (uint256 _duration) {
        if (_duration < MINDURATION || _duration > MAXDURATION) {
            revert InvalidDuration();
        }
        _;
    }

    /// @notice Check if a token ID of the NFT is locked
    /// @param _tokenID The token ID of the NFT
    /// @return 0 or 1. 0 - Not locked. 1 - Locked.
    function isLocked (uint256 _tokenID) public view returns (uint256) {
        return tokenIDLockedDetails[_tokenID].isLocked;
    }

    /// @notice get voting power of a particular NFT token ID
    /// @notice If the locked duration is exceeded, it returns 0
    /// @dev The voting power decreases linearly as the end time for the lock up period approaches
    /// @param _tokenID The token ID of the NFT
    /// @return votingPower - The voting Power of the NFT
    function getVotingPower (uint256 _tokenID) external view returns (uint256 votingPower) {
        if (isLocked(_tokenID) == 0) revert NotLocked();
        LockedDetails memory lockedDetails = tokenIDLockedDetails[_tokenID];
        uint256 startTime = lockedDetails.startTime;
        uint256 endTime = lockedDetails.endTime;
        uint256 lockedAmount = lockedDetails.lockedAmount;
        // If the deadline has elapsed return 0;
        if (block.timestamp > endTime) {
            votingPower = 0;
            return votingPower;
        }
        uint256 deductedPower = lockedAmount * (block.timestamp - startTime);
        // Rounding Up the division
        deductedPower = unsafeDivUp(deductedPower, (endTime - startTime));
        votingPower = lockedAmount - deductedPower;
        return votingPower;
    }

    /// @notice returns the seconds to deadline. If deadline exceeded, returns 0
    function timeToDeadline (uint256 _tokenID) public view returns (uint256 _deadline) {
        if (isLocked(_tokenID) == 0) revert NotLocked();
        uint256 endTime = tokenIDLockedDetails[_tokenID].endTime;
        _deadline = endTime > block.timestamp ? endTime - block.timestamp : 0;
    }

    /// @notice Lock up the $REKT tokens
    /// @dev After locking up $REKT tokens, an NFT would be minted to signify the
    /// @dev voting power. This NFT can be traded and transferred freely, but 
    /// @dev doing so would mean giving up your voting Power.
    /// @param _amount - The amount of $REKT tokens to lock up
    /// @param _duration - The duration to lock up $REKT tokens
    function lock(uint _amount, uint256 _duration) external 
        validateDuration(_duration) {

        if (_amount == 0) revert InvalidAmount();
        uint256 balance = rekt.balanceOf(msg.sender);
        if (_amount > balance) revert InsufficientFunds(balance, _amount);

        uint256 _tokenID = tokenIds;

        LockedDetails memory lockedDetails = tokenIDLockedDetails[_tokenID];
        uint256 timestamp = block.timestamp;
        lockedDetails.startTime = timestamp;
        lockedDetails.endTime = timestamp + _duration;
        lockedDetails.lockedAmount = _amount;
        lockedDetails.isLocked = 1;
        tokenIDLockedDetails[_tokenID] = lockedDetails;
        // Approve contract to transfer tokens
        // rekt.approve(address(this), type(uint256).max);
        bool success = rekt.transferFrom(msg.sender, address(this), _amount);
        if (!success) revert TransferFailed();

        mint();
        
        emit RektLocked(timestamp, timestamp + _duration, _amount, _tokenID);
    }

    /// @notice unlocks the locked $REKT token and transfer to the current NFT holder
    function unlock(uint256 _tokenID) external {
        address sender = msg.sender;
        if (ownerOf(_tokenID) != sender) revert NotOwner();
        if (timeToDeadline(_tokenID) != 0) revert NotDeadline();
        if (isLocked(_tokenID) == 0) revert NotLocked();
        tokenIDLockedDetails[_tokenID].isLocked = 0;
        uint256 lockedAmount = tokenIDLockedDetails[_tokenID].lockedAmount;
        // delete tokenIDLockedDetails[_tokenID];
        bool success = rekt.transfer(sender, lockedAmount);
        if (!success) revert TransferFailed();

        emit RektUnlocked (lockedAmount, _tokenID);
    }

    function setDuration(uint256 _minDuration, uint256 _maxDuration) external payable onlyOwner {
        MINDURATION = _minDuration;
        MAXDURATION = _maxDuration;
    }

    function getDuration() external view returns (uint256 _minDuration, uint256 _maxDuration) {
        _minDuration = MINDURATION;
        _maxDuration = MAXDURATION;
    }

    function unsafeDivUp(uint256 x, uint256 y) internal pure returns (uint256 z) {
        /// @solidity memory-safe-assembly
        assembly {
            // Add 1 to x * y if x % y > 0. Note this will
            // return 0 instead of reverting if y is zero.
            z := add(gt(mod(x, y), 0), div(x, y))
        }
    }

}