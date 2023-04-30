// SPDX-License-Identifier: MIT

pragma solidity ^0.8.16;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "../extensions/ISnapshot.sol";

interface IGovernanceToken is IERC20Upgradeable, ISnapshot {
    function balanceOfAt(
        address account,
        uint256 snapshotId
    ) external view returns (uint256);

    function totalSupplyAt(uint256 snapshotId) external view returns (uint256);

    function mint(address to, uint256 amount) external;

    function burn(address from, uint256 amount) external;

    function wrap(address from, uint256 amount) external;

    function unwrap(address from, address to, uint256 amount) external;
}
