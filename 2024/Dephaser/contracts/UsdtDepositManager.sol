// SPDX-License-Identifier: MIT
pragma solidity 0.8.27;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { UUPSUpgradeable } from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import { AccessControlUpgradeable } from "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/ReentrancyGuardUpgradeable.sol";
import { Math } from "@openzeppelin/contracts/utils/math/Math.sol";

import { IERC20, SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IPool } from "@src/interfaces/external/IPool.sol";
import { IAggregatorV3 } from "@src/interfaces/external/IAggregatorV3.sol";
import { IERC20MintableBurnable } from "@src/interfaces/external/IERC20MintableBurnable.sol";
import { IERC20PermitMinimal } from "@src/interfaces/external/IERC20PermitMinimal.sol";
import { IDepositManager } from "@src/interfaces/internal/IDepositManager.sol";

import {
    EXCHANGE_RATE_SCALE,
    ONE_HUNDRED_PERCENT_IN_BP,
    MIN_COOLDOWN_BLOCKS,
    MAX_COOLDOWN_BLOCKS,
    MIN_PROTOCOL_FEE_BPS,
    MAX_PROTOCOL_FEE_BPS
} from "@src/constants/NumericConstants.sol";
import { OPERATOR_ROLE, UPGRADER_ROLE } from "@src/constants/RoleConstants.sol";

/**
 * @title UsdtDepositManager
 * @notice Manages deposits, withdrawals, and exchange between deposit tokens and JPY tokens
 */
