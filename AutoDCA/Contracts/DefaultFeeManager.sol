// SPDX-License-Identifier: UNLICENSED
// © Copyright AutoDCA. All Rights Reserved

pragma solidity ^0.8.9;
import "./IFeeManager.sol";
import "./DCAStrategyManager.sol";
import "./DCATypes.sol";

contract DefaultFeeManager is IFeeManager {
    uint256 constant DENOMINATOR = 1000000;
    DCAStrategyManager dcaStrategyManager;

    constructor(address dcaStrategyManager_) {
        dcaStrategyManager = DCAStrategyManager(dcaStrategyManager_);
    }

    function getFeePercentage(
        uint256 strategyId,
        address /*user*/
    ) public view returns (uint256) {
        DCATypes.StrategyData memory strategyData = dcaStrategyManager
            .getStrategy(strategyId);
        return strategyData.strategyFee;
    }

    function calculateFee(
        uint256 strategyId,
        address user,
        uint256 amount
    ) external view returns (uint256) {
        uint256 strategyFee = getFeePercentage(strategyId, user);
        uint256 fee = (amount * strategyFee) / DENOMINATOR;

        return fee;
    }
}
