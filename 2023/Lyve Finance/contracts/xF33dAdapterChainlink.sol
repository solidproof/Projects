// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.13;

import "./interfaces/AggregatorV3Interface.sol";

contract xF33dAdapterChainlink {
    function getLatestData(
        bytes calldata _feedData
    ) external view returns (bytes memory) {
        address priceFeed = abi.decode(_feedData, (address));
        (
            uint80 roundId,
            int256 price,
            uint256 startedAt,
            uint256 timestamp,
            uint80 answeredInRound
        ) = AggregatorV3Interface(priceFeed).latestRoundData();
        return
            abi.encode(roundId, price, startedAt, timestamp, answeredInRound);
    }
}
