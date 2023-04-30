// SPDX-License-Identifier: MIT
pragma solidity ^0.8.16;

import "./IRedemptionController.sol";

// The contract tells how many tokens are redeemable by Contributors
abstract contract RedemptionControllerBase is IRedemptionController {
    struct Redeemable {
        uint256 amount;
        uint256 mintTimestamp;
        uint256 start;
        uint256 end;
    }

    struct MintBudget {
        uint256 timestamp;
        uint256 amount;
    }

    uint256 public redemptionStart;
    uint256 public redemptionWindow;

    uint256 public maxDaysInThePast;
    uint256 public activityWindow;

    mapping(address => Redeemable[]) internal _redeemables;
    mapping(address => uint256) internal _redeemablesFirst;

    mapping(address => MintBudget[]) internal _mintBudgets;
    mapping(address => uint256) internal _mintBudgetsStartIndex;

    function _initialize() internal {
        redemptionStart = 60 days;
        redemptionWindow = 10 days;
        maxDaysInThePast = 30 days * 15;
        activityWindow = 30 days * 3;
    }

    // Hooks

    function afterRedeem(address account, uint256 amount) external virtual;

    function afterMint(address account, uint256 amount) external virtual;

    function afterOffer(address account, uint256 amount) external virtual;

    // Public read

    function redeemableBalance(
        address account
    ) external view virtual returns (uint256 redeemableAmount) {
        Redeemable[] storage accountRedeemables = _redeemables[account];

        for (uint256 i = 0; i < accountRedeemables.length; i++) {
            Redeemable storage accountRedeemable = accountRedeemables[i];
            if (
                block.timestamp >= accountRedeemable.start &&
                block.timestamp < accountRedeemable.end
            ) {
                redeemableAmount += accountRedeemable.amount;
            }
        }
    }

    // Implementation

    function _afterMint(address to, uint256 amount) internal virtual {
        _mintBudgets[to].push(MintBudget(block.timestamp, amount));
    }

    function _afterOffer(address account, uint256 amount) internal virtual {
        // Find tokens minted ofer the last 3 months of activity, no earlier than 15 months
        if (_mintBudgets[account].length == 0) {
            return;
        }

        uint256 lastActivity = _mintBudgets[account][
            _mintBudgets[account].length - 1
        ].timestamp;

        // User can redeem tokens minted within 3 months since last activity
        uint256 thresholdActivity = lastActivity - activityWindow;
        // User cannot redeem tokens that were minted earlier than 15 months ago
        uint256 earliestTimestamp = block.timestamp - maxDaysInThePast;

        // If thresholdActivity falls behind the 15 months threshold, we apply a
        // cutoff.
        if (thresholdActivity < earliestTimestamp) {
            thresholdActivity = earliestTimestamp;
        }

        // Calculate when the next redemption starts, that is today plus the
        // time a contributor has to wait to redeem the tokens
        uint256 redemptionStarts = block.timestamp + redemptionStart;

        // Load the mint budgets for that account
        MintBudget[] storage mintBudgets = _mintBudgets[account];
        uint256 i;
        for (
            // Optimization: use the start index to avoid iterating over the
            // whole array
            i = _mintBudgetsStartIndex[account];
            // Iterate until we reach the end of the budgets and we still have
            // an amount to consume
            i < mintBudgets.length && amount > 0;
            i++
        ) {
            MintBudget storage mintBudget = mintBudgets[i];
            // If the mint is within the activity window, consume the mint and
            // create a new Redeemable object
            if (
                mintBudget.timestamp >= thresholdActivity &&
                mintBudget.amount > 0
            ) {
                if (amount >= mintBudget.amount) {
                    amount -= mintBudget.amount;

                    _addRedeemable(
                        account,
                        mintBudget.amount,
                        mintBudget.timestamp,
                        redemptionStarts
                    );
                    mintBudget.amount = 0;
                } else {
                    mintBudget.amount -= amount;

                    _addRedeemable(
                        account,
                        amount,
                        mintBudget.timestamp,
                        redemptionStarts
                    );
                    amount = 0;
                }
            }
        }

        // Optimization: save the start index for later use
        _mintBudgetsStartIndex[account] = i - 1;

        // We may still have some amount to consume, that's why we check if
        // there are some expired redeemables whose original mint is still in
        // the activity threshold.
        Redeemable[] storage accountRedeemables = _redeemables[account];

        for (
            i = _redeemablesFirst[account];
            i < accountRedeemables.length && amount > 0;
            i++
        ) {
            Redeemable storage accountRedeemable = accountRedeemables[i];
            if (
                // If the redeemable expired, and
                block.timestamp >= accountRedeemable.end &&
                // if it wasn't completely redeemed
                accountRedeemable.amount > 0 &&
                // and the original mint is still in the activity threshold
                accountRedeemable.mintTimestamp >= thresholdActivity
            ) {
                // Consume the redeemable
                if (amount >= accountRedeemable.amount) {
                    amount -= accountRedeemable.amount;
                    _addRedeemable(
                        account,
                        accountRedeemable.amount,
                        accountRedeemable.mintTimestamp,
                        redemptionStarts
                    );

                    accountRedeemable.amount = 0;
                } else {
                    accountRedeemable.amount -= amount;
                    _addRedeemable(
                        account,
                        amount,
                        accountRedeemable.mintTimestamp,
                        redemptionStarts
                    );

                    amount = 0;
                }
            }

            if (
                i > 0 &&
                accountRedeemable.mintTimestamp < thresholdActivity &&
                block.timestamp >= accountRedeemable.end
            ) {
                _redeemablesFirst[account] = i - 1;
            }
        }
    }

    function _afterRedeem(address account, uint256 amount) internal virtual {
        Redeemable[] storage redeemables = _redeemables[account];

        for (uint256 i = 0; i < redeemables.length && amount > 0; i++) {
            Redeemable storage redeemable = redeemables[i];
            if (
                block.timestamp >= redeemable.start &&
                block.timestamp < redeemable.end
            ) {
                if (amount < redeemable.amount) {
                    redeemable.amount -= amount;
                    amount = 0;
                } else {
                    amount -= redeemable.amount;
                    redeemable.amount = 0;
                    // FIXME: delete object from array?
                }
            }
        }

        require(
            amount == 0,
            "Redemption controller: amount exceeds redeemable balance"
        );
    }

    // Utility methods

    function _addRedeemable(
        address account,
        uint256 amount,
        uint256 mintTimestamp,
        uint256 redemptionStarts
    ) internal virtual {
        Redeemable memory offerRedeemable = Redeemable(
            amount,
            mintTimestamp,
            redemptionStarts,
            redemptionStarts + redemptionWindow
        );
        _redeemables[account].push(offerRedeemable);
    }
}
