// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity ^0.8.10;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721.sol";

/// @title NftPositionLocker
/// @notice This contract locks v3 nft position of uniswap v3 for a period of time
contract NftPositionLocker is Ownable, IERC721Receiver {
    IERC721 public immutable nonfungiblePositionManager;

    uint40 public lockId;
    uint40 public unlockTime;
    uint256 public positionId;
    bool public isDeposited;
    bool public isWithdrawn;

    error NotPositionNFT();
    error InvalidNFT();
    error NotOwner();
    error NotUnlocked();
    error Unlocked();
    error AlreadyDeposited();
    error NotDeposited();
    error AlreadyWithdrawn();
    error InvalidUnlockTime();

    event LockCreated(uint40 lockId, address positionManagerAddress, uint40 unlockTime, address owner);
    event Deposit(address from, uint256 tokenId);
    event Extended(uint40 newUnlockTime);
    event Withdrew();
    event Recover(uint256 tokenId);

    constructor(uint40 lockId_, address positionManagerAddress_, uint40 unlockTime_, address owner_) {
        if (unlockTime_ < _blockTimestamp()) revert InvalidUnlockTime();

        nonfungiblePositionManager = IERC721(positionManagerAddress_);
        unlockTime = unlockTime_;
        lockId = lockId_;

        transferOwnership(owner_);

        emit LockCreated(lockId_, positionManagerAddress_, unlockTime_, owner_);
    }

    bool private _transferLocked;

    /// @notice Check if unlocked
    function isUnlocked() public view returns (bool) {
        return _blockTimestamp() >= unlockTime;
    }

    /// @notice Upon receiving a ERC721
    function onERC721Received(
        address,
        address _from,
        uint256 _tokenId,
        bytes calldata
    ) external override returns (bytes4) {
        if (_from != owner()) revert NotOwner();
        if (isUnlocked()) revert Unlocked();
        if (isDeposited) revert AlreadyDeposited();
        if (msg.sender != address(nonfungiblePositionManager)) revert NotPositionNFT();
        isDeposited = true;
        positionId = _tokenId;
        emit Deposit(_from, _tokenId);

        return this.onERC721Received.selector;
    }

    /// @notice Withdraw the deposited position
    function withdraw() external onlyOwner {
        if (!isUnlocked()) revert NotUnlocked();
        if (!isDeposited) revert NotDeposited();
        if (isWithdrawn) revert AlreadyWithdrawn();

        isWithdrawn = true;

        nonfungiblePositionManager.safeTransferFrom(address(this), owner(), positionId);

        emit Withdrew();
    }

    /// @notice Recover incorrectly sent tokens
    function recoverToken(uint256 tokenId) external onlyOwner {
        if (tokenId == positionId) revert InvalidNFT();

        nonfungiblePositionManager.safeTransferFrom(address(this), owner(), tokenId);

        emit Recover(tokenId);
    }

    /// @notice Extend the unlock time
    function extend(uint40 newUnlockTime) external onlyOwner {
        if (isUnlocked()) revert Unlocked();
        if (newUnlockTime <= unlockTime) revert InvalidUnlockTime();

        unlockTime = newUnlockTime;

        emit Extended(newUnlockTime);
    }

    function _blockTimestamp() internal view returns (uint256) {
        return block.timestamp;
    }
}