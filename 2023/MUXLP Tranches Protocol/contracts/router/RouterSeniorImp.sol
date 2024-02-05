// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "../libraries/LibConfigSet.sol";
import "../libraries/LibUniswap.sol";

import "./UtilsImp.sol";
import "./TicketImp.sol";
import "./AdapterImp.sol";
import "./RouterRewardImp.sol";
import "./Type.sol";

library RouterSeniorImp {
    using UtilsImp for RouterStateStore;
    using TicketImp for RouterStateStore;
    using AdapterImp for RouterStateStore;
    using RouterRewardImp for RouterStateStore;

    using LibConfigSet for LibConfigSet.ConfigSet;
    using LibTypeCast for bytes32;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    event DepositSenior(address indexed account, uint256 assets, uint256 shares);
    event WithdrawSenior(address indexed account, uint256 shares);
    event WithdrawSeniorDelayed(address indexed account, uint64 indexed ticketId, uint256 shares);
    event HandleWithdrawSenior(address indexed account, uint64 indexed ticketId, uint256 removals);
    event WithdrawSeniorSuccess(
        address indexed account,
        uint64 indexed ticketId,
        uint256 repayment,
        uint256 overflows
    );
    event WithdrawSeniorFailed(address indexed account, uint64 indexed ticketId);
    event IncreasePendingSeniorWithdrawal(
        address indexed account,
        uint256 shares,
        uint256 personalPendingWithdrawal,
        uint256 totalPendingWithdrawal
    );
    event DecreasePendingSeniorWithdrawal(
        address indexed account,
        uint256 shares,
        uint256 personalPendingWithdrawal,
        uint256 totalPendingWithdrawal
    );

    // =============================================== Deposit Senior ===============================================
    function depositSenior(
        RouterStateStore storage store,
        address account,
        uint256 assets
    ) public returns (uint256 shares) {
        require(assets > 0, "RouterSeniorImp::ZERO_AMOUNT");
        store.updateRewards(account);
        IERC20Upgradeable(store.seniorVault.depositToken()).safeTransferFrom(
            account,
            address(store.seniorVault),
            assets
        );
        shares = store.seniorVault.deposit(assets, account);
        emit DepositSenior(account, assets, shares);
    }

    // =============================================== Withdraw Senior ===============================================
    function withdrawSenior(
        RouterStateStore storage store,
        address account,
        uint256 shares, // assets
        bool acceptPenalty
    ) public {
        // TODO: lock
        (ISeniorVault.LockType lockType, bool isLocked) = store.seniorVault.lockStatus(account);
        if (lockType == ISeniorVault.LockType.HardLock) {
            require(!isLocked, "RouterSeniorImp::LOCKED");
        } else if (lockType == ISeniorVault.LockType.SoftLock) {
            require(!isLocked || (isLocked && acceptPenalty), "RouterSeniorImp::LOCKED");
        }
        uint256 pendingWithdrawal = store.pendingSeniorWithdrawals[account];
        uint256 maxWithdrawal = store.seniorVault.balanceOf(account);
        maxWithdrawal = maxWithdrawal > pendingWithdrawal ? maxWithdrawal - pendingWithdrawal : 0;
        require(shares <= maxWithdrawal, "RouterSeniorImp::EXCEEDS_WITHDRAWABLE");

        uint256 assets = store.seniorVault.convertToAssets(shares);
        uint256 available = store.seniorTotalAssets();
        if (assets <= available) {
            store.updateRewards(account);
            store.seniorVault.withdraw(msg.sender, account, shares, account);
            emit WithdrawSenior(account, shares);
        } else {
            Ticket storage ticket = store.createTicket(
                Action.WithdrawSenior,
                abi.encode(
                    SeniorWithdrawParams({
                        caller: msg.sender,
                        account: account,
                        shares: shares,
                        removals: 0, // will fill in handleWithdrawSenior
                        minRepayments: assets - available
                    })
                )
            );
            emit WithdrawSeniorDelayed(account, ticket.id, shares);
            // status init => pending
            handleWithdrawSenior(store, ticket);
        }
    }

    function handleWithdrawSenior(RouterStateStore storage store, Ticket storage ticket) public {
        require(
            ticket.status == Status.Init || ticket.status == Status.Failed,
            "ImpRouter::INVALID_STATUS"
        );
        // estimate repay
        SeniorWithdrawParams memory params = abi.decode(ticket.params, (SeniorWithdrawParams));
        if (params.account != address(0)) {
            params.removals = store.estimateMaxIn(params.minRepayments);
            increasePendingWithdrawal(store, params.account, params.shares);
        }
        store.juniorVault.transferOut(params.removals);
        uint64 orderId = store.placeRemoveOrder(params.removals);
        store.updateTicket(ticket, orderId, Status.Pending, abi.encode(params));

        emit HandleWithdrawSenior(params.account, ticket.id, params.removals);
    }

    function beforeWithdrawSenior(
        RouterStateStore storage store,
        MuxOrderContext memory context,
        Ticket storage ticket
    ) public view returns (bool) {
        SeniorWithdrawParams memory params = abi.decode(ticket.params, (SeniorWithdrawParams));
        uint256 seniorAmountOut = store.estimateExactOut(
            context.seniorAssetId,
            params.removals,
            context.seniorPrice,
            context.juniorPrice,
            context.currentSeniorValue,
            context.targetSeniorValue
        );
        return seniorAmountOut >= params.minRepayments;
    }

    function onWithdrawSeniorSuccess(
        RouterStateStore storage store,
        MuxOrderContext memory,
        Ticket storage ticket,
        uint256 amountOut
    ) public {
        SeniorWithdrawParams memory params = abi.decode(ticket.params, (SeniorWithdrawParams));
        // 1. repay
        uint256 totalBorrows = store.seniorBorrows();
        uint256 repayments = MathUpgradeable.min(amountOut, totalBorrows);
        IERC20Upgradeable(store.seniorVault.depositToken()).safeTransfer(
            address(store.seniorVault),
            repayments
        );
        store.seniorVault.repay(repayments);
        // 2. if need withdraw
        if (params.account != address(0)) {
            store.seniorVault.withdraw(
                params.caller,
                params.account,
                params.shares,
                params.account
            );
            decreasePendingWithdrawal(store, params.account, params.shares);
        }
        // 3. return the remaining over total debts to junior.
        //    only the last junior or liquidation will have overflows.
        uint256 overflows = amountOut - repayments;
        if (overflows > 0) {
            // buy MUXLP
            store.createTicket(
                Action.DepositJunior,
                abi.encode(DepositJuniorParams({assets: overflows}))
            );
        } else if (store.status != RouterStatus.Normal) {
            store.status = RouterStatus.Normal;
        }

        emit WithdrawSeniorSuccess(params.account, ticket.id, repayments, overflows);
    }

    function onWithdrawSeniorFailed(RouterStateStore storage store, Ticket storage ticket) public {
        SeniorWithdrawParams memory params = abi.decode(ticket.params, (SeniorWithdrawParams));
        IERC20Upgradeable(store.juniorVault.depositToken()).safeTransfer(
            address(store.juniorVault),
            params.removals
        );
        store.juniorVault.transferIn(params.removals);
        decreasePendingWithdrawal(store, params.account, params.shares);
        emit WithdrawSeniorFailed(params.account, ticket.id);
    }

    function increasePendingWithdrawal(
        RouterStateStore storage store,
        address account,
        uint256 shares
    ) internal {
        store.pendingSeniorWithdrawals[account] += shares;
        store.totalPendingSeniorWithdrawal += shares;
        emit IncreasePendingSeniorWithdrawal(
            account,
            shares,
            store.pendingSeniorWithdrawals[account],
            store.totalPendingSeniorWithdrawal
        );
    }

    function decreasePendingWithdrawal(
        RouterStateStore storage store,
        address account,
        uint256 shares
    ) internal {
        store.pendingSeniorWithdrawals[account] -= shares;
        store.totalPendingSeniorWithdrawal -= shares;
        emit DecreasePendingSeniorWithdrawal(
            account,
            shares,
            store.pendingSeniorWithdrawals[account],
            store.totalPendingSeniorWithdrawal
        );
    }
}
