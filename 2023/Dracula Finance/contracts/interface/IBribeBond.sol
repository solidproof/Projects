// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "./IERC20.sol";

interface IBribeBond {
    function depositedValueForEpoch() external view returns (uint256);

    function stable() external view returns (IERC20);

    function resetDepositedValueForEpoch() external;
}
