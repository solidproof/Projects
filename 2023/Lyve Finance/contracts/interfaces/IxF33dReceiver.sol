// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

interface IxF33dReceiver {
    function init(address lzEndpoint, address srcAddress,address lsdRateOracle) external;
}
