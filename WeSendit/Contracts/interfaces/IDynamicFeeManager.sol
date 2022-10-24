// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./IPancakeRouter.sol";

/**
 * Fee entry structure
 */
struct FeeEntry {
    // Unique identifier for the fee entry
    // Generated out of (destination, doLiquify, doSwapForBusd, swapOrLiquifyAmount) to
    // always use the same feeEntryAmounts entry.
    bytes32 id;
    // Sender address OR wildcard address
    address from;
    // Receiver address OR wildcard address
    address to;
    // Fee percentage multiplied by 100000
    uint256 percentage;
    // Fee destination address
    address destination;
    // Indicator, if callback should be called on the destination address
    bool doCallback;
    // Indicator, if the fee amount should be used to add liquidation on DEX
    bool doLiquify;
    // Indicator, if the fee amount should be swapped to BUSD
    bool doSwapForBusd;
    // Amount used to add liquidation OR swap to BUSD
    uint256 swapOrLiquifyAmount;
    // Timestamp after which the fee won't be applied anymore
    uint256 expiresAt;
}

interface IDynamicFeeManager {
    /**
     * Emitted on fee addition
     *
     * @param id bytes32 - "Unique" identifier for fee entry
     * @param from address - Sender address OR address(0) for wildcard
     * @param to address - Receiver address OR address(0) for wildcard
     * @param percentage uint256 - Fee percentage to take multiplied by 100000
     * @param destination address - Destination address for the fee
     * @param doCallback bool - Indicates, if a callback should be called at the fee destination
     * @param doLiquify bool - Indicates, if the fee amount should be used to add liquidy on DEX
     * @param doSwapForBusd bool - Indicates, if the fee amount should be swapped to BUSD
     * @param swapOrLiquifyAmount uint256 - Amount for liquidify or swap
     * @param expiresAt uint256 - Timestamp after which the fee won't be applied anymore
     */
    event FeeAdded(
        bytes32 indexed id,
        address indexed from,
        address to,
        uint256 percentage,
        address indexed destination,
        bool doCallback,
        bool doLiquify,
        bool doSwapForBusd,
        uint256 swapOrLiquifyAmount,
        uint256 expiresAt
    );

    /**
     * Emitted on fee removal
     *
     * @param id bytes32 - "Unique" identifier for fee entry
     * @param index uint256 - Index of removed the fee
     */
    event FeeRemoved(bytes32 indexed id, uint256 index);

    /**
     * Emitted on fee reflection / distribution
     *
     * @param id bytes32 - "Unique" identifier for fee entry
     * @param token address - Token used for fee
     * @param from address - Sender address OR address(0) for wildcard
     * @param to address - Receiver address OR address(0) for wildcard
     * @param destination address - Destination address for the fee
     * @param doCallback bool - Indicates, if a callback should be called at the fee destination
     * @param doLiquify bool - Indicates, if the fee amount should be used to add liquidy on DEX
     * @param doSwapForBusd bool - Indicates, if the fee amount should be swapped to BUSD
     * @param swapOrLiquifyAmount uint256 - Amount for liquidify or swap
     * @param expiresAt uint256 - Timestamp after which the fee won't be applied anymore
     */
    event FeeReflected(
        bytes32 indexed id,
        address token,
        address indexed from,
        address to,
        uint256 tFee,
        address indexed destination,
        bool doCallback,
        bool doLiquify,
        bool doSwapForBusd,
        uint256 swapOrLiquifyAmount,
        uint256 expiresAt
    );

    /**
     * Emitted on fee state update
     *
     * @param enabled bool - Indicates if fees are enabled now
     */
    event FeeEnabledUpdated(bool enabled);

    /**
     * Emitted on pancake router address update
     *
     * @param newAddress address - New pancake router address
     */
    event PancakeRouterUpdated(address newAddress);

    /**
     * Emitted on BUSD address update
     *
     * @param newAddress address - New BUSD address
     */
    event BusdAddressUpdated(address newAddress);

    /**
     * Emitted on fee limits (fee percentage and transsaction limit) decrease
     */
    event FeeLimitsDecreased();

    /**
     * Emitted on volume percentage for swap events updated
     *
     * @param newPercentage uint256 - New volume percentage for swap events
     */
    event PercentageVolumeSwapUpdated(uint256 newPercentage);

    /**
     * Emitted on volume percentage for liquify events updated
     *
     * @param newPercentage uint256 - New volume percentage for liquify events
     */
    event PercentageVolumeLiquifyUpdated(uint256 newPercentage);

    /**
     * Emitted on Pancakeswap pair (WSI <-> BUSD) address updated
     *
     * @param newAddress address - New pair address
     */
    event PancakePairBusdUpdated(address newAddress);

    /**
     * Emitted on Pancakeswap pair (WSI <-> BNB) address updated
     *
     * @param newAddress address - New pair address
     */
    event PancakePairBnbUpdated(address newAddress);

    /**
     * Emitted on swap and liquify event
     *
     * @param firstHalf uint256 - Half of tokens
     * @param newBalance uint256 - Amount of BNB
     * @param secondHalf uint256 - Half of tokens for BNB swap
     */
    event SwapAndLiquify(
        uint256 firstHalf,
        uint256 newBalance,
        uint256 secondHalf
    );

    /**
     * Emitted on token swap to BUSD
     *
     * @param token address - Token used for swap
     * @param inputAmount uint256 - Amount used as input for swap
     * @param newBalance uint256 - Amount of received BUSD
     * @param destination address - Destination address for BUSD
     */
    event SwapTokenForBusd(
        address token,
        uint256 inputAmount,
        uint256 newBalance,
        address indexed destination
    );

