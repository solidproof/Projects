// SPDX-License-Identifier: BSD-3-Clause
pragma solidity 0.8.9;

interface IBridgeVault {
    function bridgeWithdrawal(address token, address recipient, uint256 amount) external;
}