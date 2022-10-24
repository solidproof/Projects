// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import "./EmergencyGuard.sol";
import "./interfaces/IDynamicFeeManager.sol";

/**
 * @title Base Dynamic Fee Manager
 */
abstract contract BaseDynamicFeeManager is
    IDynamicFeeManager,
    EmergencyGuard,
    AccessControlEnumerable,
    Ownable,
    ReentrancyGuard
{
    // Role allowed to do admin operations like adding to fee whitelist, withdraw, etc.
    bytes32 public constant ADMIN = keccak256("ADMIN");

    // Role allowed to bypass fees
    bytes32 public constant FEE_WHITELIST = keccak256("FEE_WHITELIST");

    // Role allowed to token be sent to without fee
    bytes32 public constant RECEIVER_FEE_WHITELIST =
        keccak256("RECEIVER_FEE_WHITELIST");

    // Role allowed to bypass swap and liquify
    bytes32 public constant BYPASS_SWAP_AND_LIQUIFY =
        keccak256("BYPASS_SWAP_AND_LIQUIFY");

    // Role allowed to bypass wildcard fees
    bytes32 public constant EXCLUDE_WILDCARD_FEE =
        keccak256("EXCLUDE_WILDCARD_FEE");

    // Role allowed to call reflectFees
    bytes32 public constant CALL_REFLECT_FEES = keccak256("CALL_REFLECT_FEES");

    // Fee percentage limit
    uint256 public constant FEE_PERCENTAGE_LIMIT = 10_000; // 10%

    // Fee percentage limit on creation
    uint256 public constant INITIAL_FEE_PERCENTAGE_LIMIT = 25_000; // 25%

    // Transaction fee limit
    uint256 public constant TRANSACTION_FEE_LIMIT = 10_000; // 10%

    // Transaction fee limit on creation
    uint256 public constant INITIAL_TRANSACTION_FEE_LIMIT = 25_000; // 25%

    // Max. amount for fee entries
    uint256 public constant MAX_FEE_AMOUNT = 30;

    // Fee divider
    uint256 internal constant FEE_DIVIDER = 100_000;

    // Wildcard address for fees
    address internal constant WHITELIST_ADDRESS =
        0x000000000000000000000000000000000000dEaD;

    // List of all currently added fees
    FeeEntry[] internal feeEntries;

    // Mapping id to current liquify or swap amounts
    mapping(bytes32 => uint256) internal feeEntryAmounts;

    // Fees enabled state
    bool private _feesEnabled = false;

    // Pancake Router address
    IPancakeRouter02 private _pancakeRouter =
        IPancakeRouter02(address(0x10ED43C718714eb63d5aA57B78B54704E256024E));

    // BUSD address
    address private _busdAddress;

    // Fee Decrease status
    bool private _feeDecreased = false;

    // Volume percentage for swap events
    uint256 private _percentageVolumeSwap = 0;

    // Volume percentage for liquify events
    uint256 private _percentageVolumeLiquify = 0;

    // Pancakeswap Pair (WSI <-> BUSD) address
    address private _pancakePairBusdAddress;

    // Pancakeswap Pair (WSI <-> BNB) address
    address private _pancakePairBnbAddress;

    // WeSendit token
    IERC20 private _token;

    constructor(address wesenditToken) {
        // Add creator to admin role
        _setupRole(ADMIN, _msgSender());

        // Set role admin for roles
        _setRoleAdmin(ADMIN, ADMIN);
        _setRoleAdmin(FEE_WHITELIST, ADMIN);
        _setRoleAdmin(RECEIVER_FEE_WHITELIST, ADMIN);
        _setRoleAdmin(BYPASS_SWAP_AND_LIQUIFY, ADMIN);
        _setRoleAdmin(EXCLUDE_WILDCARD_FEE, ADMIN);
        _setRoleAdmin(CALL_REFLECT_FEES, ADMIN);

        // Create WeSendit token instance
        _token = IERC20(wesenditToken);
    }

    /**
     * Getter & Setter
     */
    function getFee(uint256 index)
        external
        view
        override
        returns (FeeEntry memory fee)
    {
        return feeEntries[index];
    }

    function getFeeAmount(bytes32 id)
        external
        view
        override
        returns (uint256 amount)
    {
        return feeEntryAmounts[id];
    }

    function setFeesEnabled(bool value) external override onlyRole(ADMIN) {
        _feesEnabled = value;

        emit FeeEnabledUpdated(value);
    }

    function setPancakeRouter(address value) external override onlyRole(ADMIN) {
        require(
            value != address(0),
            "DynamicFeeManager: Cannot set Pancake Router to zero address"
        );

        _pancakeRouter = IPancakeRouter02(value);
        emit PancakeRouterUpdated(value);
    }

    function setBusdAddress(address value) external override onlyRole(ADMIN) {
        require(
            value != address(0),
            "DynamicFeeManager: Cannot set BUSD to zero address"
        );

        _busdAddress = value;
        emit BusdAddressUpdated(value);
    }

    function feeDecreased() external view override returns (bool value) {
        return _feeDecreased;
    }

    function decreaseFeeLimits() external override onlyRole(ADMIN) {
        require(
            !_feeDecreased,
            "DynamicFeeManager: Fee limits are already decreased"
        );

        _feeDecreased = true;

        emit FeeLimitsDecreased();
    }

    function emergencyWithdraw(uint256 amount)
        external
        override
        onlyRole(ADMIN)
    {
        super._emergencyWithdraw(amount);
    }

    function emergencyWithdrawToken(address tokenToWithdraw, uint256 amount)
        external
        override
        onlyRole(ADMIN)
    {
        super._emergencyWithdrawToken(tokenToWithdraw, amount);
    }

    function setPercentageVolumeSwap(uint256 value)
        external
        override
        onlyRole(ADMIN)
    {
        require(
            value <= 100,
            "DynamicFeeManager: Invalid percentage volume swap value"
        );

        _percentageVolumeSwap = value;

        emit PercentageVolumeSwapUpdated(value);
    }

    function setPercentageVolumeLiquify(uint256 value)
        external
        override
        onlyRole(ADMIN)
    {
        require(
            value <= 100,
            "DynamicFeeManager: Invalid percentage volume liquify value"
        );

        _percentageVolumeLiquify = value;

        emit PercentageVolumeLiquifyUpdated(value);
    }

    function setPancakePairBusdAddress(address value)
        external
        override
        onlyRole(ADMIN)
    {
        require(
            value != address(0),
            "DynamicFeeManager: Cannot set BUSD pair to zero address"
        );

        _pancakePairBusdAddress = value;

        emit PancakePairBusdUpdated(value);
    }

    function setPancakePairBnbAddress(address value)
        external
        override
        onlyRole(ADMIN)
    {
        require(
            value != address(0),
            "DynamicFeeManager: Cannot set BNB pair to zero address"
        );

        _pancakePairBnbAddress = value;

        emit PancakePairBnbUpdated(value);
    }

    function feesEnabled() public view override returns (bool) {
        return _feesEnabled;
    }

    function pancakeRouter()
        public
        view
        override
        returns (IPancakeRouter02 value)
    {
        return _pancakeRouter;
    }

    function busdAddress() public view override returns (address value) {
        return _busdAddress;
    }

    function feePercentageLimit() public view override returns (uint256 value) {
        return
            _feeDecreased ? FEE_PERCENTAGE_LIMIT : INITIAL_FEE_PERCENTAGE_LIMIT;
    }

    function transactionFeeLimit()
        public
        view
        override
        returns (uint256 value)
    {
        return
            _feeDecreased
                ? TRANSACTION_FEE_LIMIT
                : INITIAL_TRANSACTION_FEE_LIMIT;
    }

    function percentageVolumeSwap()
        public
        view
        override
        returns (uint256 value)
    {
        return _percentageVolumeSwap;
    }

    function percentageVolumeLiquify()
        public
        view
        override
        returns (uint256 value)
    {
        return _percentageVolumeLiquify;
    }

    function pancakePairBusdAddress()
        public
        view
        override
        returns (address value)
    {
        return _pancakePairBusdAddress;
    }

    function pancakePairBnbAddress()
        public
        view
        override
        returns (address value)
    {
        return _pancakePairBnbAddress;
    }

    function token() public view override returns (IERC20 value) {
        return _token;
    }

    /**
     * Swaps half of the token amount and add liquidity on Pancakeswap
     *
     * @param amount uint256 - Amount to use
     * @param destination address - Destination address for the LP tokens
     *
     * @return tokenSwapped uint256 - Amount of token which have been swapped
     */
    function _swapAndLiquify(uint256 amount, address destination)
        internal
        nonReentrant
        returns (uint256 tokenSwapped)
    {
        // split the contract balance into halves
        uint256 half = amount / 2;
        uint256 otherHalf = amount - half;

        // capture the contract's current BNB balance.
        // this is so that we can capture exactly the amount of BNB that the
        // swap creates, and not make the liquidity event include any BNB that
        // has been manually sent to the contract
        uint256 initialBalance = address(this).balance;

        // swap tokens for BNB
        _swapTokensForBnb(half, address(this));

        // how much BNB did we just swap into?
        uint256 newBalance = address(this).balance - initialBalance;

        // add liquidity to uniswap
        uint256 tokenLiquified = _addLiquidity(
            otherHalf,
            newBalance,
            destination
        );

        emit SwapAndLiquify(half, newBalance, otherHalf);

        return half + tokenLiquified;
    }

    /**
     * Swaps tokens against BNB on Pancakeswap
     *
     * @param amount uint256 - Amount to use
     * @param destination address - Destination address for BNB
     */
    function _swapTokensForBnb(uint256 amount, address destination) internal {
        // generate the uniswap pair path of token -> wbnb
        address[] memory path = new address[](2);
        path[0] = address(token());
        path[1] = pancakeRouter().WETH();

        require(
            token().approve(address(pancakeRouter()), amount),
            "DynamicFeeManager: Failed to approve token for swap to BNB"
        );

        // make the swap
        pancakeRouter().swapExactTokensForETHSupportingFeeOnTransferTokens(
            amount,
            0, // accept any amount of BNB
            path,
            destination,
            block.timestamp
        );
    }

    /**
     * Swaps tokens against BUSD on Pancakeswap
     *
     * @param amount uint256 - Amount to use
     * @param destination address - Destination address for BUSD
     */
    function _swapTokensForBusd(uint256 amount, address destination)
        internal
        nonReentrant
    {
        // generate the uniswap pair path of token -> wbnb
        address[] memory path = new address[](2);
        path[0] = address(token());
        path[1] = busdAddress();

        require(
            token().approve(address(pancakeRouter()), amount),
            "DynamicFeeManager: Failed to approve token for swap to BUSD"
        );

        // capture the contract's current balances
        uint256 initialBalance = IERC20(busdAddress()).balanceOf(destination);

        // make the swap
        pancakeRouter().swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount,
            0, // accept any amount of BUSD
            path,
            destination,
            block.timestamp
        );

        // how much BUSD did we just swap into?
        uint256 newBalance = IERC20(busdAddress()).balanceOf(destination) -
            initialBalance;

        emit SwapTokenForBusd(
            address(token()),
            amount,
            newBalance,
            destination
        );
    }

    /**
     * Creates liquidity on Pancakeswap
     *
     * @param tokenAmount uint256 - Amount of token to use
     * @param bnbAmount uint256 - Amount of BNB to use
     * @param destination address - Destination address for the LP tokens
     *
     * @return tokenSwapped uint256 - Amount of token which have been swapped
     */
    function _addLiquidity(
        uint256 tokenAmount,
        uint256 bnbAmount,
        address destination
    ) internal returns (uint256 tokenSwapped) {
        // approve token transfer to cover all possible scenarios
        require(
            token().approve(address(pancakeRouter()), tokenAmount),
            "DynamicFeeManager: Failed to approve token for adding liquidity"
        );

        // add the liquidity
        (tokenSwapped, , ) = pancakeRouter().addLiquidityETH{value: bnbAmount}(
            address(token()),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            destination,
            block.timestamp
        );

        return tokenSwapped;
    }

    /**
     * Returns the amount used for swap / liquify based on volume percentage for swap / liquify
     *
     * @param swapOrLiquifyAmount uint256 - Fee entry swap or liquify amount
     * @param percentageVolume uint256 - Volume percentage for swap / liquify
     * @param pancakePairAddress address - Pancakeswap pair address to use for volume
     *
     * @return amount uint256 - Amount used for swap / liquify
     */
    function _getSwapOrLiquifyAmount(
        uint256 swapOrLiquifyAmount,
        uint256 percentageVolume,
        address pancakePairAddress
    ) internal view returns (uint256 amount) {
        if (pancakePairAddress == address(0) || percentageVolume == 0) {
            return swapOrLiquifyAmount;
        }

        // Get pancakeswap pair token balance to identify, how many
        // token are currently on the market
        uint256 pancakePairTokenBalance = token().balanceOf(pancakePairAddress);

        // Calculate percentual amount of volume
        uint256 percentualAmount = (pancakePairTokenBalance *
            percentageVolume) / 100;

        // Do not exceed swap or liquify amount from fee entry
        if (percentualAmount >= swapOrLiquifyAmount) {
            return swapOrLiquifyAmount;
        }

        return percentualAmount;
    }
}
