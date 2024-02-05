// SPDX-License-Identifier: MIT

// The Dublr token (symbol: DUBLR), with a built-in distributed exchange for buying/selling tokens.
// By Hiroshi Yamamoto.
// 虎穴に入らずんば虎子を得ず。
//
// Officially hosted at: https://github.com/dublr/dublr

pragma solidity ^0.8.15;

import "./OmniToken.sol";

/**
 * @title DublrInternal
 * @dev Utility functions for the Dublr token and distributed exchange.
 * @author Hiroshi Yamamoto
 */
abstract contract DublrInternal is OmniToken {

    // -----------------------------------------------------------------------------------------------------------------
    // API enablement (needed in case a security issue is discovered with one of the APIs after the contract is created)

    /** @dev true if minting is enabled. */
    bool internal mintingEnabled = true;

    /** @dev true if buying is enabled on the built-in distributed exchange. */
    bool internal buyingEnabled = true;

    /** @dev true if selling is enabled on the built-in distributed exchange. */
    bool internal sellingEnabled = true;

    /**
     * @notice Only callable by the owner/deployer of the contract.
     *
     * @dev Enable or disable minting.
     */
    function _owner_enableMinting(bool enable) external ownerOnly { mintingEnabled = enable; }

    /**
     * @notice Only callable by the owner/deployer of the contract.
     *
     * @dev Enable or disable selling on the built-in distributed exchange.
     */
    function _owner_enableSelling(bool enable) external ownerOnly { sellingEnabled = enable; }

    /**
     * @notice Only callable by the owner/deployer of the contract.
     *
     * @dev Enable or disable buying on the built-in distributed exchange.
     * `_owner_enableBuying(false)` disables buying but not minting, so `buy()` will still work
     * unless minting is also disabled.
     */
    function _owner_enableBuying(bool enable) external ownerOnly { buyingEnabled = enable; }

    // -----------------------------------------------------------------------------------------------------------------
    // Constants

    /** @dev Mint price doubling period: 90 days. */
    uint256 internal constant DOUBLING_PERIOD_DAYS = 90;

    /** @dev Doublings per year = 4.05 ~= 4 => mint price increase factor per year = ~2^4 = ~16. */
    uint256 internal constant DOUBLING_PERIOD_SEC = DOUBLING_PERIOD_DAYS * 24 * 60 * 60;

    /**
     * @dev Num doubling periods: 30 (7.5 years * 4 doublings per year) => max mint price increase factor is
     * 2^30 = ~1B, although minting should end organically before then due to increased supply of sell orders
     * below the mint price. (See forward-looking statement disclaimer in README.md .)
     */
    uint256 internal constant NUM_DOUBLING_PERIODS = 30;

    /** @dev The number of seconds during which the mint price continues to double. */
    uint256 internal constant MAX_DOUBLING_TIME_SEC = DOUBLING_PERIOD_SEC * NUM_DOUBLING_PERIODS;

    /** @dev The value of 1 for fixed point calculation of number of doublings over time. */
    uint256 internal constant FIXED_POINT = 1 << 30;

    /** @dev The value of ln(2)*FIXED_POINT == ln(2)*(1<<30). */
    uint256 internal constant LN2_FIXED_POINT = 0x2c5c85fe;

    /** @dev The trading fee of 0.1%, = 0.001*(1<<30). */
    uint256 internal constant TRADING_FEE_FIXED_POINT = 0x10624e;

    /**
     * @dev The maximum number of sell orders that can be bought at once, to prevent uncontrolled resource consumption
     * DoS attacks. See: https://swcregistry.io/docs/SWC-128
     */
    uint256 internal constant MAX_SELL_ORDERS_PER_BUY = 20;

    // -----------------------------------------------------------------------------------------------------------------
    // Minting values set by the constructor

    /** @dev The price of 1 DUBLR in ETH, times 1e9, when the constructor was called. */
    uint256 internal initialMintPriceETHPerDUBLR_x1e9;

    /** @dev The timestamp when the constructor was called. */
    uint256 internal initialMintTimestamp;

    // -----------------------------------------------------------------------------------------------------------------
    // The distributed exchange orderbook

    /** @dev An orderbook entry (for a sell order). */
    struct Order {
        address seller;
        uint256 timestamp;
        uint256 priceETHPerDUBLR_x1e9;
        uint256 amountDUBLRWEI;
    }

    /** @dev The heap (to enforce increasing order of price for orderbook entry removal). */
    Order[] internal orderBook;

    /**
     * @dev The order book: mapping from address to (heap index + 1) if there is a current active sell order
     * for this address in the heap. (Need to add one because heap storage starts at index 0, but zero values
     * cannot be disambiguated from non-existence in a mapping.)
     *
     * The use of this mapping guarantees O(log N) removal time for removing an order by address.
     *
     * This data structure only allows us to have zero orders or one order per address at any given time.
     * It would be significantly more complex to create an orderbook where each user can have multiple active
     * orders at any given time, and still keep all order book access to O(log N) time.
     */
    mapping(address => uint256) internal sellerToHeapIdxPlusOne;

    // -----------------------------------------------------------------------------------------------------------------
    // Orderbook heap management functions

    /**
     * @dev Compare two orderbook entries, first by price, then (as a tiebreaker) by timestamp.
     * This is used to ensure that the cheapest orders are sold first, and when there is a tie,
     * the oldest order is sold first. (Does not compare amount, only compares price and timestamp.)
     *
     * @return diff -1 if order0 < order1, 0 if order0 == order1, 1 if order0 > order1, according to
     *         the above criteria.
     */
    function compare(Order memory order0, Order memory order1) private pure returns (int diff) {
        return order0.priceETHPerDUBLR_x1e9 < order1.priceETHPerDUBLR_x1e9 ? int(-1)
               : order0.priceETHPerDUBLR_x1e9 > order1.priceETHPerDUBLR_x1e9 ? int(1)
               : order0.timestamp < order1.timestamp ? int(-1)
               : order0.timestamp > order1.timestamp ? int(1)
               : int(0);
    }

    /**
     * @dev Set an entry in the orderbook min-heap, also updating the seller-to-heap-index mapping
     * sellerToHeapIdxPlusOne[order.seller].
     *
     * @param heapIdx The position to set the order.
     * @param order The order to set at the position.
     */
    function setOrder(uint256 heapIdx, Order memory order) private {
        require(heapIdx <= orderBook.length, "heapIdx");  // Sanity check
        if (heapIdx == orderBook.length) {
            orderBook.push(order);
        } else {
            orderBook[heapIdx] = order;
        }
        sellerToHeapIdxPlusOne[order.seller] = heapIdx + 1;
    }

    /**
     * @dev Standard up-heap algorithm for moving an order up a heap into its correct position.
     * (Heap is a min-heap, ordered by priceETHPerDUBLR_x1e9, then by timestamp.)
     *
     * @param orderToMove The order to bubble up the heap
     * @param startHeapIdx The heap index to start bubbling up the heap from. (The order at this index
     * is ignored -- it is treated as a "hole".)
     */
    function upHeap(Order memory orderToMove, uint256 startHeapIdx) private {
        uint256 i = startHeapIdx;
        while (i > 0) {
            uint256 parentI;
            unchecked { parentI = (i - 1) / 2; }  // Save gas by using unchecked
            Order memory parentOrder = orderBook[parentI];
            if (compare(parentOrder, orderToMove) <= 0) {
                // Stop moving up heap once the parent order has a smaller value than the order to be inserted
                break;
            }
            // Move parent order down into position `i`, leaving a "hole" where the parent was
            setOrder(i, parentOrder);
            // Move up the heap
            i = parentI;
        }
        // Overwrite the "hole" at the final position with orderToMove
        setOrder(i, orderToMove);
    }

    /**
     * @dev Standard down-heap algorithm for moving an order down a heap into its correct position.
     * (Heap is a min-heap, ordered by priceETHPerDUBLR_x1e9, then by timestamp.)
     *
     * @param orderToMove The order to percolate down the heap
     * @param startHeapIdx The heap index to start percolating down the heap from. (The order at this index
     * is ignored -- it is treated as a "hole".)
     */
    function downHeap(Order memory orderToMove, uint256 startHeapIdx) private {
        uint256 i = startHeapIdx;
        while (true) {
            // Get the index of the left and right child
            uint256 leftI;
            unchecked { leftI = 2 * i + 1; }  // Save gas (it would be impossibly expensive to ever cause overflow)
            if (leftI >= orderBook.length) {
                // Stop when node has no children
                break;
            }
            uint256 rightI;
            unchecked { rightI = leftI + 1; }  // Save gas
            // Choose child with lower priceETHPerDUBLR_x1e9 (or older child, if children have same price)
            // -- this preserves the min-heap property relative to the other child, if the child with
            // a lower price or older order timestamp is moved up to the parent position
            uint256 smallerChildI = rightI < orderBook.length && compare(orderBook[rightI], orderBook[leftI]) < 0
                    ? rightI : leftI;
            Order memory smallerChildOrder = orderBook[smallerChildI];
            if (compare(orderToMove, smallerChildOrder) < 0) {
                // Stop when the correct insertion point for orderToMove is found
                break;
            }
            // Insertion point for orderToMove has not yet been found -- move child up into empty
            // parent position (this leaves child entry empty), as parent for next iteration)
            setOrder(i, smallerChildOrder);
            // Move to child entry
            i = smallerChildI;
        }
        // Overwrite the "hole" in the heap at the final position with orderToMove
        setOrder(i, orderToMove);
    }

    /**
     * @dev Insert a new sell order into the orderbook min-heap.
     *
     * @param order The sell order to insert into the heap.
     */
    function heapInsert(Order memory order) internal {
        // Insert order at the end of the heap, then bubble up into correct position
        upHeap(order, orderBook.length);
    }

    /**
     * @dev Remove an entry from the orderbook min-heap by index.
     *
     * (Min-heap is ordered by priceETHPerDUBLR_x1e9, then by timestamp.)
     *
     * @param heapIdx The index of the heap entry to remove and return.
     * @return removedOrder The order at the given heap index.
     */
    function heapRemove(uint256 heapIdx) internal returns (Order memory removedOrder) {
        require(orderBook.length > 0, "Empty heap");  // Sanity check
        require(heapIdx < orderBook.length, "heapIdx");  // Sanity check
        // Set element to be removed as return value
        removedOrder = orderBook[heapIdx];
        // After removing this order, there are no other orders for the seller (sellers can have only one
        // sell order at a given time)
        delete sellerToHeapIdxPlusOne[removedOrder.seller];
        // Last element in heap must be inserted into the space vacated by deletion of removedOrder,
        // then moved into position via down-heap (percolate down) operation
        uint256 lastOrderIdx;
        unchecked { lastOrderIdx = orderBook.length - 1; }  // Checked by require above
        Order memory lastOrder = orderBook[lastOrderIdx];
        // Remove lastOrder from the end of the array
        orderBook.pop();
        // if (heapIdx == lastOrderIdx), then removed order is at end of array (i.e. removedOrder == lastOrder)
        // -- just return the removed order
        if (heapIdx != lastOrderIdx) {
            // Otherwise determine whether lastOrder needs to be bubbled up the heap or percolated down the heap
            // from the hole vacated by removedOrder
            if (heapIdx > 0 && compare(lastOrder, orderBook[(heapIdx - 1) / 2]) < 0) {
                // removedOrder had a parent (wasn't the root node of the heap), and lastOrder has a value
                // less than removedOrder's parent's value, so run up-heap algorithm
                upHeap(lastOrder, heapIdx);
            } else {
                // Otherwise (if removedOrder was at the root of the heap or lastOrder has a value greater than
                // or equal to removedOrder's parent's value), then run down-heap algorithm
                downHeap(lastOrder, heapIdx);
            }
        }
    }

    // -----------------------------------------------------------------------------------------------------------------
    // Send ETH to address

    /**
     * @dev Send an amount of ETH to a given address.
     *
     * @param recipient The address to send ETH to.
     * @param amountETH The amount of ETH (in wei) to send to the recipient.
     * @param errorMessageOnFail The error message to revert with if the ETH payment couldn't be sent,
     *              or empty if the transaction should not revert if the send fails.
     * @return success `true` if the send succeeded, or `false` if `errorMessageOnFail` is empty and the send failed.
     * @return returnData Any data returned from a failed call, if `success == false`.
     */
    function sendETH(address recipient, uint256 amountETH, string memory errorMessageOnFail)
            // Use extCaller modifier for reentrancy protection
            internal extCaller returns (bool success, bytes memory returnData) {
        require(recipient != address(0), "Bad recipient");
        if (amountETH > 0) {
            // Calls the `receive` or `fallback` function with the specified amount of ETH (if a contract).
            // For contracts, the argument of "" delivers a zero-length payload to the call. Function calls
            // must be at least 4 bytes long, for the function selector. Solidity 0.6.0 and above will
            // call the `receive()` function if `msg.data.length == 0`, otherwise they will call the
            // `fallback()` function if `msg.data.length > 0` or there is no `receive()` function defined.
            // If there is no `receive()` or `fallback()` function defined, and the recipient is a contract,
            // then send will revert. For contracts compiled on older versions of solidity, zero-length
            // payloads will simply trigger the `fallback()` function -- there is no `receive()` function.
            // `call` automatically succeeds if the recipient is an EOA.
            (success, returnData) = callContractFunction(
                    recipient, amountETH, /* abiEncoding = */ "", errorMessageOnFail);
        } else {
            return (true, "");
        }
    }

    // -----------------------------------------------------------------------------------------------------------------
    // Math functions

    /**
     * @dev Divide, rounding up to nearest integer.
     * Roughly equivalent to ceil((double) numerator / (double) denominator).
     */
    function divRoundUp(uint256 numerator, uint256 denominator) internal pure returns (uint256) {
        return (numerator + denominator - 1) / denominator;
    }

    /** @dev Return the minimum of two values. */
    function min(uint256 a, uint256 b) internal pure returns (uint256) {
        return a < b ? a : b;
    }

    /** @dev Convert DUBLR to ETH. */
    function dublrToEthRoundUpClamped(uint256 dublrAmt, uint256 priceETHPerDUBLR_x1e9, uint256 maxEthAmt)
            internal pure returns (uint256) {
        uint256 ethAmt = (dublrAmt * priceETHPerDUBLR_x1e9 + 1e9 - 1) / 1e9;
        return ethAmt < maxEthAmt ? ethAmt : maxEthAmt;
    }

    /** @dev Convert DUBLR to ETH. */
    function dublrToEthRoundDown(uint256 dublrAmt, uint256 priceETHPerDUBLR_x1e9) internal pure returns (uint256) {
        return dublrAmt * priceETHPerDUBLR_x1e9 / 1e9;
    }

    /** @dev Convert ETH to DUBLR. */
    function ethToDublrRoundDown(uint256 ethAmt, uint256 priceETHPerDUBLR_x1e9) internal pure returns (uint256) {
        return ethAmt * 1e9 / priceETHPerDUBLR_x1e9;
    }
}

