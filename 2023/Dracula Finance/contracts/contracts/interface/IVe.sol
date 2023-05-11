// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

interface IVe {
    enum DepositType {
        DEPOSIT_FOR_TYPE,
        CREATE_LOCK_TYPE,
        INCREASE_LOCK_AMOUNT,
        INCREASE_UNLOCK_TIME,
        MERGE_TYPE
    }

    struct Point {
        int128 bias;
        int128 slope; // # -dweight / dt
        uint256 ts;
        uint256 blk; // block
    }
    /* We cannot really do block numbers per se b/c slope is per time, not per block
     * and per block could be fairly bad b/c Ethereum changes blocktimes.
     * What we can do is to extrapolate ***At functions */

    struct LockedBalance {
        int128 amount;
        uint256 end;
    }

    function token() external view returns (address);

    function balanceOfNFT(uint256) external view returns (uint256);

    function isApprovedOrOwner(address, uint256) external view returns (bool);

    function createLockFor(
        uint256,
        uint256,
        address
    ) external returns (uint256);

    function userPointEpoch(uint256 tokenId) external view returns (uint256);

    function epoch() external view returns (uint256);

    function userPointHistory(
        uint256 tokenId,
        uint256 loc
    ) external view returns (Point memory);

    function pointHistory(uint256 loc) external view returns (Point memory);

    function checkpoint() external;

    function depositFor(uint256 tokenId, uint256 value) external;

    function attachToken(uint256 tokenId) external;

    function detachToken(uint256 tokenId) external;

    function voting(uint256 tokenId) external;

    function abstain(uint256 tokenId) external;

    function createLockBond(
        uint256 value,
        address to
    ) external returns (uint256);
}
