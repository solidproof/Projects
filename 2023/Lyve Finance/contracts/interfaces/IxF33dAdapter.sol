// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

interface IxF33dAdapter {
    function getLatestData(
        bytes calldata _feedData
    ) external view returns (bytes memory);
}
