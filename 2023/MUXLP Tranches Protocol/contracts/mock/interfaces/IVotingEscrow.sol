// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface IVotingEscrow {
    struct Point {
        int128 bias;
        int128 slope; // - dweight / dt
        uint256 ts;
        uint256 blk; // block
    }

    struct LockedBalance {
        int128 amount;
        uint256 end;
    }

    struct DepositedBalance {
        uint128 mcbAmount;
        uint128 muxAmount;
    }

    function depositedBalances(address account) external view returns (DepositedBalance memory);

    function averageUnlockTime() external view returns (uint256);

    function pointHistory(uint256 epoch) external view returns (Point memory);

    function getLastUserBlock(address addr) external view returns (uint256);

    function checkpoint() external;

    function depositFor(
        address _fundingAddr,
        address _addr,
        address _token,
        uint256 _value,
        uint256 _unlockTime
    ) external;

    function increaseUnlockTimeFor(address _addr, uint256 _unlockTime) external;

    function withdrawFor(address _account) external;

    function increaseAmount(uint256 _value) external;

    function increaseUnlockTime(uint256 _unlockTime) external;

    function balanceOf(address addr) external view returns (uint256);

    function totalSupply() external view returns (uint256);

    function balanceOfAt(address addr, uint256 _block) external view returns (uint256);

    function totalSupplyAt(uint256 _block) external view returns (uint256);

    function supply() external view returns (uint256);

    function locked(address account) external view returns (LockedBalance memory);

    function lockedEnd(address _addr) external view returns (uint256);

    function lockedAmount(address _addr) external view returns (uint256);

    function userPointEpoch(address _addr) external view returns (uint256);

    function epoch() external view returns (uint256);

    function userPointHistory(address _addr, uint256 loc) external view returns (Point memory);

    function token0() external view returns (address);

    function token1() external view returns (address);

    function findTimestampEpoch(uint256 _timestamp) external view returns (uint256);

    function findTimestampUserEpoch(
        address _addr,
        uint256 _timestamp,
        uint256 max_user_epoch
    ) external view returns (uint256);

    function setHandler(address _handler, bool _isActive) external;
}
