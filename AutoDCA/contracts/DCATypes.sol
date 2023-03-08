// SPDX-License-Identifier: UNLICENSED
// © Copyright AutoDCA. All Rights Reserved

pragma solidity ^0.8.9;

library DCATypes {
    enum ExecutionPhase {
        COLLECT,
        EXCHANGE,
        DISTRIBUTE,
        FINISH
    }

    struct StrategyExecutionData {
        bool isExecuting;
        ExecutionPhase currentPhase;
        int256 lastLoopIndex;
        uint256 totalCollectedToExchange;
        uint256 totalCollectedFee;
        uint256 received;
    }

    struct StrategyData {
        address fromAsset;
        address toAsset;
        address accessManager;
        address feeManager;
        uint256 totalCollectedFromAsset;
        uint256 totalReceivedToAsset;
        uint256 strategyFee; // percentage amount divided by 1000000
        uint24 uniswapFeeTier; // 3000 for 0.3% https://docs.uniswap.org/protocol/concepts/V3-overview/fees#pool-fees-tiers
        uint256 maxParticipants;
        uint256 minWeeklyAmount;
        uint256 lastExecuted;
        StrategyExecutionData executionData;
    }

    struct UserStrategyData {
        uint256 totalCollectedFromAsset; // total "FromAsset" already collected by user in strategy
        uint256 totalReceivedToAsset; // total "ToAsset" received by user in strategy
        uint256 lastCollectedFromAssetAmount; // "FromAsset" collected during last DCA strategy execution
        uint256 totalCollectedFromAssetSinceStart; // total "FromAsset" already collected by user in strategy since start timestamp
        uint256 start; // participate timestamp (updates when updating weeklyAmount)
        uint256 weeklyAmount; // amount of "FromAsset" that will be converted to "ToAsset" within one week period
        bool participating; // is currently participating
        uint256 participantsIndex; // index in strategyParticipants array
    }

    struct StrategyInfoResponse {
        address fromAsset;
        address toAsset;
        address accessManager;
        address feeManager;
        uint256 totalCollectedFromAsset;
        uint256 totalReceivedToAsset;
        uint256 strategyFee; // percentage amount divided by 1000000
        uint24 uniswapFeeTier; // 3000 for 0.3% https://docs.uniswap.org/protocol/concepts/V3-overview/fees#pool-fees-tiers
        uint256 maxParticipants;
        uint256 minWeeklyAmount;
        uint256 lastExecuted;
        bool isExecuting;
        uint256 participantsAmount;
        DCATypes.UserStrategyData userStrategyData;
    }
}
