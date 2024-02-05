// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";

interface IRedemptionController {
    function afterMint(address to, uint256 amount) external;

    function afterOffer(address account, uint256 amount) external;

    function afterRedeem(address account, uint256 amount) external;

    function redeemableBalance(
        address account
    ) external view returns (uint256 redeemableAmount);
}
