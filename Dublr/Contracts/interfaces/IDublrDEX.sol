// SPDX-License-Identifier: MIT

// The Dublr token (symbol: DUBLR), with a built-in distributed exchange for buying/selling tokens.
// By Hiroshi Yamamoto.
// 虎穴に入らずんば虎子を得ず。
//
// Officially hosted at: https://github.com/dublr/dublr

pragma solidity ^0.8.15;

/**
 * @title IDublrDex
 * @dev Dublr distributed exchange interface.
 * @author Hiroshi Yamamoto
 */
interface IDublrDEX {

    // -----------------------------------------------------------------------------------------------------------------
    // Events

    /**
     * @notice Emitted when a seller's tokens are listed for sale.
     *
     * @param seller The account of the seller of the listed tokens.
     * @param priceETHPerDUBLR_x1e9 The list price of the tokens, in ETH per DUBLR (multiplied by `10**9`).
     * @param amountDUBLRWEI The number of tokens listed for sale.
     */
    event ListSell(address indexed seller, uint256 priceETHPerDUBLR_x1e9, uint256 amountDUBLRWEI);

    /**
     * @notice Emitted when a sell order is canceled.
     *
     * @param seller The account of the token seller in the canceled listing.
     * @param priceETHPerDUBLR_x1e9 The price tokens were listed for, in ETH per DUBLR (multiplied by `10**9`).
     * @param amountDUBLRWEI The number of tokens that were listed for sale.
     */
    event CancelSell(address indexed seller, uint256 priceETHPerDUBLR_x1e9, uint256 amountDUBLRWEI);

    /**
     * @notice Emitted when the a sell order is partially or fully purchased by a buyer.
     *
     * @dev When amountRemainingInOrderDUBLR reaches 0, the sell order is removed from the orderbook.
     *
     * @param buyer The buyer account.
     * @param seller The seller account.
     * @param priceETHPerDUBLR_x1e9 The price tokens were listed for, in ETH per DUBLR (multiplied by `10**9`).
     * @param amountBoughtDUBLRWEI The number of DUBLR tokens (in DUBLR wei, where 1 DUBLR == `10**18` DUBLR wei)
     *          that were transferred from the seller to the buyer.
     * @param amountRemainingInOrderDUBLRWEI The number of DUBLR tokens (in DUBLR wei) remaining in the order.
     * @param amountSentToSellerETHWEI The amount of ETH (in wei) transferred from the buyer to the seller.
     * @param amountChargedToBuyerETHWEI The amount of ETH (in wei) charged to the buyer, including fees.
     */
    event Buy(address indexed buyer, address indexed seller,
            uint256 priceETHPerDUBLR_x1e9, uint256 amountBoughtDUBLRWEI, uint256 amountRemainingInOrderDUBLRWEI,
            uint256 amountSentToSellerETHWEI, uint256 amountChargedToBuyerETHWEI);

    /**
     * @notice Emitted when a buyer calls `buy()`, and there are no sell orders listed below the mint price,
     * leading to new tokens being minted for the buyer.
     *
     * @param buyer The account to mint tokens for.
     * @param priceETHPerDUBLR_x1e9 The current mint price, in ETH per DUBLR (multiplied by `10**9`).
     * @param amountSpentETHWEI The amount of ETH that was spent by the buyer to mint tokens.
     * @param amountMintedDUBLRWEI The number of tokens that were minted for the buyer.
     */
    event Mint(address indexed buyer, uint256 priceETHPerDUBLR_x1e9, uint256 amountSpentETHWEI,
            uint256 amountMintedDUBLRWEI);

    /**
     * @notice Emitted to return any change to the buyer from a `buy()` call, where the provided ETH amount was
     * not a whole multiple of the token price.
     *
     * @param buyer The buyer account.
     * @param refundedETHWEI The amount of ETH (in wei) that was refunded to the buyer.
     */
    event RefundChange(address indexed buyer, uint256 refundedETHWEI);

    /**
     * @notice Emitted when an ETH payment could not be sent to a seller for any reason. These payments
     * are considered forfeited as per the documentation on the `sell(...)` function.
     *
     * @param seller The seller account to which an attempt was made to send an ETH payment.
     * @param amountETHWEI The amount of ETH (in wei) that the Dublr contract attempted to send.
     * @param data Any data returned by the failed payable call (may contain revert reason information).
     */
    event Unpayable(address indexed seller, uint256 amountETHWEI, bytes data);

    // -----------------------------------------------------------------------------------------------------------------
    // Public functions for interacting with order book

