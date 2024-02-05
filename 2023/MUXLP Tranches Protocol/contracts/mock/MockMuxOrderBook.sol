// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "../interfaces/mux/IMuxLiquidityPool.sol";
import "../interfaces/mux/IMuxLiquidityCallback.sol";

contract MockMuxOrderBook {
    struct Order {
        uint8 assetId;
        uint96 rawAmount;
        bool isAdding;
        address receiver;
    }

    uint64 public nextOrderId;

    address public mlp;
    address public pool;
    address public callback;

    mapping(uint64 => Order) orders;

    constructor(address mlp_, address pool_) {
        mlp = mlp_;
        pool = pool_;
        nextOrderId = 1;
    }

    function liquidityLockPeriod() external pure returns (uint32) {
        return 15 * 60;
    }

    function placeLiquidityOrder(
        uint8 assetId,
        uint96 rawAmount, // erc20.decimals
        bool isAdding
    ) external payable {
        if (isAdding) {
            address token = IMuxLiquidityPool(pool).getAssetInfo(assetId).tokenAddress;
            require(token != address(0), "assetId not found");
            IERC20Upgradeable(token).transferFrom(msg.sender, address(this), rawAmount);
        } else {
            IERC20Upgradeable(mlp).transferFrom(msg.sender, address(this), rawAmount);
        }
        orders[nextOrderId] = Order(assetId, rawAmount, isAdding, msg.sender);
        nextOrderId += 1;
    }

    function setFillCallback(address callback_) external {
        callback = callback_;
    }

    function fillLiquidityOrder(uint64 orderId, uint256 price) external {
        if (orders[orderId].isAdding) {
            // rawAmount => assetAmount
            uint256 assetAmount = (uint256(orders[orderId].rawAmount) * 1e18) / price;
            IERC20Upgradeable(mlp).transfer(orders[orderId].receiver, assetAmount);
            IMuxLiquidityCallback(callback).afterFillLiquidityOrder(
                IMuxLiquidityCallback.LiquidityOrder(
                    orderId,
                    orders[orderId].receiver,
                    orders[orderId].rawAmount,
                    orders[orderId].assetId,
                    orders[orderId].isAdding,
                    0
                ),
                assetAmount,
                1e6,
                uint96(price),
                0,
                0
            );
        } else {
            // rawAmount => stableAmount
            address token = IMuxLiquidityPool(pool)
                .getAssetInfo(orders[orderId].assetId)
                .tokenAddress;
            require(token != address(0), "assetId not found");
            uint256 stableAmount = (uint256(orders[orderId].rawAmount) * price) / 1e18;
            IERC20Upgradeable(token).transfer(orders[orderId].receiver, stableAmount);
            IMuxLiquidityCallback(callback).afterFillLiquidityOrder(
                IMuxLiquidityCallback.LiquidityOrder(
                    orderId,
                    orders[orderId].receiver,
                    orders[orderId].rawAmount,
                    orders[orderId].assetId,
                    orders[orderId].isAdding,
                    0
                ),
                stableAmount,
                1e6,
                uint96(price),
                0,
                0
            );
        }
        delete orders[orderId];
    }

    function cancelLiquidityOrder(uint64 orderId) external {
        if (orders[orderId].isAdding) {
            address token = IMuxLiquidityPool(pool)
                .getAssetInfo(orders[orderId].assetId)
                .tokenAddress;
            require(token != address(0), "assetId not found");
            require(
                IERC20Upgradeable(token).balanceOf(address(this)) >= orders[orderId].rawAmount,
                "A"
            );
            IERC20Upgradeable(token).transfer(orders[orderId].receiver, orders[orderId].rawAmount);
            IMuxLiquidityCallback(callback).afterCancelLiquidityOrder(
                IMuxLiquidityCallback.LiquidityOrder(
                    orderId,
                    orders[orderId].receiver,
                    orders[orderId].rawAmount,
                    orders[orderId].assetId,
                    orders[orderId].isAdding,
                    0
                )
            );
        } else {
            require(
                IERC20Upgradeable(mlp).balanceOf(address(this)) >= orders[orderId].rawAmount,
                "A"
            );
            IERC20Upgradeable(mlp).transfer(orders[orderId].receiver, orders[orderId].rawAmount);
            IMuxLiquidityCallback(callback).afterCancelLiquidityOrder(
                IMuxLiquidityCallback.LiquidityOrder(
                    orderId,
                    orders[orderId].receiver,
                    orders[orderId].rawAmount,
                    orders[orderId].assetId,
                    orders[orderId].isAdding,
                    0
                )
            );
        }
        delete orders[orderId];
    }
}
