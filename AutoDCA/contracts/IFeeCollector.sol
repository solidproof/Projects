// SPDX-License-Identifier: UNLICENSED
// © Copyright AutoDCA. All Rights Reserved
pragma solidity ^0.8.9;

interface IFeeCollector {
    function receiveNative() external payable;

    function receiveToken(address tokenAddress, uint256 amount) external;
}
