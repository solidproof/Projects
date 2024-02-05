// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IDistributionWallet {
    function distribute(address account, uint256 amount) external;
}
