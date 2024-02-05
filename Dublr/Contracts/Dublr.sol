// SPDX-License-Identifier: MIT

// The Dublr token (symbol: DUBLR), with a built-in distributed exchange for buying/selling tokens.
// By Hiroshi Yamamoto.
// 虎穴に入らずんば虎子を得ず。
//
// Officially hosted at: https://github.com/dublr/dublr

pragma solidity ^0.8.15;

import "./DublrInternal.sol";
import "./interfaces/IDublrDEX.sol";

/**
 * @title Dublr
 * @dev The Dublr token and distributed exchange
 * @author Hiroshi Yamamoto
 */
contract Dublr is DublrInternal, IDublrDEX {

    // -----------------------------------------------------------------------------------------------------------------
    // Constructor

    /**
     * @dev Constructor.
     * @param initialMintPrice_ETHPerDUBLR_x1e9 the numerator of the initial price of DUBLR in
     *          ETH per DUBLR token, multiplied by 1e9 (as a fixed point representation).
     * @param initialMintAmountDUBLR the one-time number of DUBLR tokens to mint for the owner on creation
     *          of the contract.
     */
    constructor(uint256 initialMintPrice_ETHPerDUBLR_x1e9, uint256 initialMintAmountDUBLR)
            OmniToken("Dublr", "DUBLR", "1", emptyAddressArray(), initialMintAmountDUBLR) {
        require(initialMintPrice_ETHPerDUBLR_x1e9 > 0 && initialMintAmountDUBLR > 0);
        
        // Record timestamp and initial mint price at contract creation time
        initialMintPriceETHPerDUBLR_x1e9 = initialMintPrice_ETHPerDUBLR_x1e9;
        // solhint-disable-next-line not-rely-on-time
        initialMintTimestamp = block.timestamp;

        // Register DUBLR token via ERC1820
        registerInterfaceViaERC1820("DUBLRToken", true);
        
        // Register IDublrDEX interface via ERC165
        registerInterfaceViaERC165(type(IDublrDEX).interfaceId, true);
    }

    // -----------------------------------------------------------------------------------------------------------------
    // Determine the current mint price, based on block timestamp

    /**
     * @notice The current mint price, in ETH per DUBLR (multiplied by `10**9`).
     *
     * @dev Returns the current mint price for this token. Calls to `buy()` will buy tokens for sale
     * rather than minting new tokens, if there are tokens listed below the current mint price.
     *
     * The mint price grows exponentially, doubling every 90 days for 30 doubling periods, and then minting
     * is disabled. In practice, minting may no longer be triggered long before that time, if the supply
     * of coins for sale below the mint price exceeds demand.
     *
     * @return mintPriceETHPerDUBLR_x1e9 The current mint price, in ETH per DUBLR, multiplied by `10**9`,
     *              or zero if the minting time period has ended (after 30 doubling periods).
     */
    function mintPrice() public view returns (uint256 mintPriceETHPerDUBLR_x1e9) {
        // This is only a polynomial approximation of 2^t, so the doubling is not quite precise.
        // Factor increase in mint price during 1st doubling period: 1.999528
        // Factor increase in mint price during 30th doubling period: 1.973042
        // Factor increase in mint price between initial mint price and price after 30th
        //     doubling period: 871819739 (0.87 billion, i.e. 19% less than 1<<30)

        // N.B. daily compound interest rate == exp(ln(2) / DOUBLING_PERIOD_DAYS)
        // == 1.00773 if DOUBLING_PERIOD_DAYS == 90 (compound interest rate is 0.77% per day)

        // Use the block timestamp as an estimate of the current time. It is possible for miners to spoof
        // this timestamp, but it must be greater than the parent block timestamp (according to the Ethereum
        // yellowpaper), and most clients reject timestamps more than 15 seconds in the future.
        // The mint price grows by only 0.77% per day, so adding 15 seconds won't change the value of the
        // mint price by much (up to 0.003%). Also, setting the timestamp ahead of the real time results
        // in a higher price, which is only disadvantageous for a would-be attacker. Therefore, using the
        // block timestamp is not problematic here.
        // solhint-disable-next-line not-rely-on-time
        uint256 t = block.timestamp - initialMintTimestamp;
        if (t > MAX_DOUBLING_TIME_SEC) {
            return 0;
        }

        // Given an exponential function that doubles as x increments by 1
        //
        //     p = 2**x
        //
        // then to rewrite this in base e, we have
        //
        //     p = e**(ln(2) x)
        //
        // since
        //
        //     e**y = 2  =>  y == ln(2)
        //
        // Therefore the factor increase in mint price since the contract was deployed is given by
        //
        //     p = e**(ln(2) t / DOUBLING_PERIOD_SEC)
        //
        // where t is time since the constructor was called, in seconds.
        //
        // Exponentiation may be approximated by a polynomial:
        //
        //     exp(x) = lim{n->inf} (1 + x/n)**n
        //
        // (we use n = 1024 for a reasonable approximation that is not too costly).
        //
        // The factor increase in price can therefore be approximated by
        //
        //     p = (1 + ln(2) t / DOUBLING_PERIOD_SEC)**1024
        //
        // This approximation is accurate to within 3% per doubling period, with the biggest error
        // at the latest (30th) doubling period.
        
        // Convert the value (ln(2) * t / DOUBLING_PERIOD_SEC) to fixed point
        uint256 x = LN2_FIXED_POINT * t / DOUBLING_PERIOD_SEC;
        // x = 1 + x/1024
        x = FIXED_POINT + x / 1024;
        // x = x**1024
        // slither-disable-next-line divide-before-multiply
        x = x * x / FIXED_POINT; // => x**2
        x = x * x / FIXED_POINT; // => x**4
        x = x * x / FIXED_POINT; // => x**8
        x = x * x / FIXED_POINT; // => x**16
        x = x * x / FIXED_POINT; // => ...
        x = x * x / FIXED_POINT;
        x = x * x / FIXED_POINT;
        x = x * x / FIXED_POINT;
        x = x * x / FIXED_POINT; // => ...
        x = x * x / FIXED_POINT; // => x**1024
        // x is now an estimate of p, the factor increase in price, in fixed point.
        // Multiply x by the initial mint price to get the current mint price in fixed point,
        // then convert back from fixed point
        return x * initialMintPriceETHPerDUBLR_x1e9 / FIXED_POINT;
    }
    
    // -----------------------------------------------------------------------------------------------------------------
    // Public functions for interacting with order book

    /**
     * @notice The number of sell orders in the order book.
     *
     * @return numEntries The number of entries in the order book.
     */
    function orderBookSize() external view override(IDublrDEX) returns (uint256 numEntries) {
        return orderBook.length;
    }

    /**
     * @notice The price of the cheapest sell order in the order book for any user.
     *
     * @dev If there are no current sell orders, reverts.
     *
     * @return priceETHPerDUBLR_x1e9 The price of DUBLR tokens in the cheapest sell order, in ETH per DUBLR
     *          (multiplied by `10**9`).
     * @return amountDUBLRWEI the number of DUBLR tokens for sale, in DUBLR wei (1 DUBLR = 10^18 DUBLR wei).
     */
    function cheapestSellOrder() external view override(IDublrDEX)
            returns (uint256 priceETHPerDUBLR_x1e9, uint256 amountDUBLRWEI) {
        require(orderBook.length > 0, "No sell order");
        Order storage order = orderBook[0];
        return (order.priceETHPerDUBLR_x1e9, order.amountDUBLRWEI);
    }

    /**
     * @notice The current sell order in the order book for the caller.
     *
     * @dev If the caller has no current sell order, reverts.
     *
     * @return priceETHPerDUBLR_x1e9 The price of DUBLR tokens in the caller's current sell order, in ETH per DUBLR
     *          (multiplied by `10**9`).
     * @return amountDUBLRWEI the number of DUBLR tokens for sale, in DUBLR wei (1 DUBLR = `10**18` DUBLR wei).
     */
    function mySellOrder() external view override(IDublrDEX)
            returns (uint256 priceETHPerDUBLR_x1e9, uint256 amountDUBLRWEI) {
        uint256 heapIdxPlusOne = sellerToHeapIdxPlusOne[msg.sender];
        require(heapIdxPlusOne > 0, "No sell order");
        uint256 heapIdx;
        unchecked { heapIdx = heapIdxPlusOne - 1; }  // Save gas
        
        // Peek at the order in the heap without removing it
        Order storage order = orderBook[heapIdx];
        require(order.seller == msg.sender, "Not seller");  // Sanity check
        
        return (order.priceETHPerDUBLR_x1e9, order.amountDUBLRWEI);
    }

    /**
     * @notice Cancel the caller's current sell order in the orderbook.
     *
     * @dev Restores the remaining (unfulfilled) amount of the caller's sell order back to the seller's
     * token balance. If the caller has no current sell order, reverts.
     */
    function cancelMySellOrder() public override(IDublrDEX) stateUpdater {
        // Determine the heap index of the sender's current sell order, if any
        uint256 heapIdxPlusOne = sellerToHeapIdxPlusOne[msg.sender];
        require(heapIdxPlusOne > 0, "No sell order");
        uint256 heapIdx;
        unchecked { heapIdx = heapIdxPlusOne - 1; }  // Save gas

        // Remove the order from the heap
        Order memory order = heapRemove(heapIdx);
        require(order.seller == msg.sender, "Not seller");  // Sanity check

        // Add the order amount of the canceled sell order back into the seller's balance
        balanceOf[order.seller] += order.amountDUBLRWEI;

        emit CancelSell(order.seller, order.priceETHPerDUBLR_x1e9, order.amountDUBLRWEI);
    }

    /**
     * @notice Get all sell orders in the orderbook.
     * 
     * @dev Note that the orders are returned in min-heap order by price, and not in increasing order by price.
     *
     * @return priceAndAmountOfSellOrders A list of all sell orders in the orderbook, in min-heap order by price.
     * Each list item is a tuple consisting of the price of each token in ETH per DUBLR (multiplied by `10**9`),
     * and the number of tokens for sale.
     */
    function allSellOrders() external view override(IDublrDEX)
            // Returning an array requires ABI encoder v2, which is the default in Solidity >=0.8.0.
            returns (PriceAndAmount[] memory priceAndAmountOfSellOrders) {
        require(orderBook.length > 0, "No sell order");
        priceAndAmountOfSellOrders = new PriceAndAmount[](orderBook.length);
        uint256 len = orderBook.length;
        for (uint256 i = 0; i < len; ) {
            Order storage order = orderBook[i];
            priceAndAmountOfSellOrders[i] = PriceAndAmount({
                    priceETHPerDUBLR_x1e9: order.priceETHPerDUBLR_x1e9,
                    amountDUBLRWEI: order.amountDUBLRWEI});
            unchecked { ++i; }  // Save gas
        }
    }

    /**
     * @notice Only callable by the owner/deployer of the contract.
     *
     * @dev Cancel all sell orders (in case of emergency).
     * Restores the remaining (unfulfilled) amount of each sell order back to the respective seller's token balance.
     */
    function _owner_cancelAllSellOrders() external stateUpdater ownerOnly {
        while (orderBook.length > 0) {
            uint256 heapIdx;
            unchecked { heapIdx = orderBook.length - 1; }  // Save gas
            Order storage order = orderBook[heapIdx];
            balanceOf[order.seller] += order.amountDUBLRWEI;
            delete sellerToHeapIdxPlusOne[order.seller];
            orderBook.pop();
            emit CancelSell(order.seller, order.priceETHPerDUBLR_x1e9, order.amountDUBLRWEI);
        }
    }

    // -----------------------------------------------------------------------------------------------------------------
    // Selling

    /** 
     * @notice List DUBLR tokens for sale in the orderbook.
     *
     * @dev List some amount of the caller's DUBLR token balance for sale. This may be canceled any time before the
     * tokens are purchased by a buyer.
     *
     * During the time that tokens are listed for sale, the amount of the sell order is deducted from the token
     * balance of the seller, to prevent double-spending. The amount is returned to the caller's token balance if
     * the sell order is later canceled.
     *
     * If there is already a sell order in the order book for this sender, then that old order is automatically
     * canceled before the new order is placed (there may only be one order per seller in the order book at one
     * time).
     *
     * If a sell order is bought by a buyer, a market maker fee of 0.1% is deducted from the sale price of the
     * tokens before the remaining ETH amount is sent to the seller. This market maker fee is non-refundable.
     *
     * Because payment for the sale of tokens is sent to the seller when the tokens are sold, the seller account
     * must be able to receive ETH payments. In other words, the seller account must either be a non-contract
     * wallet (an Externally-Owned Account or EOA), or a contract that implements one of the payable `receive()`
     * or `fallback()` functions, in order to receive payment. If sending ETH to the seller fails because the
     * seller account is a non-payable contract, then the ETH from the sale of tokens is forfeited. In other
     * words, if you are trying to sell tokens that are owned by a non-payable contract, you MUST use a different
     * exchange -- do not use the Dublr `sell(...)` function, because there is no way for the Dublr DEX to send
     * you payment, and the action of the entire exchange cannot be held up by your order being unable to be
     * fulfilled.
     *
     * Reverts if `priceETHPerDUBLR_x1e9 == 0` or `amountDUBLRWEI == 0`, or if `amountDUBLRWEI` is larger than the
     * caller's DUBLR balance.
     *
     * @notice By calling this function, you confirm that the Dublr token is not considered an unregistered or illegal
     * security, and that the Dublr smart contract is not considered an unregistered or illegal exchange, by
     * the laws of any legal jurisdiction in which you hold or use the Dublr token.
     * 
     * @notice In some jurisdictions, such as the United States, any use, transfer, or sale of a token is a taxable
     * event. It is your responsibility to record the purchase price and sale price in ETH or your local currency
     * equivalent for each use, transfer, or sale of DUBLR tokens you own, and to pay the taxes due.
     *
     * @param priceETHPerDUBLR_x1e9 the price to list the tokens for sale at, in ETH per DUBLR token, multiplied
     *          by `10**9`.
     * @param amountDUBLRWEI the number of DUBLR tokens to sell, in units of DUBLR wei (1 DUBLR == `10**18` DUBLR wei).
     *          Must be less than or equal to the caller's balance.
     */
    function sell(uint256 priceETHPerDUBLR_x1e9, uint256 amountDUBLRWEI) external override(IDublrDEX) stateUpdater {
        require(sellingEnabled, "Selling disabled");
        require(priceETHPerDUBLR_x1e9 > 0, "Zero price");
        require(amountDUBLRWEI > 0, "Zero amount");

        // Cancel existing order, if there is one, before placing new sell order
        address seller = msg.sender;
        uint256 heapIdxPlusOne = sellerToHeapIdxPlusOne[seller];
        if (heapIdxPlusOne > 0) {
            cancelMySellOrder();
        }

        // Remove sell amount from sender's balance, to prevent spending of amount while order is in orderbook
        // (this amount will be restored to account balance if order is canceled)
        require(amountDUBLRWEI <= balanceOf[seller], "Insufficient balance");
        unchecked { balanceOf[seller] -= amountDUBLRWEI; }  // Save gas by using unchecked

        // Add sell order to heap
        heapInsert(Order({
                seller: msg.sender,
                // solhint-disable-next-line not-rely-on-time
                timestamp: block.timestamp,
                priceETHPerDUBLR_x1e9: priceETHPerDUBLR_x1e9,
                amountDUBLRWEI: amountDUBLRWEI}));

        emit ListSell(seller, priceETHPerDUBLR_x1e9, amountDUBLRWEI);
    }

    // -----------------------------------------------------------------------------------------------------------------
    // Buying

    /** @dev The amount of change to give to a seller. */
    struct SellerPayment {
        address seller;
        uint256 amountETHWEI;
    } 

    /**
     * @dev Amount in ETH to send to sellers. This will be cleared at the end of each buy() call, it is only
     * held in storage rather than memory because Solidity does not support dynamic arrays in memory.
     */
    SellerPayment[] private amountToSendToSellers;

    /**
     * @notice Buy the cheapest DUBLR tokens available, for the equivalent value of the ETH `payableAmount`/`value`
     * sent with the transaction, optionally disabling minting.
     *
     * @dev A payable function that exchanges the ETH value attached to the transaction for DUBLR tokens.
     *
     * The ETH amount exchanged for DUBLR tokens is `payableAmount`, if calling `buy()` from EtherScan, or
     * `value`/`msg.value`, if calling `buy()` from Javascript, Solidity, or a dapp.
     *
     * If there are sell orders in the orderbook that are listed at a cheaper price than the current mint price,
     * and `allowMint == true` then the sell orders will be purchased first in increasing order of price, in lieu
     * of minting. If sell orders below the mint price are exhausted, then new coins are minted at the current
     * mint price, increasing the total supply. If instead `allowMint == false`, then orders are purchased from
     * the order book, ignoring the mint price.
     *
     * This payable function should be funded with the appropriate value of tokens to buy, in ETH, including the
     * 0.1% market taker fee (i.e. multiply the ETH value of tokens you want to buy by 1.001, and then round up to
     * the nearest 1 ETH wei, to cover the market taker fee, if buying sell orders from the order book).
     * If minting new tokens (i.e. if there are no sell orders, or insufficient orders, in the order book below
     * the mint price), then when coins are minted, there is no need to add the market taker fee -- DUBLR tokens
     * will be minted at the current mint price. Market taker fees and minting fees are non-refundable.
     *
     * Because change is given if the buyer sends an ETH amount that is not a whole multiple of the token price
     * (after fee deduction), the buyer must be able to receive ETH payments. In other words, the buyer account
     * must either be a non-contract wallet (an EOA), or a contract that implements one of the payable `receive()`
     * or `fallback()` functions to receive payment.
     *
     * Note that there is a limit to the number of sell orders that can be bought per call to `buy()` to prevent
     * uncontrolled resource (gas) consumption DoS attacks, so you may need to call `buy()` multiple times to spend
     * the requested ETH amount on buy orders or minting. Any unused amount is refunded to the buyer with a `Refund`
     * event issued. A refund is also issued if the amount of ETH paid with the call to `buy()` is not an even
     * multiple of the token price (i.e. change is given where appropriate).
     *
     * @notice By calling this function, you confirm that the Dublr token is not considered an unregistered or illegal
     * security, and that the Dublr smart contract is not considered an unregistered or illegal exchange, by
     * the laws of any legal jurisdiction in which you hold or use the Dublr token.
     * 
     * @notice In some jurisdictions, such as the United States, any use, transfer, or sale of a token is a taxable
     * event. It is your responsibility to record the purchase price and sale price in ETH or your local currency
     * equivalent for each use, transfer, or sale of DUBLR tokens you own, and to pay the taxes due.
     *
     * @param allowMinting If `true`, allow the minting of new tokens at the current mint price. This parameter is
     * available because the mint price grows exponentially, and it is possible you may not want to trigger the 
     * minting of new tokens at an exorbitant price well above the current market price of the DUBLR token.
     */
    function buy(bool allowMinting) public payable override(IDublrDEX) stateUpdater {
        address buyer = msg.sender;

        // Get the ETH value sent to this function in units of ETH wei
        uint256 msgValueETHWEI = msg.value;
        require(msgValueETHWEI > 0, "Zero payment");
        uint256 buyOrderRemainingETHWEI = msgValueETHWEI;

        // Calculate the mint price -- the price is 0 if minting has finished (MAX_DOUBLING_TIME_SEC seconds
        // or more after contract deployment, mintPrice() will return 0), or has been disabled by calling
        // `_owner_enableMinting(false)`, or has been disallowed by the user by passing in `allowMinting == false`.
        uint256 mintPriceETHPerDUBLR_x1e9 = mintingEnabled && allowMinting ? mintPrice() : 0;

        // Amount of ETH to refund to buyer, and amounts to send to sellers at end of transaction
        uint256 amountToRefundToBuyerETHWEI = 0;
        require(amountToSendToSellers.length == 0, "Internal error");  // Sanity check

        // Market-matching the buyer with sellers, and executing orders: -----------------------------------------------

        for (uint256 numSellOrdersBought = 0;
                // If buyingEnabled is false, skip over the buying stage (minting is still enabled unless
                // mintingEnabled is also false). This allows exchange function to be shut down if necessary
                // without affecting minting.
                buyingEnabled
                // Iterate through orders in increasing order of priceETHPerDUBLR_x1e9, until we run out of ETH,
                // or until we run out of orders.
                && buyOrderRemainingETHWEI > 0 && orderBook.length > 0; ) {
                
            // Find the lowest-priced order (this is a memory copy, because heapRemove(0) may be called below)
            Order memory sellOrder = orderBook[0];
            // If you're trying to buy your own sell order, you need to cancel your sell order first
            require (sellOrder.seller != buyer, "Can't buy own sell order");

            // If minting hasn't ended and hasn't been disabled by the owner or disallowed by the caller, stop
            // iterating through sell orders once the order price is above the current mint price. If minting
            // has ended, or has been disabled or disallowed, then keep buying sell orders in increasing order
            // of price, until the buyer's balance is exhausted or there are no more sell orders.
            if (mintPriceETHPerDUBLR_x1e9 > 0 && sellOrder.priceETHPerDUBLR_x1e9 > mintPriceETHPerDUBLR_x1e9) {
                break;
            }
            
            // Calculate number of tokens to buy, and the price including fees: ----------------------------------------

            // Save some stack space by block-scoping some variables that are only needed temporarily
            // (otherwise the compiler complains the compiled code has run out of stack space)
            uint256 sellOrderPriceETHPerDUBLRPlusFee_x1e9;
            uint256 sellOrderPriceETHPerDUBLRMinusFee_x1e9;
            uint256 amountToBuyDUBLRWEI;
            {
                // Calculate price of trading fee (0.1% of sell price) in ETH per DUBLR, multiplied by 1e9.
                // This is charged to sellers as a market maker fee and buyers as a market taker fee.
                // Round up to nearest integer (which rounds up to the nearest 10^-9).
                uint256 tradingFeeETHPerDUBLR_x1e9 =
                    divRoundUp(sellOrder.priceETHPerDUBLR_x1e9 * TRADING_FEE_FIXED_POINT, FIXED_POINT);
                
                // Calculate price of each token including the fee (1.001x price) and minus the fee (0.999x price)
                sellOrderPriceETHPerDUBLRPlusFee_x1e9 = sellOrder.priceETHPerDUBLR_x1e9 + tradingFeeETHPerDUBLR_x1e9;
                sellOrderPriceETHPerDUBLRMinusFee_x1e9 = sellOrder.priceETHPerDUBLR_x1e9 - tradingFeeETHPerDUBLR_x1e9;
            
                // Determine how many whole DUBLR can be purchased with the current ETH balance, at the current price
                // of this order, including the trading fee. (Whole DUBLR => round down.)
                uint256 amountBuyerCanAffordAtSellOrderPrice_asDUBLRWEI_inclFee =
                        ethToDublrRoundDown(buyOrderRemainingETHWEI, sellOrderPriceETHPerDUBLRPlusFee_x1e9);

                if (amountBuyerCanAffordAtSellOrderPrice_asDUBLRWEI_inclFee == 0) {
                    // The amount of DUBLR that the buyer can afford at the sell order price is less than 1 token,
                    // so the buyer can't continue buying orders (order prices in the rest of the order book, and
                    // the mint price, have to be at least as high as the current price). Stop going through order
                    // book, and refunded remaining ETH balance to the buyer as change.
                    if (buyOrderRemainingETHWEI > 0) {
                        amountToRefundToBuyerETHWEI += buyOrderRemainingETHWEI;
                        // Emit RefundChange event
                        emit RefundChange(buyer, buyOrderRemainingETHWEI);
                        // The minting price must be higher than the current order, so minting will not be
                        // triggered either.
                        buyOrderRemainingETHWEI = 0;
                    }
                    break;
                }

                // The number of DUBLR tokens to buy from the sell order is the minimum of the order's
                // amountDUBLRWEI (it's only possible to buy a maximum of amountDUBLRWEI tokens from this order)
                // and amountBuyerCanAffordAtSellOrderPrice_asDUBLRWEI_inclFee (the buyer can't buy more tokens
                // than they can afford)
                amountToBuyDUBLRWEI = min(
                        sellOrder.amountDUBLRWEI,
                        amountBuyerCanAffordAtSellOrderPrice_asDUBLRWEI_inclFee);
            }

            // Given the whole number of DUBLR tokens to be purchased, calculate the ETH amount to charge buyer,
            // including the market taker fee, and deduct the market maker fee from the amount to send the seller.
            // (Both buyer and seller pay the same 0.1% trading fee).
            // Round up amount to charge buyer and round down amount to send seller to nearest 1 ETH wei.
            uint256 amountToChargeBuyerETHWEI = dublrToEthRoundUpClamped(
                    amountToBuyDUBLRWEI, sellOrderPriceETHPerDUBLRPlusFee_x1e9,
                    // Clamping shouldn't be needed, but to guarantee safe rounding up,
                    // clamp amount to available balance
                    buyOrderRemainingETHWEI);
            // Invariant: amountToChargeBuyerETHWEI <= buyOrderRemainingETHWEI

            // Convert the number of DUBLR tokens bought into an ETH balance to send to seller, after subtracting
            // the market maker fee.
            uint256 amountToSendToSellerETHWEI = dublrToEthRoundDown(
                    amountToBuyDUBLRWEI, sellOrderPriceETHPerDUBLRMinusFee_x1e9);

            // Transfer DUBLR from sell order to buyer: ----------------------------------------------------------------

            // Subtract the DUBLR amount from the seller's order balance
            // (modify `orderBook[0]` in storage, not the `sellOrder` copy in memory)
            uint256 sellOrderRemainingDUBLRWEI =
                    // Note that the following expression has a side effect: `-=`. The orderbook entry's
                    // remaining amount is modified in-place. The corresponding field of the in-memory copy,
                    // `sellOrder.amountDUBLRWEI`, is not used below the following line, so it doesn't matter
                    // that the storage version and the in-memory copy differ after this point.
                    (orderBook[0].amountDUBLRWEI -= amountToBuyDUBLRWEI);
                    
            // Remove `orderBook[0]` from the orderbook when its remaining balance reaches zero
            if (sellOrderRemainingDUBLRWEI == 0) {
                heapRemove(0);
            }
            
            // Deposit the DUBLR amount into the buyer's account
            balanceOf[buyer] += amountToBuyDUBLRWEI;

            // Transfer ETH from buyer to seller: ----------------------------------------------------------------------

            // Record the amount of ETH to be sent to the seller (there may be several sellers involved in one buy)
            if (amountToSendToSellerETHWEI > 0) {
                amountToSendToSellers.push(
                        SellerPayment({seller: sellOrder.seller, amountETHWEI: amountToSendToSellerETHWEI}));
            }

            // Deduct from the remaining ETH balance of buyer's buy order
            unchecked { buyOrderRemainingETHWEI -= amountToChargeBuyerETHWEI; }  // Save gas (see invariant above)
            
            // Fees to send to owner: ----------------------------------------------------------------------------------
            
            // Fees to send to owner are (amountToChargeBuyerETHWEI - amountToSendToSellerETHWEI).
            // We don't need to actually calculate this or store it anywhere, because we can calculate how much ETH is
            // left over from `msg.value` after sellers have been paid and buyer has received change.

            // Emit Dublr Buy event
            emit Buy(buyer, sellOrder.seller,
                    sellOrder.priceETHPerDUBLR_x1e9, amountToBuyDUBLRWEI,
                    sellOrderRemainingDUBLRWEI, amountToSendToSellerETHWEI, amountToChargeBuyerETHWEI);

            unchecked { ++numSellOrdersBought; }  // Save gas by using unchecked
            
            if (numSellOrdersBought == MAX_SELL_ORDERS_PER_BUY) {
                // Stop after processing MAX_SELL_ORDERS_PER_BUY buy orders, to prevent uncontrolled resource
                // consumption DoS attacks. See: https://swcregistry.io/docs/SWC-128
                
                // Refund the rest of the remaining ETH to the buyer
                amountToRefundToBuyerETHWEI += buyOrderRemainingETHWEI;
                // Emit RefundChange event
                emit RefundChange(buyer, buyOrderRemainingETHWEI);
                // Stop processing sell orders
                buyOrderRemainingETHWEI = 0;
                break;
            }
        }

        // Minting: ----------------------------------------------------------------------------------------------------

        // If the buyer's ETH balance is still greater than zero after there are no more sell orders below the
        // mint price, switch to minting
        if (buyOrderRemainingETHWEI > 0) {
            // Check minting is enabled & is allowed by the caller
            require(mintingEnabled && allowMinting, "Out of sell orders, and minting is disabled");
            // If mint price is 0, then the minting period has finished, and we can't fulfill the entire buy order
            require(mintPriceETHPerDUBLR_x1e9 > 0, "Out of sell orders, and minting has ended");

            // Mint DUBLR tokens into buyer's account: -----------------------------------------------------------------

            // Convert the amount remaining of the buy order from ETH to DUBLR.
            // Round down to the nearest whole DUBLR wei.
            uint256 amountToMintDUBLRWEI = ethToDublrRoundDown(
                    buyOrderRemainingETHWEI, mintPriceETHPerDUBLR_x1e9);
                    
            // Convert the whole number of DUBLR wei to mint back into ETH wei to spend on minting.
            // Round up to the nearest 1 ETH wei.
            uint256 amountToMintETHWEI = dublrToEthRoundUpClamped(
                    amountToMintDUBLRWEI, mintPriceETHPerDUBLR_x1e9,
                    // Clamping shouldn't be needed, but to guarantee safe rounding up,
                    // clamp amount to available balance
                    buyOrderRemainingETHWEI);
            // Invariant: amountToMintETHWEI <= buyOrderRemainingETHWEI

            // Only mint if the number of DUBLR tokens to mint is at least 1
            if (amountToMintDUBLRWEI > 0) {
                // Mint this number of DUBLR tokens for buyer (msg.sender).
                // Call the `extCallerDenied` version to ensure that _mint cannot call out to external contracts,
                // so that Checks-Effects-Interactions is followed (since we're still updating state).
                __mint_extCallerDenied(buyer, buyer, amountToMintDUBLRWEI, "", "");
                // Emit Dublr Mint event (provides more useful info than other mint events)
                emit Mint(buyer, mintPriceETHPerDUBLR_x1e9, amountToMintETHWEI, amountToMintDUBLRWEI);
                
                // Minting fee is 100% of amount spent to mint coins, i.e. amountToMintETHWEI.
                // We don't need to actually calculate this or store it anywhere, because we can calculate
                // how much ETH is left over from msg.value after buyer and sellers have been paid.
            }

            // Refund change to buyer for any fractional remainder (ETH worth less than 1 DUBLR): ----------------------

            // Calculate how much change to give for the last fractional ETH value that is worth less than 1 DUBLR
            // (amountToMintETHWEI is clamped above to a max of buyOrderRemainingETHWEI)
            unchecked { buyOrderRemainingETHWEI -= amountToMintETHWEI; }  // Save gas (see invariant above)
            
            // If the remaining ETH balance is greater than zero, it must be equivalent to less than 1 DUBLR,
            // so return the remaining ETH balance as change back to the buyer.
            if (buyOrderRemainingETHWEI > 0) {
                amountToRefundToBuyerETHWEI += buyOrderRemainingETHWEI;
                // Emit RefundChange event
                emit RefundChange(buyer, buyOrderRemainingETHWEI);
                // All remaining ETH is used up.
                buyOrderRemainingETHWEI = 0;
            }
        }
        
        // Transfer ETH from buyer to seller, and ETH fees to owner ----------------------------------------------------
        
        // Send any pending ETH payments to sellers
        uint256 totalSentToSellersAndBuyerETHWEI = 0;
        uint256 numSellers = amountToSendToSellers.length;
        if (numSellers > 0) {
            // In order to prevent the opportunity for reentrancy attacks, a copy of the amountToSendToSellers array
            // is made here in order to ensure amountToSendToSellers is emptied before any sendETH call to external
            // contracts (otherwise looping through the amountToSendToSellers array to send payments to sellers would
            // mix state updates with calling external contracts, breaking the Checks-Effects-Interactions pattern).
            SellerPayment[] memory amountToSendToSellersCopy = new SellerPayment[](numSellers);
            for (uint256 i = 0; i < numSellers; ) {
                amountToSendToSellersCopy[i] = amountToSendToSellers[i];
                unchecked { ++i; }  // Save gas
            }
            delete amountToSendToSellers;  // Clear storage array, so that it is always clear at the end of buy()

            // --------------------------------------------------------------------------------------------------------
            // All state changes in this function happen before this point, and all interactions (`sendETH`) happen
            // after this point, in order to follow the "Checks-Effects-Interactions" pattern for reentrancy protection
            // --------------------------------------------------------------------------------------------------------
            
            // Send ETH (from sale amount minus fees) to sellers
            for (uint256 i = 0; i < numSellers; ) {
                SellerPayment memory sellerPayment = amountToSendToSellersCopy[i];
                // By attempting to send with `errorMessageOnFail == ""`, if sending fails, then instead of reverting,
                // sendETH will return false. We need to catch this case, because otherwise, a seller could execute
                // a DoS on the DEX by refusing to accept ETH payments, since every buy attempt would fail. Due to
                // Checks-Effects-Interactions, we can't go back at this point and just cancel the seller's order
                // -- all state has to have already been finalized. We also can't cancel the buy order, because
                // this is not the buyer's fault. Therefore, it is the seller's responsibility to ensure that they
                // can receive ETH payments, and as noted in the documentation for the `sell` function, if they
                // can't or won't accept ETH payment, they forfeit the payment.
                (bool success, bytes memory returnData) =
                        sendETH(sellerPayment.seller, sellerPayment.amountETHWEI, /* errorMessageOnFail = */ "");
                if (success) {
                    // sellerPayment.amountETHWEI was sent to seller
                    totalSentToSellersAndBuyerETHWEI += sellerPayment.amountETHWEI;
                } else {
                    // if (!success), then payment is forfeited and sent to owner, because seller does not accept
                    // ETH, and we must prevent seller from being able to attack the exchange by causing all `buy()`
                    // calls to revert. Log this case.
                    // (Disable Slither static analyzer warning, there is no way to emit this event before all
                    // external function calls are made)
                    // slither-disable-next-line reentrancy-events
                    emit Unpayable(sellerPayment.seller, sellerPayment.amountETHWEI, returnData);
                }
                unchecked { ++i; }  // Save gas
            }
        }
        
        // Send any unspent ETH change to buyer (equiv to deducting the sale amount plus fees from the amount spent)
        if (amountToRefundToBuyerETHWEI > 0) {
            // Refund change back to buyer. Reverts if the buyer does not accept payment. (This is different than
            // the behavior when a seller does not accept payment, because a buyer not accepting payment cannot
            // shut down the whole exchange.)
            sendETH(buyer, amountToRefundToBuyerETHWEI, "Can't give buyer change");
            totalSentToSellersAndBuyerETHWEI += amountToRefundToBuyerETHWEI;
        }
        
        // Send any remaining ETH (trading fees + minting fees) to owner
        uint256 feesToSendToOwnerETHWEI = msgValueETHWEI - totalSentToSellersAndBuyerETHWEI;
        if (feesToSendToOwnerETHWEI > 0) {
            // Send fees to owner
            sendETH(_owner, feesToSendToOwnerETHWEI, "Can't pay owner");
        }
        
        // The previous sendETH call should leave the contract's ETH balance at zero.
        // However there are a few (unlikely) ways that the Dublr contract could gain an additional ETH balance:
        // https://ethereum.stackexchange.com/a/63988/82179
        // If this happens for some reason, send ETH over to the owner, so that the ETH is not lost.
        if (address(this).balance > 0) {
            sendETH(_owner, address(this).balance, "Can't pay owner");
        }
    }

    /**
     * @notice Buy the cheapest DUBLR tokens available, for the equivalent value of the ETH `payableAmount`/`value`
     * sent with the transaction.
     *
     * @dev A payable function that exchanges the ETH value attached to the transaction for DUBLR tokens.
     * Equivalent to calling `buy(true)`, i.e. setting the parameter `allowMinting == true`.
     *
     * The ETH amount exchanged for DUBLR tokens is `payableAmount`, if calling `buy()` from EtherScan, or
     * `value`/`msg.value`, if calling `buy()` from Javascript, Solidity, or a dapp.
     *
     * If there are sell orders in the orderbook that are listed at a cheaper price than the current mint price,
     * then these will be purchased first in increasing order of price, in lieu of minting. If sell orders below
     * the mint price are exhausted, then new coins are minted at the current mint price, increasing the total supply.
     *
     * This payable function should be funded with the appropriate value of tokens to buy, in ETH, including the
     * 0.1% market taker fee (i.e. multiply the ETH value of tokens you want to buy by 1.001, and then round up to
     * the nearest 1 ETH wei, to cover the market taker fee, if buying sell orders from the order book).
     * If minting new tokens (i.e. if there are no sell orders, or insufficient orders, in the order book below
     * the mint price), then when coins are minted, there is no need to add the market taker fee -- DUBLR tokens
     * will be minted at the current mint price. Market taker fees and minting fees are non-refundable.
     *
     * Because change is given if the buyer sends an ETH amount that is not a whole multiple of the token price
     * (after fee deduction), the buyer must be able to receive ETH payments. In other words, the buyer account
     * must either be a non-contract wallet (an EOA), or a contract that implements one of the payable `receive()`
     * or `fallback()` functions to receive payment.
     *
     * Note that there is a limit to the number of sell orders that can be bought per call to `buy()` to prevent
     * uncontrolled resource (gas) consumption DoS attacks, so you may need to call `buy()` multiple times to spend
     * the requested ETH amount on buy orders or minting. Any unused amount is refunded to the buyer with a `Refund`
     * event issued. A refund is also issued if the amount of ETH paid with the call to `buy()` is not an even
     * multiple of the token price (i.e. change is given where appropriate).
     *
     * @notice By calling this function, you confirm that the Dublr token is not considered an unregistered or illegal
     * security, and that the Dublr smart contract is not considered an unregistered or illegal exchange, by
     * the laws of any legal jurisdiction in which you hold or use the Dublr token.
     * 
     * @notice In some jurisdictions, such as the United States, any use, transfer, or sale of a token is a taxable
     * event. It is your responsibility to record the purchase price and sale price in ETH or your local currency
     * equivalent for each use, transfer, or sale of DUBLR tokens you own, and to pay the taxes due.
     */
    function buy() external payable override(IDublrDEX) {
        buy(/* allowMinting = */ true);
    }
}

