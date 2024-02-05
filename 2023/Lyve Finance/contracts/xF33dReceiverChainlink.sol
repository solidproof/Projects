// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import {xF33dReceiver} from "./xF33dReceiver.sol";

contract xF33dReceiverChainlink is xF33dReceiver {
    function latestRoundData()
        public
        view
        returns (
            uint80 roundId,
            int256 price,
            uint256 startedAt,
            uint256 timestamp,
            uint80 answeredInRound
        )
    {
        (roundId, price, startedAt, timestamp, answeredInRound) = abi.decode(
            oracleData,
            (uint80, int256, uint256, uint256, uint80)
        );
    }
}