    /**
     * Return the fee entry at the given index
     *
     * @param index uint256 - Index of the fee entry
     *
     * @return fee FeeEntry - Fee entry
     */
    function getFee(uint256 index) external view returns (FeeEntry memory fee);

    /**
     * Adds a fee entry to the list of fees
     *
     * @param from address - Sender address OR wildcard address
     * @param to address - Receiver address OR wildcard address
     * @param percentage uint256 - Fee percentage to take multiplied by 100000
     * @param destination address - Destination address for the fee
     * @param doCallback bool - Indicates, if a callback should be called at the fee destination
     * @param doLiquify bool - Indicates, if the fee amount should be used to add liquidy on DEX
     * @param doSwapForBusd bool - Indicates, if the fee amount should be swapped to BUSD
     * @param swapOrLiquifyAmount uint256 - Amount for liquidify or swap
     * @param expiresAt uint256 - Timestamp after which the fee won't be applied anymore
     *
     * @return index uint256 - Index of the newly added fee entry
     */
    function addFee(
        address from,
        address to,
        uint256 percentage,
        address destination,
        bool doCallback,
        bool doLiquify,
        bool doSwapForBusd,
        uint256 swapOrLiquifyAmount,
        uint256 expiresAt
    ) external returns (uint256 index);

    /**
     * Removes the fee entry at the given index
     *
     * @param index uint256 - Index to remove
     */
    function removeFee(uint256 index) external;

    /**
     * Reflects the fee for a transaction
     *
     * @param from address - Sender address
     * @param to address - Receiver address
     * @param amount uint256 - Transaction amount
     *
     * @return tTotal uint256 - Total transaction amount after fees
     * @return tFees uint256 - Total fee amount
     */
    function reflectFees(
        address from,
        address to,
        uint256 amount
    ) external returns (uint256 tTotal, uint256 tFees);

    /**
     * Returns the collected amount for swap / liquify fees
     *
     * @param id bytes32 - Fee entry id
     *
     * @return amount uint256 - Collected amount
     */
    function getFeeAmount(bytes32 id) external view returns (uint256 amount);

    /**
     * Returns true if fees are enabled, false when disabled
     *
     * @param value bool - Indicates if fees are enabled
     */
    function feesEnabled() external view returns (bool value);

    /**
     * Sets the transaction fee state
     *
     * @param value bool - true to enable fees, false to disable
     */
    function setFeesEnabled(bool value) external;

    /**
     * Returns the pancake router
     *
     * @return value IPancakeRouter02 - Pancake router
     */
    function pancakeRouter() external view returns (IPancakeRouter02 value);

    /**
     * Sets the pancake router
     *
     * @param value address - New pancake router address
     */
    function setPancakeRouter(address value) external;

    /**
     * Returns the BUSD address
     *
     * @return value address - BUSD address
     */
    function busdAddress() external view returns (address value);

    /**
     * Sets the BUSD address
     *
     * @param value address - BUSD address
     */
    function setBusdAddress(address value) external;

    /**
     * Returns the fee decrease status
     *
     * @return value bool - True if fees are already decreased, false if not
     */
    function feeDecreased() external view returns (bool value);

    /**
     * Returns the fee entry percentage limit
     *
     * @return value uint256 - Fee entry percentage limit
     */
    function feePercentageLimit() external view returns (uint256 value);

    /**
     * Returns the overall transaction fee limit
     *
     * @return value uint256 - Transaction fee limit in percent
     */
    function transactionFeeLimit() external view returns (uint256 value);

    /**
     * Decreases the fee limits from initial values (used for bot protection), to normal values
     */
    function decreaseFeeLimits() external;

    /**
     * Returns the current volume percentage for swap events
     *
     * @return value uint256 - Volume percentage for swap events
     */
    function percentageVolumeSwap() external view returns (uint256 value);

    /**
     * Sets the volume percentage for swap events
     * If set to zero, swapping based on volume will be disabled and fee.swapOrLiquifyAmount is used.
     *
     * @param value uint256 - New volume percentage for swapping
     */
    function setPercentageVolumeSwap(uint256 value) external;

    /**
     * Returns the current volume percentage for liquify events
     *
     * @return value uint256 - Volume percentage for liquify events
     */
    function percentageVolumeLiquify() external view returns (uint256 value);

    /**
     * Sets the volume percentage for liquify events
     * If set to zero, adding liquidity based on volume will be disabled and fee.swapOrLiquifyAmount is used.
     *
     * @param value uint256 - New volume percentage for adding liquidity
     */
    function setPercentageVolumeLiquify(uint256 value) external;

    /**
     * Returns the Pancakeswap pair address (WSI <-> BUSD)
     *
     * @return value address - Pair address
     */
    function pancakePairBusdAddress() external view returns (address value);

    /**
     * Sets the Pancakeswap pair address (WSI <-> BUSD)
     *
     * @param value address - New pair address
     */
    function setPancakePairBusdAddress(address value) external;

    /**
     * Returns the Pancakeswap pair address (WSI <-> BNB)
     *
     * @return value address - Pair address
     */
    function pancakePairBnbAddress() external view returns (address value);

    /**
     * Sets the Pancakeswap pair address (WSI <-> BNB)
     *
     * @param value address - New pair address
     */
    function setPancakePairBnbAddress(address value) external;

    /**
     * Returns the WeSendit token instance
     *
     * @return value IERC20 - WeSendit Token instance
     */
    function token() external view returns (IERC20 value);
}
