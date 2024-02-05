// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

interface IThunderCustomReq {
    function canDepositDescription() external view returns (string calldata);
    function canHarvestDescription() external view returns (string calldata);

    function canDeposit(address user, uint256 tokenId) external view returns (bool);
    function canHarvest(address user) external view returns (bool);
}