    /**
     * @notice The number of sell orders in the order book.
     *
     * @return numEntries The number of entries in the order book.
     */
    function orderBookSize() external view returns (uint256 numEntries);

    /**
     * @notice The price of the cheapest sell order in the order book for any user.
     *
     * @dev If there are no current sell orders, reverts.
     *
     * @return priceETHPerDUBLR_x1e9 The price of DUBLR tokens in the cheapest sell order, in ETH per DUBLR
     *          (multiplied by `10**9`).
     * @return amountDUBLRWEI the number of DUBLR tokens for sale, in DUBLR wei (1 DUBLR = 10^18 DUBLR wei).
     */
    function cheapestSellOrder() external view returns (uint256 priceETHPerDUBLR_x1e9, uint256 amountDUBLRWEI);

    /**
     * @notice The current sell order in the order book for the caller.
     *
     * @dev If the caller has no current sell order, reverts.
     *
     * @return priceETHPerDUBLR_x1e9 The price of DUBLR tokens in the caller's current sell order, in ETH per DUBLR
     *          (multiplied by `10**9`).
     * @return amountDUBLRWEI the number of DUBLR tokens for sale, in DUBLR wei (1 DUBLR = `10**18` DUBLR wei).
     */
    function mySellOrder() external view returns (uint256 priceETHPerDUBLR_x1e9, uint256 amountDUBLRWEI);

    /**
     * @notice Cancel the caller's current sell order in the orderbook.
     *
     * @dev Restores the amount of the caller's sell order back to the seller's token balance.
     *
     * If the caller has no current sell order, reverts.
     */
    function cancelMySellOrder() external;
    
    /**
     * @dev The price and amount of a sell order in the orderbook.
     *
     * @param priceETHPerDUBLR_x1e9 The price of DUBLR tokens in the caller's current sell order, in ETH per DUBLR
     *          (multiplied by `10**9`).
     * @param amountDUBLRWEI the number of DUBLR tokens for sale, in DUBLR wei (1 DUBLR = `10**18` DUBLR wei).
     */
    struct PriceAndAmount {
        // Tuples are not a first-class type in Solidity, so need to use a struct to return an array of tuples
        uint256 priceETHPerDUBLR_x1e9;
        uint256 amountDUBLRWEI;
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
    function allSellOrders() external view
            // Returning an array requires ABI encoder v2, which is the default in Solidity >=0.8.0.
            returns (PriceAndAmount[] memory priceAndAmountOfSellOrders);

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
     * If there is already a sell order in the order book for this sender, then that old order is canceled before
     * the new order is placed (there may only be one order per account in the order book at one time).
     *
     * Reverts if `priceETHPerDUBLR_x1e9 == 0` or `amountDUBLRWEI == 0`, or if `amountDUBLRWEI` is larger than the
     * caller's DUBLR balance.
     *
     * If a sell order is bought by a buyer, a market maker fee of 0.1% is deducted from the sale price of the tokens
     * before the remaining ETH amount is sent to the seller. The market maker fee is non-refundable.
     *
     * Because payment for the sale of tokens is sent to the seller (the caller of `sell(price, amount)`) when
     * the tokens are sold, the seller must be able to receive ETH payments. In other words, the seller account must
     * either be a non-contract wallet (an EOA), or a contract that implements one of the payable `receive()` or
     * `fallback()` functions to receive payment.
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
    function sell(uint256 priceETHPerDUBLR_x1e9, uint256 amountDUBLRWEI) external;
    
    // -----------------------------------------------------------------------------------------------------------------
    // Buying

    /**
     * @notice Buy the cheapest DUBLR tokens available, for the equivalent value of the ETH `payableAmount`/`value`
     * sent with the transaction, optionally disabling minting.
     *
     * @dev A payable function that exchanges the ETH value attached to the transaction for DUBLR tokens.
     * Minting may be disabled by passing in `false` to the `allowMinting` parameter.
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
    function buy(bool allowMinting) external payable;

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
     * @notice By calling this function, you confirm that the Dublr token is not considered an unregistered or illegal
     * security, and that the Dublr smart contract is not considered an unregistered or illegal exchange, by
     * the laws of any legal jurisdiction in which you hold or use the Dublr token.
     * 
     * @notice In some jurisdictions, such as the United States, any use, transfer, or sale of a token is a taxable
     * event. It is your responsibility to record the purchase price and sale price in ETH or your local currency
     * equivalent for each use, transfer, or sale of DUBLR tokens you own, and to pay the taxes due.
     */
    function buy() external payable;
}

