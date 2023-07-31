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

library RouterJuniorImp {
    using UtilsImp for RouterStateStore;
    using TicketImp for RouterStateStore;
    using AdapterImp for RouterStateStore;
    using RouterRewardImp for RouterStateStore;
    using LibConfigSet for LibConfigSet.ConfigSet;
    using LibTypeCast for bytes32;
    using SafeERC20Upgradeable for IERC20Upgradeable;

    event DepositJunior(address indexed account, uint256 assets, uint256 shares);
    event HandleDepositJunior(address indexed account, uint64 indexed ticketId, uint256 amountIn);
    event DepositJuniorSuccess(
        address indexed account,
        uint64 indexed ticketId,
        uint256 amountIn,
        uint256 amountOut
    );

    event WithdrawJuniorDelayed(address indexed account, uint64 indexed ticketId, uint256 shares);
    event HandleWithdrawJunior(address indexed account, uint64 indexed ticketId, uint256 borrows);
    event WithdrawSeniorSuccess(
        address indexed account,
        uint64 indexed ticketId,
        uint256 repayments,
        uint256 seniorAssets,
        uint256 juniorAssets
    );
    event WithdrawJuniorFailed(address indexed account, uint64 indexed ticketId);
    event IncreasePendingJuniorWithdrawal(
        address indexed account,
        uint256 shares,
        uint256 personalPendingWithdrawal,
        uint256 totalPendingWithdrawal
    );
    event DecreasePendingJuniorWithdrawal(
        address indexed account,
        uint256 shares,
        uint256 personalPendingWithdrawal,
        uint256 totalPendingWithdrawal
    );

    function depositJunior(
        RouterStateStore storage store,
        address account,
        uint256 assets
    ) public returns (uint256 shares) {
        require(assets > 0, "RouterJuniorImp::ZERO_AMOUNT");
        IERC20Upgradeable(store.juniorVault.depositToken()).safeTransferFrom(
            account,
            address(store.juniorVault),
            assets
        );
        store.updateRewards(account);
        shares = store.juniorVault.deposit(assets, account);
        emit DepositJunior(account, assets, shares);
    }

    function handleDepositJunior(RouterStateStore storage store, Ticket storage ticket) internal {
        require(
            ticket.status == Status.Init || ticket.status == Status.Failed,
            "RouterJuniorImp::STATUS"
        );
        DepositJuniorParams memory params = abi.decode(ticket.params, (DepositJuniorParams));
        uint64 orderId = store.placeAddOrder(params.assets);
        store.updateTicket(ticket, orderId, Status.Pending);
        emit HandleDepositJunior(address(0), ticket.id, params.assets);
    }

    function onDepositJuniorSuccess(
        RouterStateStore storage store,
        MuxOrderContext memory,
        Ticket storage ticket,
        uint256 amountOut
    ) public {
        DepositJuniorParams memory params = abi.decode(ticket.params, (DepositJuniorParams));
        IERC20Upgradeable(store.juniorVault.depositToken()).safeTransfer(
            address(store.juniorVault),
            amountOut
        );
        store.juniorVault.transferIn(amountOut);
        if (store.status != RouterStatus.Normal) {
            store.status = RouterStatus.Normal;
        }
        emit DepositJuniorSuccess(address(0), ticket.id, params.assets, amountOut);
    }

    // =============================================== Withdraw Junior ===============================================
    function juniorWithdrawable(
        RouterStateStore storage store,
        address account
    ) internal view returns (uint256) {
        return store.juniorVault.balanceOf(account);
    }

    function withdrawJunior(
        RouterStateStore storage store,
        address account,
        uint256 shares
    ) public {
        require(shares > 0, "RouterJuniorImp::ZERO_AMOUNT");
        require(
            shares <= juniorWithdrawable(store, account),
            "RouterJuniorImp::EXCEEDS_REDEEMABLE"
        );
        Ticket storage ticket = store.createTicket(
            Action.WithdrawJunior,
            abi.encode(
                JuniorWithdrawParams({
                    caller: msg.sender,
                    account: account,
                    shares: shares,
                    debts: 0,
                    assets: 0,
                    removals: 0
                })
            )
        );
        // the status of ticket should be init
        emit WithdrawJuniorDelayed(account, ticket.id, shares);
        handleWithdrawJunior(store, ticket);
        // the status of ticket should be pending
    }

    function handleWithdrawJunior(RouterStateStore storage store, Ticket storage ticket) public {
        require(
            ticket.status == Status.Init || ticket.status == Status.Failed,
            "RouterJuniorImp::INVALID_STATUS"
        );
        // estimate repay
        JuniorWithdrawParams memory params = abi.decode(ticket.params, (JuniorWithdrawParams));
        uint256 borrows = store.seniorVault.borrows(address(this));
        params.debts = ((borrows * params.shares) / store.juniorVault.totalSupply());
        params.removals = store.estimateMaxIn(params.debts);
        store.updateRewards(params.account);
        params.assets = store.juniorVault.withdraw(
            params.account,
            params.account,
            params.shares,
            address(this)
        );
        require(params.assets >= params.removals, "ImpRouter::UNSAFE");
        uint64 orderId = store.placeRemoveOrder(params.removals);
        store.updateTicket(ticket, orderId, Status.Pending, abi.encode(params));
        increasePendingWithdrawal(store, params.account, params.shares);

        emit HandleWithdrawJunior(params.account, ticket.id, borrows);
    }

    function beforeWithdrawJunior(
        RouterStateStore storage store,
        MuxOrderContext memory context,
        Ticket storage ticket
    ) public view returns (bool) {
        JuniorWithdrawParams memory params = abi.decode(ticket.params, (JuniorWithdrawParams));
        uint256 seniorAmountOut = store.estimateExactOut(
            context.seniorAssetId,
            params.removals,
            context.seniorPrice,
            context.juniorPrice,
            context.currentSeniorValue,
            context.targetSeniorValue
        );
        return seniorAmountOut >= params.debts;
    }

    function onWithdrawJuniorSuccess(
        RouterStateStore storage store,
        MuxOrderContext memory context,
        Ticket storage ticket,
        uint256 amountOut // senior token
    ) public {
        require(ticket.action != Action.Invalid, "ImpJunior::INVALID_ACTION");
        JuniorWithdrawParams memory params = abi.decode(ticket.params, (JuniorWithdrawParams));
        uint256 repayments = params.debts;
        uint256 totalDebt = store.seniorBorrows();
        uint256 juniorOut = params.assets - params.removals;
        // 0. virtual swap
        if (amountOut > repayments && totalDebt > 0) {
            // the junior amount we removed is always more than the expected amount
            // since we have exact junior and senior prices
            // we do a virtual swap, turning the extra output to junior token
            // to avoid the case that junior user receives both junior and senior token after withdrawal
            uint256 swapIn = MathUpgradeable.min(amountOut - repayments, totalDebt);
            uint256 swapOut = store.toJuniorUnit(
                (swapIn * context.seniorPrice) / context.juniorPrice
            );
            if (store.juniorVault.totalAssets() > swapOut) {
                store.juniorVault.transferOut(swapOut);
                repayments += swapIn;
                juniorOut += swapOut;
            }
        }
        // 1. repay
        if (repayments > 0) {
            IERC20Upgradeable(store.seniorVault.depositToken()).safeTransfer(
                address(store.seniorVault),
                repayments
            );
            store.seniorVault.repay(repayments);
        }
        // 2. refund if possible
        uint256 seniorOut = amountOut - repayments;
        if (seniorOut > 0) {
            IERC20Upgradeable(store.seniorVault.depositToken()).safeTransfer(
                params.account, // junior user
                seniorOut
            );
        }
        // 3. withdraw mlp
        if (juniorOut > 0) {
            IERC20Upgradeable(store.juniorVault.depositToken()).safeTransfer(
                params.account, // junior user
                juniorOut
            );
        }
        decreasePendingWithdrawal(store, params.account, params.shares);
        emit WithdrawSeniorSuccess(params.account, ticket.id, repayments, seniorOut, juniorOut);
    }

    function onWithdrawJuniorFailed(RouterStateStore storage store, Ticket storage ticket) public {
        JuniorWithdrawParams memory params = abi.decode(ticket.params, (JuniorWithdrawParams));
        IERC20Upgradeable(store.juniorVault.depositToken()).safeTransfer(
            address(store.juniorVault),
            params.assets
        );
        store.updateRewards(params.account);
        store.juniorVault.deposit(params.assets, params.account);
        decreasePendingWithdrawal(store, params.account, params.shares);
        emit WithdrawJuniorFailed(params.account, ticket.id);
    }

    function increasePendingWithdrawal(
        RouterStateStore storage store,
        address account,
        uint256 shares
    ) internal {
        store.pendingJuniorWithdrawals[account] += shares;
        store.totalPendingJuniorWithdrawal += shares;
        emit IncreasePendingJuniorWithdrawal(
            account,
            shares,
            store.pendingJuniorWithdrawals[account],
            store.totalPendingJuniorWithdrawal
        );
    }

    function decreasePendingWithdrawal(
        RouterStateStore storage store,
        address account,
        uint256 shares
    ) internal {
        store.pendingJuniorWithdrawals[account] -= shares;
        store.totalPendingJuniorWithdrawal -= shares;
        emit DecreasePendingJuniorWithdrawal(
            account,
            shares,
            store.pendingJuniorWithdrawals[account],
            store.totalPendingJuniorWithdrawal
        );
    }
}
