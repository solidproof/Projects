// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

interface VaultInterface {
    function transferItems(
        address _recipient,
        uint16 _vaultId,
        uint16 _qtyToClaim,
        uint16 _league,
        uint16 _claimed
    ) external returns (uint256 pointsToRedeem, bool isPhysical);
}
