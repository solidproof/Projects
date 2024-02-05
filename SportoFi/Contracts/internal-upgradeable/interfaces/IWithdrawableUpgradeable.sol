// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

interface IWithdrawableUpgradeable {
    event Withdrawn(
        IERC20Upgradeable indexed token,
        address indexed to,
        uint256 indexed value
    );
    event Received(address indexed sender, uint256 indexed value);

    function withdraw(
        IERC20Upgradeable from_,
        address to_,
        uint256 amount_
    ) external;
}