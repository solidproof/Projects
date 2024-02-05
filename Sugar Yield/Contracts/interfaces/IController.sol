// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity 0.8.15;

interface IController {
    function getVaultFactory() external view returns (address);

    function triggerDepeg(uint256 marketIndex, uint256 epochEnd) external;

    function triggerEndEpoch(uint256 marketIndex, uint256 epochEnd) external;

    function triggerNullEpoch(uint256 marketIndex, uint256 epochEnd) external;
}