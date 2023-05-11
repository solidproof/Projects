// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "./IMinter.sol";

interface IVoter {
    function ve() external view returns (address);

    function attachTokenToGauge(uint256 _tokenId, address account) external;

    function detachTokenFromGauge(uint256 _tokenId, address account) external;

    function emitDeposit(
        uint256 _tokenId,
        address account,
        uint256 amount
    ) external;

    function emitWithdraw(
        uint256 _tokenId,
        address account,
        uint256 amount
    ) external;

    function distribute(address _gauge) external;

    function notifyRewardAmount(uint256 amount) external;

    function minter() external view returns (address);

    function isLocked() external view returns (bool);

    function _claimBondRewards(
        address[] calldata _gauges,
        uint256 tokenId
    ) external returns (uint256);

    function isSnapshot(uint256 activePeriod) external view returns (bool);
}