contract UsdtDepositManager is
    IDepositManager,
    Initializable,
    UUPSUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable
{
    using SafeERC20 for IERC20;

    /// @notice The cooldown period in blocks that must pass before a withdrawal can be executed
    uint256 public cooldownBlocks;

    /// @notice The protocol fee in basis points
    uint256 public protocolFeeBps;

    /// @notice The total amount of fees collected in form of deposit token
    uint256 public totalFeeAmount;

    /// @notice The Aave Pool contract used for depositing and withdrawing tokens
    IPool public aavePool;

    // @notice The token used for deposits (e.g., USDT)
    IERC20 public depositToken;

    /// @notice The Aave wrapped version of the deposit token (aToken)
    IERC20 public aaveWrappedDepositToken;

    /// @notice The JPY token contract
    IERC20MintableBurnable public jpyToken;

    /// @notice The total amount of deposit tokens currently managed by this contract
    uint256 public totalDepositToken;

    /// @notice The total amount of JPY tokens currently minted by this contract
    uint256 public totalMintedJpy;

    /// @notice Mapping of token addresses to their corresponding PriceFeedInfo
    mapping(address => PriceFeedInfo) public tokenUsdPriceFeeds;

    /// @notice Mapping of user addresses to their withdrawal requests
    mapping(address => WithdrawalRequest) public withdrawalRequests;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    /**
     * @notice Initializes the DepositManager contract
     * @param defaultAdmin Address of the default admin
     * @param operator Address with operator role
     * @param aavePoolAddress Address of the Aave pool
     * @param depositTokenAddress Address of the deposit token
     * @param depositTokenUsdPriceFeedAddress Address of the deposit token USD price feed(Using Chainlink Price Feed)
     * @param jpyTokenAddress Address of the JPY token
     * @param jpyUsdPriceFeedAddress Address of the JPY USD price feed(Using Chainlink Price Feed)
     * @param initialCooldownBlocks Initial cooldown period in blocks
     */
    function initialize(
        address defaultAdmin,
        address operator,
        address aavePoolAddress,
        address depositTokenAddress,
        address depositTokenUsdPriceFeedAddress,
        address jpyTokenAddress,
        address jpyUsdPriceFeedAddress,
        uint256 initialCooldownBlocks
    )
        public
        initializer
    {
        __AccessControl_init();
        __UUPSUpgradeable_init();
        __ReentrancyGuard_init();

        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
        _grantRole(OPERATOR_ROLE, operator);

        _setCooldownBlocks(initialCooldownBlocks);
        _setPriceFeed(jpyTokenAddress, jpyUsdPriceFeedAddress);
        _setPriceFeed(depositTokenAddress, depositTokenUsdPriceFeedAddress);

        // these variables must be immutable
        aavePool = IPool(aavePoolAddress);
        depositToken = IERC20(depositTokenAddress);
        jpyToken = IERC20MintableBurnable(jpyTokenAddress);
        aaveWrappedDepositToken = IERC20(IPool(aavePoolAddress).getReserveData(depositTokenAddress).aTokenAddress);
    }

    /**
     * @notice Get the current profit generated from Aave deposits
     * @dev This function calculates the profit by comparing the current balance of Aave wrapped tokens
     *      with the total amount of deposit tokens. The profit is generated because the Aave wrapped token
     *      (aToken) is a yield-bearing token, meaning its balance increases over time as it accrues interest.
     *
     * @return uint256 The current profit in terms of the deposit token
     *
     * @notice The profit is calculated as follows:
     * 1. The balance of aTokens increases automatically as interest accrues.
     * 2. The `totalDepositToken` remains constant unless new deposits or withdrawals occur.
     * 3. The difference between the current aToken balance and `totalDepositToken` represents the profit.
     *
     * @notice This profit calculation assumes:
     * - The aToken/deposit token exchange rate is 1:1 (which is true for Aave v3).
     */
    function getCurrentAaveProfit() public view returns (uint256) {
        return aaveWrappedDepositToken.balanceOf(address(this)) - totalDepositToken;
    }

    /**
     * @notice Get the USD rate for a given token
     * @dev This function retrieves the latest price data from a Chainlink price feed for the specified token
     * @param token The address of the token for which to get the USD rate
     * @return uint256 The current price of the token in USD, scaled by the price feed's decimal places
     * @return uint8 The number of decimal places used in the price feed
     *
     * @notice Important considerations:
     * - This function assumes that the price feed returns the token's price in USD
     * - The returned price is a fixed-point number; use the returned decimals to interpret it correctly
     * - This function reverts if no price feed is set for the token or if the price feed returns an invalid price
     *
     * @notice Example:
     * If the function returns (100000000, 8) for USDT, it means 1 USDT = $1.00
     */
    function getTokenUsdRate(address token) public view returns (uint256, uint8) {
        PriceFeedInfo memory priceFeedInfo = tokenUsdPriceFeeds[token];
        if (address(priceFeedInfo.priceFeed) == address(0)) {
            revert PriceFeedNotSet(token);
        }

        (, int256 price,,,) = priceFeedInfo.priceFeed.latestRoundData();

        if (price <= 0) {
            revert InvalidPrice(token);
        }

        return (uint256(price), priceFeedInfo.decimals);
    }

    /**
     * @notice Calculate the current deposit rate
     * @dev This function calculates how many deposit tokens (e.g., USDT) you get for 1 JPY
     * @return The deposit rate as a fixed-point number with 8 decimal places
     * For example, if 1 JPY = 0.007 USDT, this function will return 700000 (0.00700000)
     */
    function getDepositRate() public view returns (uint256) {
        // Use 1e6 as the base amount (assuming 6 decimal places for the deposit token)
        uint256 depositBaseAmount = 1e6;

        // Apply the protocol fee to the deposit amount
        (uint256 amountAfterFee,) = _applyProtocolFee(depositBaseAmount);

        // Convert the amount after fee to JPY
        uint256 jpyAmount = _convertToJpy(amountAfterFee);

        // return the rate with 8 decimal places
        return Math.mulDiv(depositBaseAmount, EXCHANGE_RATE_SCALE, jpyAmount, Math.Rounding.Floor);
    }

    /**
     * @notice Get the average exchange rate between deposit tokens and JPY tokens
     * @dev Calculates the rate based on total deposit tokens and total minted JPY
     * @return The average exchange rate as a fixed-point number with 8 decimal places
     *
     * @notice Important considerations:
     * - Assumes the deposit token is pegged to USD (e.g., USDT)
     * - This rate represents an average over all deposits and mints, not the current market rate
     * - This rate may differ from the current market rate or the rate returned by getTokenUsdRate()
     * - The returned value is scaled by 1e8 for precision (8 decimal places)
     *
     * @notice Example:
     * If the function returns 73000000, it means the average rate is 1 JPY = 0.00730000 USD
     * (or approximately 136.99 JPY = 1 USD)
     */
    function getDepositTokenToJpyAverageRate() public view returns (uint256) {
        if (totalMintedJpy == 0) {
            return 0;
        }
        return Math.mulDiv(totalDepositToken, EXCHANGE_RATE_SCALE, totalMintedJpy, Math.Rounding.Floor);
    }

    /**
     * @inheritdoc IDepositManager
     */
    function deposit(address to, uint256 depositAmount) external override nonReentrant {
        _deposit(to, depositAmount);
    }

    /**
     * @inheritdoc IDepositManager
     */
    function depositWithPermit(
        address to,
        uint256 depositAmount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
        override
        nonReentrant
    {
        _trustlessPermit(address(depositToken), to, address(this), depositAmount, deadline, v, r, s);
        _deposit(to, depositAmount);
    }

    /**
     * @inheritdoc IDepositManager
     */
    function requestWithdrawal(uint256 jpyAmount) external override nonReentrant {
        address sender = _msgSender();

        if (withdrawalRequests[sender].jpyAmount > 0) {
            revert WithdrawalRequestPending();
        }

        _requestWithdrawal(sender, jpyAmount);
    }

    /**
     * @inheritdoc IDepositManager
     */
    function requestWithdrawalWithPermit(
        uint256 jpyAmount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        external
        override
        nonReentrant
    {
        address sender = _msgSender();
        
        if (withdrawalRequests[sender].jpyAmount > 0) {
            revert WithdrawalRequestPending();
        }

        _trustlessPermit(address(jpyToken), sender, address(this), jpyAmount, deadline, v, r, s);
        
        _requestWithdrawal(sender, jpyAmount);
    }

    /**
     * @inheritdoc IDepositManager
     */
    function executeWithdrawal() external override nonReentrant {
        address sender = _msgSender();

        WithdrawalRequest memory request = withdrawalRequests[sender];

        if (request.tokenAmount == 0) {
            revert NoWithdrawalRequest();
        }

        if (block.number < request.requestBlock + cooldownBlocks) {
            revert CooldownPeriodNotMet();
        }

        uint256 amount = request.tokenAmount;
        delete withdrawalRequests[sender];

        depositToken.safeTransfer(sender, amount);

        emit WithdrawalExecuted(sender, amount);
    }

    /**
     * @inheritdoc IDepositManager
     */
    function setPriceFeed(address token, address priceFeedAddress) external override onlyRole(OPERATOR_ROLE) {
        _setPriceFeed(token, priceFeedAddress);
    }

    /**
     * @inheritdoc IDepositManager
     */
    function setCooldownBlocks(uint256 newCooldownBlocks) external override onlyRole(OPERATOR_ROLE) {
        _setCooldownBlocks(newCooldownBlocks);
    }

    /**
     * @inheritdoc IDepositManager
     */
    function setProtocolFeeBps(uint256 newFeeBps) external override onlyRole(OPERATOR_ROLE) {
        _setProtocolFeeBps(newFeeBps);
    }

    /**
     * @inheritdoc IDepositManager
     */
    function withdrawFeeAmount() external override onlyRole(OPERATOR_ROLE) {
        if (totalFeeAmount == 0) {
            return;
        }

        address to = _msgSender();

        depositToken.safeTransfer(to, totalFeeAmount);

        emit FeeWithdrawn(to, totalFeeAmount);

        totalFeeAmount = 0;
    }

    /**
     * @inheritdoc IDepositManager
     */
    function withdrawAaveProfit() external onlyRole(OPERATOR_ROLE) {
        uint256 profit = getCurrentAaveProfit();
        aavePool.withdraw(address(depositToken), profit, _msgSender());
        emit AaveProfitWithdrawn(profit);
    }

    // Internal administrative functions
    function _setPriceFeed(address token, address priceFeedAddress) internal {
        if (token == address(0)) {
            revert ZeroTokenAddress();
        }

        if (priceFeedAddress == address(0)) {
            revert ZeroPriceFeedAddress();
        }

        IAggregatorV3 priceFeed = IAggregatorV3(priceFeedAddress);
        uint8 decimals = priceFeed.decimals();

        if (decimals == 0) {
            revert InvalidPriceFeedDecimals(decimals);
        }

        tokenUsdPriceFeeds[token] = PriceFeedInfo(priceFeed, decimals);

        emit PriceFeedUpdated(token, priceFeedAddress, decimals);
    }

    function _setCooldownBlocks(uint256 newCooldownBlocks) internal {
        if (newCooldownBlocks < MIN_COOLDOWN_BLOCKS || newCooldownBlocks > MAX_COOLDOWN_BLOCKS) {
            revert CooldownBlocksOutOfRange(newCooldownBlocks, MIN_COOLDOWN_BLOCKS, MAX_COOLDOWN_BLOCKS);
        }
        cooldownBlocks = newCooldownBlocks;
        emit CooldownBlocksUpdated(newCooldownBlocks);
    }

    function _setProtocolFeeBps(uint256 newFeeBps) internal {
        if (newFeeBps < MIN_PROTOCOL_FEE_BPS || newFeeBps > MAX_PROTOCOL_FEE_BPS) {
            revert ProtocolFeeOutOfRange(newFeeBps, MIN_PROTOCOL_FEE_BPS, MAX_PROTOCOL_FEE_BPS);
        }
        protocolFeeBps = newFeeBps;
        emit ProtocolFeeUpdated(newFeeBps);
    }

    /**
     * @dev Handles the deposit process
     * @param recipient Address to receive minted JPY tokens
     * @param depositAmount Amount of deposit tokens to be deposited
     * @notice Transfers deposit tokens, applies fee, supplies to Aave, updates totalDepositToken, totalMintedJpy, and
     * totalFeeAmount and mints JPY tokens
     */
    function _deposit(address recipient, uint256 depositAmount) internal {
        address sender = _msgSender();
        address proxy = address(this);

        depositToken.safeTransferFrom(sender, proxy, depositAmount);

        (uint256 amountAfterFee, uint256 feeAmount) = _applyProtocolFee(depositAmount);

        depositToken.safeIncreaseAllowance(address(aavePool), amountAfterFee);
        aavePool.supply(address(depositToken), amountAfterFee, proxy, 0);

        uint256 jpyAmount = _convertToJpy(amountAfterFee);

        totalFeeAmount += feeAmount;
        totalDepositToken += amountAfterFee;
        totalMintedJpy += jpyAmount;

        jpyToken.mint(recipient, jpyAmount);

        emit Deposited(recipient, depositAmount, jpyAmount);
    }

    /**
     * @dev Handles the withdrawal request process
     * @param recipient Address requesting withdrawal
     * @param jpyAmount Amount of JPY tokens to withdraw
     * @notice Burns JPY tokens, calculates average JPY/deposit token rate, converts JPY to deposit token amount, and
     * requests withdrawal
     */
    function _requestWithdrawal(address recipient, uint256 jpyAmount) internal {
        jpyToken.burnFrom(recipient, jpyAmount);

        uint256 currentRate = getJpyToDepositTokenAverageRate();

        // Convert JPY to deposit token amount

        uint256 tokenAmount = Math.mulDiv(jpyAmount, EXCHANGE_RATE_SCALE, currentRate, Math.Rounding.Floor);
        withdrawalRequests[recipient] =
            WithdrawalRequest({ jpyAmount: jpyAmount, tokenAmount: tokenAmount, requestBlock: block.number });

        totalMintedJpy -= jpyAmount;
        totalDepositToken -= tokenAmount;

        // withdraw from Aave, and store the deposit token in contract
        aavePool.withdraw(address(depositToken), tokenAmount, address(this));

        emit WithdrawalRequested(recipient, jpyAmount, tokenAmount);
    }

    /**
     * @notice Get the average JPY to deposit token exchange rate
     * @dev Calculates the average rate based on total minted JPY and total deposit tokens
     * @return uint256 The average JPY/deposit token rate as a fixed-point number with 8 decimal places
     *
     * @notice Important considerations:
     * - This rate represents an average over all mints and deposits, not necessarily the current market rate
     * - The returned value is scaled by EXCHANGE_RATE_SCALE for precision (8 decimal places)
     * - This rate is the inverse of the deposit token to JPY rate (as returned by getDepositTokenToJpyAverageRate)
     *
     * @notice Example:
     * If the function returns 13699000000, it means the average rate is 1 deposit token = 136.99 JPY
     */
    function getJpyToDepositTokenAverageRate() public view returns (uint256) {
        if (totalDepositToken == 0) {
            return 0;
        }
        return Math.mulDiv(totalMintedJpy, EXCHANGE_RATE_SCALE, totalDepositToken, Math.Rounding.Ceil);
    }

    /**
     * @notice Apply protocol fee to an amount
     * @param amount The amount to apply the fee to
     * @return The amount after applying the fee and the fee amount
     */
    function _applyProtocolFee(uint256 amount) internal view returns (uint256, uint256) {
        uint256 feeAmount = Math.mulDiv(amount, protocolFeeBps, ONE_HUNDRED_PERCENT_IN_BP, Math.Rounding.Ceil);
        uint256 amountAfterFee = amount - feeAmount;
        return (amountAfterFee, feeAmount);
    }

    /**
     * @notice Convert an amount from deposit token to JPY
     * @param amount The amount in deposit token to convert. It is the 6 decimals amount, same as jpyToken.
     * @return The equivalent amount in JPY
     */
    function _convertToJpy(uint256 amount) internal view returns (uint256) {
        (uint256 depositTokenUsdRate, uint8 depositTokenRateDecimals) = getTokenUsdRate(address(depositToken));
        (uint256 jpyUsdRate, uint8 jpyRateDecimals) = getTokenUsdRate(address(jpyToken));

        // Convert deposit token to USD.
        uint256 usdAmount =
            Math.mulDiv(amount, depositTokenUsdRate, 10 ** depositTokenRateDecimals, Math.Rounding.Floor);

        // Then convert USD to JPY
        return Math.mulDiv(usdAmount, 10 ** jpyRateDecimals, jpyUsdRate, Math.Rounding.Floor);
    }

    /**
     * @notice Executes a permit operation or checks for sufficient allowance
     * @dev This function implements a mitigation for the EIP-2612 frontrunning vulnerability
     * @param token The address of the token contract
     * @param owner The address of the token owner
     * @param spender The address of the spender
     * @param value The amount of tokens to be approved
     * @param deadline The deadline for the permit
     * @param v The v component of the signature
     * @param r The r component of the signature
     * @param s The s component of the signature
     * @notice This implementation addresses the vulnerability described in:
     * https://www.trust-security.xyz/post/permission-denied
     */
    function _trustlessPermit(
        address token,
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    )
        internal
    {
        // Try permit() before allowance check to advance nonce if possible
        try IERC20PermitMinimal(token).permit(owner, spender, value, deadline, v, r, s) {
            return;
        } catch {
            // Permit potentially got frontran. Continue anyways if allowance is sufficient.
            if (IERC20(token).allowance(owner, spender) >= value) {
                return;
            }
        }
        revert("Permit failure");
    }

    /*
     * @notice Authorize the upgrade of the implementation contract
     * @dev Only callable by UPGRADER_ROLE
     * @param newImplementation The address of the new implementation contract
     */
    function _authorizeUpgrade(address newImplementation) internal override onlyRole(UPGRADER_ROLE) { }
}