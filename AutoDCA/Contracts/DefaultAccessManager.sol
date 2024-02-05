// SPDX-License-Identifier: UNLICENSED
// © Copyright AutoDCA. All Rights Reserved

pragma solidity ^0.8.9;
import "./IAccessManager.sol";
import "./DCAStrategyManager.sol";
import "./DCATypes.sol";

contract DefaultAccessManager is IAccessManager {
    enum AccessResult {
        OK,
        MAX_PARTICIPANTS_LIMIT_REACHED,
        WEEKLY_AMOUNT_TOO_LOW
    }

    error AccessDenied(uint256 poolId, AccessResult reason);

    event AccessGranted();

    DCAStrategyManager dcaStrategyManager;

    constructor(address dcaStrategyManager_) {
        dcaStrategyManager = DCAStrategyManager(dcaStrategyManager_);
    }

    function hasAccess(
        uint256 strategyId,
        address user,
        uint256 weeklyAmount
    ) internal view returns (bool, AccessResult) {
        DCATypes.StrategyData memory strategyData = dcaStrategyManager
            .getStrategy(strategyId);
        DCATypes.UserStrategyData memory userStrategyData = dcaStrategyManager
            .getUserStrategy(user, strategyId);
        uint256 poolParticipantsLength = dcaStrategyManager
            .getStrategyParticipantsLength(strategyId);
        if (!userStrategyData.participating) {
            if (poolParticipantsLength >= strategyData.maxParticipants) {
                return (false, AccessResult.MAX_PARTICIPANTS_LIMIT_REACHED);
            }
        }
        if (strategyData.minWeeklyAmount > weeklyAmount) {
            return (false, AccessResult.WEEKLY_AMOUNT_TOO_LOW);
        }
        return (true, AccessResult.OK);
    }

    function hasAccess(
        uint256 strategyId,
        address user
    ) external view returns (bool) {
        (bool allowed, ) = hasAccess(strategyId, user, type(uint256).max);
        return allowed;
    }

    function participate(
        uint256 strategyId,
        address user,
        uint256 weeklyAmount
    ) external view {
        (bool allowed, AccessResult reason) = hasAccess(
            strategyId,
            user,
            weeklyAmount
        );
        if (!allowed) {
            revert AccessDenied(strategyId, reason);
        }
    }
}
