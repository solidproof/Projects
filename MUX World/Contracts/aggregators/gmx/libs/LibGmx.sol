// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

import "../../../interfaces/IGmxOrderBook.sol";
import "../../../interfaces/IGmxPositionRouter.sol";
import "../../../interfaces/IGmxVault.sol";
import "../../../interfaces/IWETH.sol";

import "../Type.sol";

library LibGmx {
    using SafeERC20 for IERC20;

    enum OrderCategory {
        NONE,
        OPEN,
        CLOSE,
        LIQUIDATE
    }

    enum OrderReceiver {
        PR_INC,
        PR_DEC,
        OB_INC,
        OB_DEC
    }

    struct OrderHistory {
        OrderCategory category; // 4
        OrderReceiver receiver; // 4
        uint64 index; // 64
        uint96 borrow; // 96
        uint88 timestamp; // 80
    }

    function getOraclePrice(
        ProjectConfigs storage projectConfigs,
        address token,
        bool useMaxPrice
    ) internal view returns (uint256 price) {
        // open long = max
        // open short = min
        // close long = min
        // close short = max
        price = useMaxPrice //isOpen == isLong
            ? IGmxVault(projectConfigs.vault).getMaxPrice(token)
            : IGmxVault(projectConfigs.vault).getMinPrice(token);
        require(price != 0, "ZeroOraclePrice");
    }

    function swap(
        ProjectConfigs memory projectConfigs,
        address tokenIn,
        address tokenOut,
        uint256 amountIn,
        uint256 minOut
    ) internal returns (uint256 amountOut) {
        IERC20(tokenIn).safeTransfer(projectConfigs.vault, amountIn);
        amountOut = IGmxVault(projectConfigs.vault).swap(tokenIn, tokenOut, address(this));
        require(amountOut >= minOut, "AmountOutNotReached");
    }

    function getOrderIndex(ProjectConfigs memory projectConfigs, OrderReceiver receiver)
        internal
        view
        returns (uint256 index)
    {
        if (receiver == OrderReceiver.PR_INC) {
            index = IGmxPositionRouter(projectConfigs.positionRouter).increasePositionsIndex(address(this));
        } else if (receiver == OrderReceiver.PR_DEC) {
            index = IGmxPositionRouter(projectConfigs.positionRouter).decreasePositionsIndex(address(this));
        } else if (receiver == OrderReceiver.OB_INC) {
            index = IGmxOrderBook(projectConfigs.orderBook).increaseOrdersIndex(address(this)) - 1;
        } else if (receiver == OrderReceiver.OB_DEC) {
            index = IGmxOrderBook(projectConfigs.orderBook).decreaseOrdersIndex(address(this)) - 1;
        }
    }

    function getOrder(ProjectConfigs memory projectConfigs, bytes32 key)
        internal
        view
        returns (bool isFilled, OrderHistory memory history)
    {
        history = decodeOrderHistoryKey(key);
        if (history.receiver == OrderReceiver.PR_INC) {
            IGmxPositionRouter.IncreasePositionRequest memory request = IGmxPositionRouter(
                projectConfigs.positionRouter
            ).increasePositionRequests(encodeOrderKey(address(this), history.index));
            isFilled = request.account == address(0);
        } else if (history.receiver == OrderReceiver.PR_DEC) {
            IGmxPositionRouter.DecreasePositionRequest memory request = IGmxPositionRouter(
                projectConfigs.positionRouter
            ).decreasePositionRequests(encodeOrderKey(address(this), history.index));
            isFilled = request.account == address(0);
        } else if (history.receiver == OrderReceiver.OB_INC) {
            (address collateralToken, , , , , , , , ) = IGmxOrderBook(projectConfigs.orderBook).getIncreaseOrder(
                address(this),
                history.index
            );
            isFilled = collateralToken == address(0);
        } else if (history.receiver == OrderReceiver.OB_DEC) {
            (address collateralToken, , , , , , , ) = IGmxOrderBook(projectConfigs.orderBook).getDecreaseOrder(
                address(this),
                history.index
            );
            isFilled = collateralToken == address(0);
        } else {
            revert();
        }
    }

    function cancelOrderFromPositionRouter(address positionRouter, bytes32 key) internal returns (bool success) {
        OrderHistory memory history = decodeOrderHistoryKey(key);
        success = false;
        if (history.receiver == OrderReceiver.PR_INC) {
            try
                IGmxPositionRouter(positionRouter).cancelIncreasePosition(
                    encodeOrderKey(address(this), history.index),
                    payable(address(this))
                )
            returns (bool _success) {
                success = _success;
            } catch {}
        } else if (history.receiver == OrderReceiver.PR_DEC) {
            try
                IGmxPositionRouter(positionRouter).cancelDecreasePosition(
                    encodeOrderKey(address(this), history.index),
                    payable(address(this))
                )
            returns (bool _success) {
                success = _success;
            } catch {}
        }
    }

    function cancelOrderFromOrderBook(address orderBook, bytes32 key) internal returns (bool success) {
        OrderHistory memory history = decodeOrderHistoryKey(key);
        success = false;
        if (history.receiver == OrderReceiver.OB_INC) {
            try IGmxOrderBook(orderBook).cancelIncreaseOrder(history.index) {
                success = true;
            } catch {}
        } else if (history.receiver == OrderReceiver.OB_DEC) {
            try IGmxOrderBook(orderBook).cancelDecreaseOrder(history.index) {
                success = true;
            } catch {}
        }
    }

    function cancelOrder(ProjectConfigs memory projectConfigs, bytes32 key) public returns (bool success) {
        OrderHistory memory history = decodeOrderHistoryKey(key);
        success = false;
        if (history.receiver == OrderReceiver.PR_INC) {
            try
                IGmxPositionRouter(projectConfigs.positionRouter).cancelIncreasePosition(
                    encodeOrderKey(address(this), history.index),
                    payable(address(this))
                )
            returns (bool _success) {
                success = _success;
            } catch {}
        } else if (history.receiver == OrderReceiver.PR_DEC) {
            try
                IGmxPositionRouter(projectConfigs.positionRouter).cancelDecreasePosition(
                    encodeOrderKey(address(this), history.index),
                    payable(address(this))
                )
            returns (bool _success) {
                success = _success;
            } catch {}
        } else if (history.receiver == OrderReceiver.OB_INC) {
            try IGmxOrderBook(projectConfigs.orderBook).cancelIncreaseOrder(history.index) {
                success = true;
            } catch {}
        } else if (history.receiver == OrderReceiver.OB_DEC) {
            try IGmxOrderBook(projectConfigs.orderBook).cancelDecreaseOrder(history.index) {
                success = true;
            } catch {}
        } else {
            revert();
        }
    }

    function getPnl(
        ProjectConfigs memory projectConfigs,
        address indexToken,
        uint256 size,
        uint256 averagePriceUsd,
        bool isLong,
        uint256 priceUsd,
        uint256 lastIncreasedTime
    ) public view returns (bool, uint256) {
        require(priceUsd > 0, "");
        uint256 priceDelta = averagePriceUsd > priceUsd ? averagePriceUsd - priceUsd : priceUsd - averagePriceUsd;
        uint256 delta = (size * priceDelta) / averagePriceUsd;
        bool hasProfit;
        if (isLong) {
            hasProfit = priceUsd > averagePriceUsd;
        } else {
            hasProfit = averagePriceUsd > priceUsd;
        }
        uint256 minProfitTime = IGmxVault(projectConfigs.vault).minProfitTime();
        uint256 minProfitBasisPoints = IGmxVault(projectConfigs.vault).minProfitBasisPoints(indexToken);
        uint256 minBps = block.timestamp > lastIncreasedTime + minProfitTime ? 0 : minProfitBasisPoints;
        if (hasProfit && delta * 10000 <= size * minBps) {
            delta = 0;
        }
        return (hasProfit, delta);
    }

    function encodeOrderKey(address account, uint256 index) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(account, index));
    }

    function decodeOrderHistoryKey(bytes32 key) internal pure returns (OrderHistory memory history) {
        //            252          248                184          88           0
        // +------------+------------+------------------+-----------+-----------+
        // | category 4 | receiver 4 | gmxOrderIndex 64 | borrow 96 |  time 88  |
        // +------------+------------+------------------+-----------+-----------+
        history.category = OrderCategory(uint8(bytes1(key)) >> 4);
        history.receiver = OrderReceiver(uint8(bytes1(key)) & 0x0f);
        history.index = uint64(bytes8(key << 8));
        history.borrow = uint96(uint256(key >> 88));
        history.timestamp = uint88(uint256(key));
    }

    function encodeOrderHistoryKey(
        OrderCategory category,
        OrderReceiver receiver,
        uint256 index,
        uint256 borrow,
        uint256 timestamp
    ) internal pure returns (bytes32 data) {
        //            252          248                184          88           0
        // +------------+------------+------------------+-----------+-----------+
        // | category 4 | receiver 4 | gmxOrderIndex 64 | borrow 96 |  time 88  |
        // +------------+------------+------------------+-----------+-----------+
        require(index < type(uint64).max, "GmxOrderIndexOverflow");
        require(borrow < type(uint96).max, "BorrowOverflow");
        require(timestamp < type(uint88).max, "FeeOverflow");
        data =
            bytes32(uint256(category) << 252) | // 256 - 4
            bytes32(uint256(receiver) << 248) | // 256 - 4 - 4
            bytes32(uint256(index) << 184) | // 256 - 4 - 4 - 64
            bytes32(uint256(borrow) << 88) | // 256 - 4 - 4 - 64 - 96
            bytes32(uint256(timestamp));
    }
}
