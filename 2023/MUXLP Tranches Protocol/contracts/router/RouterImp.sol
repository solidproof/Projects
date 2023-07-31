// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

import "../libraries/LibConfigSet.sol";
import "../libraries/LibUniswap.sol";

import "./UtilsImp.sol";
import "./TicketImp.sol";
import "./AdapterImp.sol";
import "./Type.sol";
import "./RouterJuniorImp.sol";
import "./RouterSeniorImp.sol";
import "./RouterRewardImp.sol";

library RouterImp {
    using UtilsImp for RouterStateStore;
    using TicketImp for RouterStateStore;
    using AdapterImp for RouterStateStore;
    using RouterJuniorImp for RouterStateStore;
    using RouterSeniorImp for RouterStateStore;
    using RouterRewardImp for RouterStateStore;
    using LibConfigSet for LibConfigSet.ConfigSet;
    using LibTypeCast for bytes32;
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using EnumerableSetUpgradeable for EnumerableSetUpgradeable.UintSet;

    event Rebalance(
        bool isBalanced_,
        bool isBorrow,
        uint256 delta,
        uint64 ticketId,
        uint256 assets
    );
    event Liquidate(uint256 balance, uint64 ticketId);

    function initialize(
        RouterStateStore storage store,
        address seniorVault,
        address juniorVault,
        address rewardController
    ) public {
        require(seniorVault != address(0), "RouterImp::INVALID_ADDRESS");
        require(juniorVault != address(0), "RouterImp::INVALID_ADDRESS");
        require(rewardController != address(0), "RouterImp::INVALID_ADDRESS");
        // skip 0
        store.ticket.nextId = 1;
        store.seniorVault = ISeniorVault(seniorVault);
        store.juniorVault = IJuniorVault(juniorVault);
        store.rewardController = IRewardController(rewardController);
    }

    function depositJunior(
        RouterStateStore storage store,
        address account,
        uint256 assets
    ) public returns (uint256 shares) {
        require(store.status == RouterStatus.Normal, "RouterImp::STATUS");
        shares = store.depositJunior(account, assets);
    }

    function withdrawJunior(
        RouterStateStore storage store,
        address account,
        uint256 shares
    ) public {
        require(store.status == RouterStatus.Normal, "RouterImp::STATUS");
        store.withdrawJunior(account, shares);
    }

    function depositSenior(
        RouterStateStore storage store,
        address account,
        uint256 assets
    ) public returns (uint256 shares) {
        require(store.status == RouterStatus.Normal, "RouterImp::STATUS");
        shares = store.depositSenior(account, assets);
    }

    function withdrawSenior(
        RouterStateStore storage store,
        address account,
        uint256 shares,
        bool acceptPenalty
    ) public {
        require(store.status == RouterStatus.Normal, "RouterImp::STATUS");
        store.withdrawSenior(account, shares, acceptPenalty);
    }

    // =============================================== Liquidate ===============================================
    function juniorLeverage(
        RouterStateStore storage store,
        uint256 seniorPrice,
        uint256 juniorPrice
    ) public view returns (uint256 leverage) {
        require(juniorPrice != 0, "RouterImp::INVALID_PRICE");
        require(seniorPrice != 0, "RouterImp::INVALID_PRICE");
        uint256 totalBorrows = store.seniorBorrows();
        if (totalBorrows == 0) {
            return ONE;
        }
        uint256 asset = store.juniorVault.totalAssets();
        uint256 debtAsset = (store.toJuniorUnit(totalBorrows) * seniorPrice) / juniorPrice;
        if (asset <= debtAsset) {
            return type(uint256).max; // should be liquidated
        }
        uint256 principle = asset - debtAsset;
        return (asset * ONE) / principle;
    }

    // =============================================== Rebalance ===============================================
    function isJuniorBalanced(
        RouterStateStore storage store,
        uint256 seniorPrice,
        uint256 juniorPrice
    ) public view returns (bool isBalanced, bool isBorrow, uint256 delta) {
        uint256 targetLeverage = store.config.getUint256(TARGET_LEVERAGE);
        require(targetLeverage > ONE, "RouterImp::INVALID_LEVERAGE");
        uint256 threshold = store.config.getUint256(REBALANCE_THRESHOLD);
        uint256 assetUsd = (store.juniorVault.totalAssets() * juniorPrice) / ONE;
        uint256 borrowUsd = (store.toJuniorUnit(store.seniorBorrows()) * seniorPrice) / ONE;
        if (assetUsd > borrowUsd) {
            uint256 principleUsd = assetUsd - borrowUsd;
            uint256 targetBorrowUsd = (principleUsd * (targetLeverage - ONE)) / ONE;
            isBorrow = targetBorrowUsd >= borrowUsd;
            uint256 deltaUsd = isBorrow ? targetBorrowUsd - borrowUsd : borrowUsd - targetBorrowUsd;
            isBalanced = ((deltaUsd * ONE) / principleUsd) <= threshold;
            delta = store.toSeniorUnit((deltaUsd * ONE) / seniorPrice);
        } else {
            // wait for liquidation, not rebalanced
            isBalanced = true;
            isBorrow = false;
            delta = 0;
        }
    }

    function updateRewards(RouterStateStore storage store) public {
        store.updateRewards(address(0));
        store.juniorVault.adjustVesting();
    }

    function rebalance(
        RouterStateStore storage store,
        uint256 seniorPrice,
        uint256 juniorPrice
    ) public {
        require(store.status == RouterStatus.Normal, "RouterImp::STATUS");
        (bool isBalanced_, bool isBorrow, uint256 delta) = isJuniorBalanced(
            store,
            seniorPrice,
            juniorPrice
        );
        require(!isBalanced_, "RouterImp::BALANCED");
        // decimal 18 => decimals of senior asset
        if (isBorrow) {
            uint256 borrowable = store.seniorVault.borrowable(address(this));
            delta = MathUpgradeable.min(borrowable, delta);
            store.seniorVault.borrow(delta);
            Ticket storage ticket = store.createTicket(
                Action.DepositJunior,
                abi.encode(DepositJuniorParams({assets: delta}))
            );
            uint64 orderId = store.placeAddOrder(delta);
            store.updateTicket(ticket, orderId, Status.Pending);
            emit Rebalance(isBalanced_, isBorrow, delta, ticket.id, 0);
        } else {
            uint256 assets = store.estimateMaxIn(delta);
            Ticket storage ticket = store.createTicket(
                Action.WithdrawSenior,
                abi.encode(
                    SeniorWithdrawParams({
                        caller: address(0),
                        account: address(0),
                        shares: 0,
                        removals: assets,
                        minRepayments: delta
                    })
                )
            );
            store.juniorVault.transferOut(assets);
            uint64 orderId = store.placeRemoveOrder(assets);
            store.updateTicket(ticket, orderId, Status.Pending);
            emit Rebalance(isBalanced_, isBorrow, delta, ticket.id, assets);
        }
        store.status = RouterStatus.Rebalance;
    }

    function liquidate(
        RouterStateStore storage store,
        uint256 seniorPrice,
        uint256 juniorPrice
    ) public {
        require(store.status == RouterStatus.Normal, "RouterImp::STATUS");
        uint256 leverage = juniorLeverage(store, seniorPrice, juniorPrice);
        uint256 maxLeverage = store.config.getUint256(LIQUIDATION_LEVERAGE);
        require(leverage > maxLeverage, "RouterImp::NOT_LIQUIDATABLE");
        cancelAllTickets(store);
        uint256 totalBalance = store.juniorVault.totalAssets();
        Ticket storage ticket = store.createTicket(
            Action.WithdrawSenior,
            abi.encode(
                SeniorWithdrawParams({
                    caller: address(0),
                    account: address(0),
                    shares: 0,
                    removals: totalBalance,
                    minRepayments: 0
                })
            )
        );
        store.juniorVault.transferOut(totalBalance);
        uint64 orderId = store.placeRemoveOrder(totalBalance);
        store.updateTicket(ticket, orderId, Status.Pending);
        store.status = RouterStatus.Liquidation;

        emit Liquidate(totalBalance, ticket.id);
    }

    // =============================================== Callbacks ===============================================
    function handleTicket(RouterStateStore storage store, uint64 ticketId) public {
        Ticket storage ticket = store.getTicket(ticketId);
        if (ticket.action == Action.DepositJunior) {
            store.handleDepositJunior(ticket);
        } else if (ticket.action == Action.WithdrawJunior) {
            store.handleWithdrawJunior(ticket);
        } else if (ticket.action == Action.WithdrawSenior) {
            store.handleWithdrawSenior(ticket);
        } else {
            revert("ImpRouter::INVALID_ACTION");
        }
    }

    function beforeOrderFilled(
        RouterStateStore storage store,
        MuxOrderContext memory context
    ) public view returns (bool) {
        Ticket storage ticket = store.getTicketByOrderId(context.orderId);
        if (ticket.action == Action.WithdrawJunior) {
            return store.beforeWithdrawJunior(context, ticket);
        } else if (ticket.action == Action.WithdrawSenior) {
            return store.beforeWithdrawSenior(context, ticket);
        }
        return true;
    }

    function onOrderFilled(
        RouterStateStore storage store,
        MuxOrderContext memory context,
        uint256 amountOut
    ) public {
        Ticket storage ticket = store.getTicketByOrderId(context.orderId);
        if (ticket.action == Action.DepositJunior) {
            store.onDepositJuniorSuccess(context, ticket, amountOut);
        } else if (ticket.action == Action.WithdrawJunior) {
            store.onWithdrawJuniorSuccess(context, ticket, amountOut);
        } else if (ticket.action == Action.WithdrawSenior) {
            store.onWithdrawSeniorSuccess(context, ticket, amountOut);
        } else {
            revert("InvalidOperation");
        }
        store.removeTicket(ticket);
    }

    function onOrderCancelled(RouterStateStore storage store, uint64 orderId) public {
        Ticket storage ticket = store.getTicketByOrderId(orderId);
        if (ticket.action == Action.WithdrawJunior) {
            store.onWithdrawJuniorFailed(ticket);
        } else if (ticket.action == Action.WithdrawSenior) {
            store.onWithdrawSeniorFailed(ticket);
        }
        store.updateTicket(ticket, 0, Status.Failed);
    }

    function getTicketCount(RouterStateStore storage store) internal view returns (uint256) {
        return store.ticket.ticketIds.length();
    }

    function getTickets(
        RouterStateStore storage store,
        uint256 begin,
        uint256 count
    ) internal view returns (Ticket[] memory tickets) {
        count = MathUpgradeable.min(count, getTicketCount(store) - begin);
        tickets = new Ticket[](count);
        for (uint256 i = 0; i < count; i++) {
            tickets[i] = store.ticket.tickets[uint64(store.ticket.ticketIds.at(i + begin))];
        }
    }

    function cancelAllTickets(RouterStateStore storage store) internal {
        uint256 length = store.ticket.ticketIds.length();
        for (uint256 i = 0; i < length; i++) {
            Ticket storage ticket = store.ticket.tickets[uint64(store.ticket.ticketIds.at(i))];
            store.cancelOrder(ticket.orderId);
            store.removeTicket(ticket);
        }
    }
}
