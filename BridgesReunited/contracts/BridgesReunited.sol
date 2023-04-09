// SPDX-License-Identifier: Unlicensed

import "@pancakeswap/pancake-contracts/interfaces/IBEP20.sol";
import "@pancakeswap-libs/pancake-swap-core/contracts/interfaces/IPancakeFactory.sol";
import "@pancakeswap-libs/pancake-swap-core/contracts/interfaces/IPancakePair.sol";
import "@pancakeswap/pancake-contracts/interfaces/IPancakeRouter02.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

pragma solidity ^0.8.19;

contract BridgesReunited is Context, IBEP20, Ownable, ReentrancyGuard {
    using Address for address;

    // Mappings
    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) private _isExcluded;
    mapping(address => bool) public _isExcludedFromAntiWhale;
    mapping(address => bool) private _AddressExists;
    mapping(address => bool) private _isExcludedFromLottery;

    // Address arrays
    address[] private _addressList;
    address[] private _excluded;

    // Lottery related variables
    address private _lottoPotAddress;
    address private _lottoWalletAddress;
    uint256 public _lastLottoWinnerAmount;
    uint256 public _totalLottoPrize;
    uint public _lottoDrawCount;

    // Fee related variables
    uint256 public maxIterations;
    uint256[] private fees;
    uint256[] private previousFees;
    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal = 28 * 10 ** 6 * 10 ** DECIMALS;
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _minLottoBalance = 28 * 10 ** 3 * 10 ** DECIMALS;
    uint256 public _maxTxAmount = 28 * 10 ** 6 * 10 ** DECIMALS;
    uint256 public constant MAX_ALLOWED_FEE = 1500;

    // Liquidity related variables
    uint256 private numTokensSellToAddToLiquidity;
    uint256 private numTokensSellToAddToLiquidityTrigger;

    // Threshold related variables
    uint256 public lotteryThreshold = 28 * 10 ** 2 * 10 ** DECIMALS;
    uint256 public _AntiWhaleThreshold = 31 * 10 ** 4 * 10 ** DECIMALS;

    // Wallet addresses
    address payable private _exchangeWallet;
    address payable private _teamWallet;
    address payable private _marketingAsiaWallet;
    address payable private _marketingAfricaWallet;
    address payable private _marketingNorthAmericaWallet;
    address payable private _marketingSouthAmericaWallet;
    address payable private _marketingAntarcticaWallet;
    address payable private _marketingEuropeWallet;
    address payable private _marketingAustraliaWallet;
    address payable private _devWallet;
    address payable private _lottoWallet;

    // Pancake related variables
    IPancakeRouter02 public pancakeRouter;
    IPancakePair public pancakePair;

    // Boolean flags
    bool public _isAntiWhaleEnabled = true;
    bool public swapAndLiquifyEnabled = true;
    bool public lottoEnabled = true;
    bool private inSwapAndLiquify;
    bool inLotteryDraw;
    bool private _callSwapAndLiquify = true;

    // Token details
    string private _name = "Bridges Reunited";
    string private _symbol = "BRT";
    uint8 constant DECIMALS = 9;

    // FeeType enum
    enum FeeType {
        _LiquidityFee,
        _LottoFee,
        _DevFee,
        _TeamFee,
        _ExchangeFee,
        _MarketingAsiaFee,
        _MarketingAfricaFee,
        _MarketingNorthAmericaFee,
        _MarketingSouthAmericaFee,
        _MarketingAntarcticaFee,
        _MarketingEuropeFee,
        _MarketingAustraliaFee
    }

    // Structs
    struct TData {
        uint256 tAmount;
        BridgesMarketingData marketingData;
        BridgesTeamData teamData;
        BridgesSystemData systemData;
        uint256 currentRate;
    }

    struct BridgesMarketingData {
        uint256[7] fees; // An array to store the marketing fees
    }

    struct BridgesTeamData {
        uint256[3] fees; // An array to store the team fees
    }

    struct BridgesSystemData {
        uint256[2] fees; // An array to store the system fees
    }

    // Events
    event NumTokensSellToAddToLiquidityUpdated(
        uint256 newNumTokensSellToAddToLiquidity
    );
    event NumTokensSellToAddToLiquidityUpdatedTrigger(
        uint256 newNumTokensSellToAddToLiquidity
    );
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event DrawLotto(uint256 amount, uint _lottoDrawCount);
    event SkippedDrawLotto(uint256 lottoBalance, uint256 lotteryThreshold);

    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived,
        uint256 tokensIntoLiqudity
    );
    event TokensWithdrawn(
        address tokenAddress,
        address recipient,
        uint256 amount
    );

    // Modifiers
    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    modifier lockTheLottery() {
        inLotteryDraw = true;
        _;
        inLotteryDraw = false;
    }

    constructor() {
        // Set initial owner reflection and add address
        _rOwned[_msgSender()] = _rTotal;
        addAddress(_msgSender());

        // Initialize lotto pot address
        _lottoPotAddress = address(1);

        // Set up PancakeRouter
        IPancakeRouter02 _pancakeRouter = IPancakeRouter02(
            0xD99D1c33F9fC3444f8101754aBC46c52416550D1
        );
        address pancakePairAddress = IPancakeFactory(_pancakeRouter.factory())
            .createPair(address(this), _pancakeRouter.WETH());
        pancakePair = IPancakePair(pancakePairAddress);
        pancakeRouter = _pancakeRouter;

        // Exclude owner, lotto pot and contract from fees
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[_lottoPotAddress] = true;
        _isExcludedFromFee[address(this)] = true;

        // Exclude owner, lotto pot, contract, router, and pair from AntiWhale
        _isExcludedFromAntiWhale[owner()] = true;
        _isExcludedFromAntiWhale[_lottoPotAddress] = true;
        _isExcludedFromAntiWhale[address(this)] = true;
        _isExcludedFromAntiWhale[address(pancakeRouter)] = true;
        _isExcludedFromAntiWhale[address(pancakePair)] = true;

        // Set max iterations and token sale limits
        maxIterations = 1;
        numTokensSellToAddToLiquidity = 14 * 10 ** 6 * 10 ** DECIMALS;
        numTokensSellToAddToLiquidityTrigger = 4 * 10 ** 4 * 10 ** DECIMALS;
        lotteryThreshold = 28 * 10 ** 2 * 10 ** DECIMALS;

        // Initialize fees
        _initializeFees();


        // Emit initial transfer event
        emit Transfer(address(0), _msgSender(), _tTotal);
    }


    //-------------------------------------------------------------------------
    //Token-related Functions
    //-------------------------------------------------------------------------


    /**
     * @dev Approves the specified amount of tokens to the specified spender.
     * @param owner The owner of the tokens.
     * @param spender The spender to approve for spending the tokens.
     * @param amount The amount of tokens to approve.
     */
    function _approve(address owner, address spender, uint256 amount) private {
        // Make sure the owner and spender addresses are not zero
        require(owner != address(0) && spender != address(0), "Err");
        // Set the allowance for the specified owner and spender
        _allowances[owner][spender] = amount;
        // Emit an Approval event
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Gets the current total supply of tokens.
     * @return rSupply The current supply of reflected tokens.
     * @return tSupply The current supply of total tokens.
     */
    function _getCurrentSupply()
        private
        view
        returns (uint256 rSupply, uint256 tSupply)
    {
        // Start with the total supply
        rSupply = _rTotal;
        tSupply = _tTotal;
        // Subtract the balances of all excluded addresses
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (
                _rOwned[_excluded[i]] > rSupply ||
                _tOwned[_excluded[i]] > tSupply
            ) {
                return (_rTotal, _tTotal);
            }
            rSupply -= _rOwned[_excluded[i]];
            tSupply -= _tOwned[_excluded[i]];
        }
        // Check if the remaining reflected supply is less than the minimum possible value
        if (rSupply < _rTotal / _tTotal) {
            return (_rTotal, _tTotal);
        }
        // Return the remaining supply values
        return (rSupply, tSupply);
    }
    /**
    // Returns values needed for the transfer
    // @param tAmount The transfer amount
    // @return rAmount The converted amount for the recipient
    // @return rTransferAmount The converted transfer amount
    // @return tTransferAmount The transfer amount minus fees
    // @return systemData The system fee data
    // @return teamData The team fee data
    // @return marketingData The marketing fee data
     */
    function _getValues(
        uint256 tAmount
    )
        private
        view
        returns (
            uint256,
            uint256,
            uint256,
            BridgesSystemData memory,
            BridgesTeamData memory,
            BridgesMarketingData memory
        )
    {
        // Get transfer values
        uint256 tTransferAmount = _getTValues(tAmount);
        uint256 currentRate = _getRate();
        uint256 rAmount = _calculateRValue(tAmount, currentRate);
        uint256 rTransferAmount = _calculateRValue(
            tTransferAmount,
            currentRate
        );

        // Get fee data
        BridgesSystemData memory systemData = _getSystemValues(tAmount);
        BridgesTeamData memory teamData = _getTeamValues(tAmount);
        BridgesMarketingData memory marketingData = _getMarketingValues(
            tAmount
        );

        // Return all necessary data
        return (
            rAmount,
            rTransferAmount,
            tTransferAmount,
            systemData,
            teamData,
            marketingData
        );
    }

    /**
     * @dev This method is responsible for taking all fees, if takeFee is true. It chooses the appropriate transfer method based on whether the sender and recipient are excluded from reward.
     * @param sender The address of the sender
     * @param recipient The address of the recipient
     * @param amount The amount of tokens to transfer
     * @param takeFee Boolean indicating whether or not to take fees
     */
    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        if (!takeFee) removeAllFee();

        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            // Transfer from excluded
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            // Transfer to excluded
            _transferToExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            // Standard transfer
            _transferStandard(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            // Transfer between excluded
            _transferBothExcluded(sender, recipient, amount);
        } else {
            // Standard transfer
            _transferStandard(sender, recipient, amount);
        }

        if (!takeFee) restoreAllFee();
    }

    /**
     * @dev Transfers the specified amount of tokens from one address to another.
     * @param from The address to transfer tokens from.
     * @param to The address to transfer tokens to.
     * @param amount The amount of tokens to transfer.
     */
    function _transfer(address from, address to, uint256 amount) private {
        // Make sure the from and to addresses are not zero
        require(from != address(0), "BEP20: transfer from the zero address");
        require(to != address(0), "BEP20: transfer to the zero address");
        // Make sure the transfer amount is greater than zero
        require(amount > 0, "Transfer amount must be greater than zero");
        // If the transaction is not initiated by the owner, make sure the transfer amount does not exceed the maximum allowed transaction amount
        if (from != owner() && to != owner()) {
            require(
                amount <= _maxTxAmount,
                "Transfer amount exceeds the maxTxAmount."
            );
        }

        // Check if the contract token balance is greater than or equal to the maximum allowed transaction amount
        uint256 contractTokenBalance = balanceOf(address(this));
        if (contractTokenBalance >= _maxTxAmount) {
            contractTokenBalance = _maxTxAmount;
        }

        // Check if the contract token balance is greater than or equal to the minimum number of tokens to sell to add liquidity and if the lottery balance is greater than or equal to the lottery threshold
        bool overMinTokenBalance = contractTokenBalance >=
            numTokensSellToAddToLiquidity;
        uint256 lottoBalance = balanceOf(_lottoPotAddress);
        bool overMinLottoBalance = lottoBalance >= lotteryThreshold;

        // If both conditions are met, decide whether to call the swapAndLiquify or drawLotto function based on the `_callSwapAndLiquify` variable
        if (overMinTokenBalance && overMinLottoBalance) {
            if (_callSwapAndLiquify) {
                if (
                    !inSwapAndLiquify &&
                    from != address(pancakePair) &&
                    swapAndLiquifyEnabled
                ) {
                    // If not currently in swapAndLiquify function and the transaction is not initiated by the PancakeSwap pair contract and swapAndLiquify is enabled, call the swapAndLiquify function with the specified number of tokens to sell
                    contractTokenBalance = numTokensSellToAddToLiquidity;
                    swapAndLiquify(contractTokenBalance);
                }
            } else {
                // If not currently in lottery draw and lotto is enabled, call the drawLotto function
                if (!inLotteryDraw && lottoEnabled) {
                    drawLotto();
                }
            }
            // Toggle the `_callSwapAndLiquify` variable
            _callSwapAndLiquify = !_callSwapAndLiquify;
        } else if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            from != address(pancakePair) &&
            swapAndLiquifyEnabled
        ) {
            // If the contract token balance is greater than or equal to the minimum number of tokens to sell to add liquidity, and not currently in swapAndLiquify function, the transaction is not initiated by the PancakeSwap pair contract, and swapAndLiquify is enabled, call the swapAndLiquify function with the specified number of tokens to sell
            contractTokenBalance = numTokensSellToAddToLiquidity;
            swapAndLiquify(contractTokenBalance);
        } else if (overMinLottoBalance && !inLotteryDraw && lottoEnabled) {
            // If the lottery balance is greater than or equal to the lottery threshold, and not currently in lottery draw, and lotto is enabled, call the drawLotto function
            drawLotto();
        }

        // If anti-whale feature is enabled and the recipient is not excluded from anti-whale, perform anti-whale check
        if (_isAntiWhaleEnabled && !_isExcludedFromAntiWhale[to]) {
            if (from == address(pancakePair) && to != address(pancakeRouter)) {
                // If the transaction is initiated by the PancakeSwap pair contract and the recipient is not PancakeSwap router contract, make sure the transfer amount and recipient's balance do not exceed the anti-whale threshold
                require(
                    amount <= _AntiWhaleThreshold,
                    "Anti whale: can't buy more than the specified threshold"
                );
                require(
                    balanceOf(to) + amount <= _AntiWhaleThreshold,
                    "Anti whale: can't hold more than the specified threshold"
                );
            }
        }

        // By default, take fee
        bool takeFee = true;

        // If either the sender or the recipient is excluded from fee, do not take fee
        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            takeFee = false;
        }

        // Add sender and recipient to the address list
        addAddress(from);
        addAddress(to);

        // Transfer tokens, take fee if necessary
        _tokenTransfer(from, to, amount, takeFee);
    }

    /**
     * @dev Transfer tokens from sender to recipient with fee deductions for system, marketing, and team.
     * @param sender The address of the sender.
     * @param recipient The address of the recipient.
     * @param tAmount The amount of tokens to transfer.
     */
    function _transferBothExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        // Get the necessary values for transfer.
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 tTransferAmount,
            BridgesSystemData memory systemData,
            BridgesTeamData memory teamData,
            BridgesMarketingData memory marketingData
        ) = _getValues(tAmount);

        // Subtract the transferred amount from the sender's balance.
        _tOwned[sender] -= tAmount;
        _rOwned[sender] -= rAmount;

        // Add the transferred amount to the recipient's balance.
        _tOwned[recipient] += tTransferAmount;
        _rOwned[recipient] += rTransferAmount;

        // Take system and lottery fees.
        _takeFees(
            address(this),
            systemData.fees[0],
            _isExcluded[address(this)]
        );
        _takeFees(
            _lottoPotAddress,
            systemData.fees[1],
            _isExcluded[_lottoPotAddress]
        );

        // Take marketing and team fees.
        _takeMarketingFees(marketingData);
        _takeTeamFees(teamData);

        // Emit transfer event.
        emit Transfer(sender, recipient, tTransferAmount);
    }

    /**
     * @dev Returns the number of decimals used by the token.
     * @return The number of decimals used by the token as a uint8.
     */
    function decimals() external pure returns (uint8) {
        return DECIMALS;
    }

    /**
     * @dev Fallback function to receive BNB.
     */
    receive() external payable {}

    /**
     * @dev Converts an amount of tokens to the corresponding amount of reflections.
     * @param tAmount The amount of tokens to convert.
     * @param deductTransferFee A boolean indicating whether the transfer fee should be deducted.
     * @return The corresponding amount of reflections as a uint256.
     */
    function reflectionFromToken(
        uint256 tAmount,
        bool deductTransferFee
    ) private view returns (uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount, , , , , ) = _getValues(tAmount);
            return rAmount;
        } else {
            (, uint256 rTransferAmount, , , , ) = _getValues(tAmount);
            return rTransferAmount;
        }
    }

    /**
     * @dev Gets the current exchange rate.
     * @return The current exchange rate.
     */
    function _getRate() private view returns (uint256) {
        // Get the current supply of reflected and total tokens
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        // Calculate and return the exchange rate
        return rSupply / tSupply;
    }

    /**
     * @dev Adds an address to the list of existing addresses.
     * @param adr The address to add.
     */
    function addAddress(address adr) private {
        // If the address already exists, return
        if (_AddressExists[adr]) {
            return;
        }
        // Otherwise, add the address to the list and mark it as existing
        _AddressExists[adr] = true;
        _addressList.push(adr);
    }


    //-------------------------------------------------------------------------
    // Fees-related Functions
    //-------------------------------------------------------------------------

   /**
     * @dev Initializes the fees array and previousFees array.
     *      Sets default values for all fees.
     */
     function _initializeFees() private {
        // Initialize fees array with length 12 (for all 12 fees)
        fees = new uint256[](12);
        // Initialize previousFees array with length 12
        previousFees = new uint256[](12);

        // Set initial values for all fees
        fees[uint256(FeeType._LiquidityFee)] = 400;
        fees[uint256(FeeType._LottoFee)] = 59;
        fees[uint256(FeeType._DevFee)] = 100;
        fees[uint256(FeeType._TeamFee)] = 100;
        fees[uint256(FeeType._ExchangeFee)] = 50;
        fees[uint256(FeeType._MarketingAsiaFee)] = 100;
        fees[uint256(FeeType._MarketingAfricaFee)] = 1;
        fees[uint256(FeeType._MarketingNorthAmericaFee)] = 10;
        fees[uint256(FeeType._MarketingSouthAmericaFee)] = 10;
        fees[uint256(FeeType._MarketingAntarcticaFee)] = 10;
        fees[uint256(FeeType._MarketingEuropeFee)] = 30;
        fees[uint256(FeeType._MarketingAustraliaFee)] = 30;

        // Set previousFees array to the same initial values as fees array
        for (uint256 i = 0; i < fees.length; i++) {
            previousFees[i] = fees[i];
        }
    }
    /**
     * @dev Calculates the R value by multiplying the total value with the current rate.
     * @param tValue The total value to calculate the R value for.
     * @param currentRate The current exchange rate.
     * @return The R value.
     */
    function _calculateRValue(
        uint256 tValue,
        uint256 currentRate
    ) private pure returns (uint256) {
        return tValue * currentRate;
    }

    /**
     * @dev Calculates the marketing fees for the given transaction amount.
     * @param tAmount The transaction amount.
     * @return BridgesMarketingData The struct containing the calculated marketing fees.
     */
    function _getMarketingValues(
        uint256 tAmount
    ) private view returns (BridgesMarketingData memory) {
        uint256[7] memory marketingFees = [
            calculateFee(tAmount, FeeType._MarketingAsiaFee),
            calculateFee(tAmount, FeeType._MarketingAfricaFee),
            calculateFee(tAmount, FeeType._MarketingNorthAmericaFee),
            calculateFee(tAmount, FeeType._MarketingSouthAmericaFee),
            calculateFee(tAmount, FeeType._MarketingAntarcticaFee),
            calculateFee(tAmount, FeeType._MarketingEuropeFee),
            calculateFee(tAmount, FeeType._MarketingAustraliaFee)
        ];

        BridgesMarketingData memory marketingData = BridgesMarketingData({
            fees: marketingFees
        });

        return marketingData;
    }

    // Returns system fee values for the given transfer amount
    // @param tAmount The transfer amount
    // @return BridgesSystemData The system fee data
    function _getSystemValues(
        uint256 tAmount
    ) private view returns (BridgesSystemData memory) {
        // Calculate system fees for liquidity and lottery fees
        uint256[2] memory systemFees = [
            calculateFee(tAmount, FeeType._LiquidityFee),
            calculateFee(tAmount, FeeType._LottoFee)
        ];

        // Store system fee data in a struct
        BridgesSystemData memory systemData = BridgesSystemData({
            fees: systemFees
        });

        // Return system fee data
        return systemData;
    }

    /**
     * @dev Returns the transfer amount minus all fees
     * @param tAmount The transfer amount
     * @return The transfer amount minus all fees
     */
    function _getTValues(uint256 tAmount) private view returns (uint256) {
        // Get fee data for system, team, and marketing fees
        BridgesSystemData memory systemData = _getSystemValues(tAmount);
        BridgesTeamData memory teamData = _getTeamValues(tAmount);
        BridgesMarketingData memory marketingData = _getMarketingValues(
            tAmount
        );

        // Calculate total fees for system, team, and marketing fees
        uint256 totalSystemFees = _getTotalSystemFees(systemData);
        uint256 totalTeamFees = _getTotalTeamFees(teamData);
        uint256 totalMarketingFees = _getTotalMarketingFees(marketingData);

        // Calculate total fees
        uint256 totalFees = totalSystemFees +
            totalTeamFees +
            totalMarketingFees;

        // Calculate transfer amount minus fees
        uint256 tTransferAmount = tAmount - totalFees;

        // Return transfer amount minus fees
        return tTransferAmount;
    }

    // Returns team fee values for the given transfer amount
    // @param tAmount The transfer amount
    // @return BridgesTeamData The team fee data
    function _getTeamValues(
        uint256 tAmount
    ) private view returns (BridgesTeamData memory) {
        // Calculate team fees for developer, exchange, and team fees
        uint256[3] memory teamFees = [
            calculateFee(tAmount, FeeType._DevFee),
            calculateFee(tAmount, FeeType._ExchangeFee),
            calculateFee(tAmount, FeeType._TeamFee)
        ];

        // Store team fee data in a struct
        BridgesTeamData memory teamData = BridgesTeamData({fees: teamFees});

        // Return team fee data
        return teamData;
    }

    /**
     * @dev Returns the total marketing fees
     * @param marketingData The marketing fee data
     * @return The total marketing fees
     */
    function _getTotalMarketingFees(
        BridgesMarketingData memory marketingData
    ) private pure returns (uint256) {
        // Calculate total marketing fees by summing all marketing fees
        return
            marketingData.fees[0] +
            marketingData.fees[1] +
            marketingData.fees[2] +
            marketingData.fees[3] +
            marketingData.fees[4] +
            marketingData.fees[5] +
            marketingData.fees[6];
    }

    /**
     * @dev Returns the total system fees
     * @param systemData The system fee data
     * @return The total system fees
     */
    function _getTotalSystemFees(
        BridgesSystemData memory systemData
    ) private pure returns (uint256) {
        // Calculate total system fees by summing liquidity and lottery fees
        return systemData.fees[0] + systemData.fees[1];
    }

    /**
     * @dev Returns the total team fees
     * @param teamData The team fee data
     * @return The total team fees
     */
    function _getTotalTeamFees(
        BridgesTeamData memory teamData
    ) private pure returns (uint256) {
        // Calculate total team fees by summing developer, exchange, and team fees
        return teamData.fees[0] + teamData.fees[1] + teamData.fees[2];
    }

    /**
     * @dev Calculates the R values for the transfer
     * @param tAmount The transfer amount
     * @param currentRate The current exchange rate
     * @param systemData The system fee data
     * @param teamData The team fee data
     * @param marketingData The marketing fee data
     * @return The R values for the transfer
     */
    function _getRValues(
        uint256 tAmount,
        uint256 currentRate,
        BridgesSystemData memory systemData,
        BridgesTeamData memory teamData,
        BridgesMarketingData memory marketingData
    ) private pure returns (uint256, uint256) {
        // Calculate R values for each fee
        uint256 rAmount = _calculateRValue(tAmount, currentRate);
        uint256 rLiquidity = _calculateRValue(systemData.fees[0], currentRate);
        uint256 rLotto = _calculateRValue(systemData.fees[1], currentRate);
        uint256 rDev = _calculateRValue(teamData.fees[0], currentRate);
        uint256 rTeam = _calculateRValue(teamData.fees[1], currentRate);
        uint256 rExchange = _calculateRValue(teamData.fees[2], currentRate);
        uint256 rMarketingAsia = _calculateRValue(
            marketingData.fees[0],
            currentRate
        );
        uint256 rMarketingAfrica = _calculateRValue(
            marketingData.fees[1],
            currentRate
        );
        uint256 rMarketingNorthAmerica = _calculateRValue(
            marketingData.fees[2],
            currentRate
        );
        uint256 rMarketingSouthAmerica = _calculateRValue(
            marketingData.fees[3],
            currentRate
        );
        uint256 rMarketingAntarctica = _calculateRValue(
            marketingData.fees[4],
            currentRate
        );
        uint256 rMarketingEurope = _calculateRValue(
            marketingData.fees[5],
            currentRate
        );
        uint256 rMarketingAustralia = _calculateRValue(
            marketingData.fees[6],
            currentRate
        );

        // Calculate R transfer amount by subtracting all fee R values from total R value
        uint256 rTransferAmount = rAmount -
            rLiquidity -
            rLotto -
            rDev -
            rTeam -
            rExchange -
            rMarketingAsia -
            rMarketingAfrica -
            rMarketingNorthAmerica -
            rMarketingSouthAmerica -
            rMarketingAntarctica -
            rMarketingEurope -
            rMarketingAustralia;

        // Return R values for the transfer
        return (rAmount, rTransferAmount);
    }
  
    /**
     * @dev Sets all fees to zero by iterating through the `fees` array and setting non-zero values to zero.
     * Stores the previous non-zero fees in the `previousFees` array.
     */
    function removeAllFee() private {
        for (uint256 i = 0; i < fees.length; i++) {
            // If the fee is already zero, skip to the next iteration
            if (fees[i] == 0) {
                continue;
            }

            // Store the previous non-zero fee value
            previousFees[i] = fees[i];
            // Set the current fee to zero
            fees[i] = 0;
        }
    }

    /**
     * @dev Restores all previously set fees by iterating through the `fees` array and setting the values to the corresponding values in the `previousFees` array.
     */
    function restoreAllFee() private {
        for (uint256 i = 0; i < fees.length; i++) {
            // Set the current fee to its previous non-zero value
            fees[i] = previousFees[i];
        }
    }

    /**
     * @dev Takes the specified fee from the transaction and adds it to the specified wallet's balance.
     * @param wallet The wallet to add the fee to.
     * @param fee The fee amount to take.
     * @param isExcluded True if the wallet is excluded from reflections, false otherwise.
     */
    function _takeFees(address wallet, uint256 fee, bool isExcluded) private {
        // Calculate the current exchange rate
        uint256 currentRate = _getRate();
        // Calculate the reflected fee amount
        uint256 rFee = fee * currentRate;

        // Add the reflected fee amount to the specified wallet's balance
        _rOwned[wallet] += rFee;
        // If the wallet is excluded from reflections, add the actual fee amount to its balance as well
        if (isExcluded) {
            _tOwned[wallet] += fee;
        }
    }

    /**
     * @dev Takes marketing fees from the transaction and transfers them to the appropriate wallets.
     * @param marketingData The data struct containing the marketing fees.
     */
    function _takeMarketingFees(
        BridgesMarketingData memory marketingData
    ) private {
        // Transfer marketing fees to each marketing wallet
        _takeFees(
            _marketingAsiaWallet,
            marketingData.fees[0],
            _isExcluded[_marketingAsiaWallet]
        );
        _takeFees(
            _marketingAfricaWallet,
            marketingData.fees[1],
            _isExcluded[_marketingAfricaWallet]
        );
        _takeFees(
            _marketingNorthAmericaWallet,
            marketingData.fees[2],
            _isExcluded[_marketingNorthAmericaWallet]
        );
        _takeFees(
            _marketingSouthAmericaWallet,
            marketingData.fees[3],
            _isExcluded[_marketingSouthAmericaWallet]
        );
        _takeFees(
            _marketingAntarcticaWallet,
            marketingData.fees[4],
            _isExcluded[_marketingAntarcticaWallet]
        );
        _takeFees(
            _marketingEuropeWallet,
            marketingData.fees[5],
            _isExcluded[_marketingEuropeWallet]
        );
        _takeFees(
            _marketingAustraliaWallet,
            marketingData.fees[6],
            _isExcluded[_marketingAustraliaWallet]
        );
    }

    /**
     * @dev Takes team fees from the transaction and transfers them to the appropriate wallets.
     * @param teamData The data struct containing the team fees.
     */
    function _takeTeamFees(BridgesTeamData memory teamData) private {
        // Transfer team fees to each team wallet
        _takeFees(_devWallet, teamData.fees[0], _isExcluded[_devWallet]);
        _takeFees(
            _exchangeWallet,
            teamData.fees[1],
            _isExcluded[_exchangeWallet]
        );
        _takeFees(_teamWallet, teamData.fees[2], _isExcluded[_teamWallet]);
    }

    /**
     * @dev Calculates the specified fee amount for the given token amount and fee type.
     * @param _amount The token amount to calculate the fee for.
     * @param feeType The type of fee to calculate.
     * @return The calculated fee amount.
     */
    function calculateFee(
        uint256 _amount,
        FeeType feeType
    ) private view returns (uint256) {
        return (_amount * fees[uint256(feeType)]) / 10 ** 4;
    }

    /**
     * @dev Transfer tokens from one address to another with fees and redistribution
     * @param sender The address sending the tokens
     * @param recipient The address receiving the tokens
     * @param tAmount The amount of tokens to transfer
     */
    function _transferStandard(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        // Get the amount of reflection tokens and transfer tokens based on the current rate
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 tTransferAmount,
            BridgesSystemData memory systemData,
            BridgesTeamData memory teamData,
            BridgesMarketingData memory marketingData
        ) = _getValues(tAmount);

        // Subtract reflection tokens from sender and add to recipient
        _rOwned[sender] -= rAmount;
        _rOwned[recipient] += rTransferAmount;

        // Take fees from each fee recipient and distribute them to holders and the lottery pot
        _takeFees(
            address(this),
            systemData.fees[0],
            _isExcluded[address(this)]
        );
        _takeFees(
            _lottoPotAddress,
            systemData.fees[1],
            _isExcluded[_lottoPotAddress]
        );
        _takeFees(
            _marketingAsiaWallet,
            marketingData.fees[0],
            _isExcluded[_marketingAsiaWallet]
        );
        _takeFees(
            _marketingAfricaWallet,
            marketingData.fees[1],
            _isExcluded[_marketingAfricaWallet]
        );
        _takeFees(
            _marketingNorthAmericaWallet,
            marketingData.fees[2],
            _isExcluded[_marketingNorthAmericaWallet]
        );
        _takeFees(
            _marketingSouthAmericaWallet,
            marketingData.fees[3],
            _isExcluded[_marketingSouthAmericaWallet]
        );
        _takeFees(
            _marketingAntarcticaWallet,
            marketingData.fees[4],
            _isExcluded[_marketingAntarcticaWallet]
        );
        _takeFees(
            _marketingEuropeWallet,
            marketingData.fees[5],
            _isExcluded[_marketingEuropeWallet]
        );
        _takeFees(
            _marketingAustraliaWallet,
            marketingData.fees[6],
            _isExcluded[_marketingAustraliaWallet]
        );
        _takeFees(_devWallet, teamData.fees[0], _isExcluded[_devWallet]);
        _takeFees(
            _exchangeWallet,
            teamData.fees[1],
            _isExcluded[_exchangeWallet]
        );
        _takeFees(_teamWallet, teamData.fees[2], _isExcluded[_teamWallet]);

        // Emit Transfer event
        emit Transfer(sender, recipient, tTransferAmount);
    }

    /**
     * @dev Transfer tokens from sender to recipient when recipient is an excluded address
     * @param sender The address sending tokens
     * @param recipient The excluded address receiving tokens
     * @param tAmount The amount of tokens to transfer
     */
    function _transferToExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 tTransferAmount,
            BridgesSystemData memory systemData,
            BridgesTeamData memory teamData,
            BridgesMarketingData memory marketingData
        ) = _getValues(tAmount);

        // Reduce the sender's reflected balance by the reflected amount of tokens
        _rOwned[sender] -= rAmount;

        // Add the transferred amount of tokens to the recipient's token balance
        _tOwned[recipient] += tTransferAmount;

        // Add the reflected transfer amount of tokens to the recipient's reflected balance
        _rOwned[recipient] += rTransferAmount;

        // Take fees
        _takeFees(
            address(this),
            systemData.fees[0],
            _isExcluded[address(this)]
        );
        _takeFees(
            _lottoPotAddress,
            systemData.fees[1],
            _isExcluded[_lottoPotAddress]
        );
        _takeFees(
            _marketingAsiaWallet,
            marketingData.fees[0],
            _isExcluded[_marketingAsiaWallet]
        );
        _takeFees(
            _marketingAfricaWallet,
            marketingData.fees[1],
            _isExcluded[_marketingAfricaWallet]
        );
        _takeFees(
            _marketingNorthAmericaWallet,
            marketingData.fees[2],
            _isExcluded[_marketingNorthAmericaWallet]
        );
        _takeFees(
            _marketingSouthAmericaWallet,
            marketingData.fees[3],
            _isExcluded[_marketingSouthAmericaWallet]
        );
        _takeFees(
            _marketingAntarcticaWallet,
            marketingData.fees[4],
            _isExcluded[_marketingAntarcticaWallet]
        );
        _takeFees(
            _marketingEuropeWallet,
            marketingData.fees[5],
            _isExcluded[_marketingEuropeWallet]
        );
        _takeFees(
            _marketingAustraliaWallet,
            marketingData.fees[6],
            _isExcluded[_marketingAustraliaWallet]
        );
        _takeFees(_devWallet, teamData.fees[0], _isExcluded[_devWallet]);
        _takeFees(
            _exchangeWallet,
            teamData.fees[1],
            _isExcluded[_exchangeWallet]
        );
        _takeFees(_teamWallet, teamData.fees[2], _isExcluded[_teamWallet]);

        // Emit transfer event
        emit Transfer(sender, recipient, tTransferAmount);
    }

    /**
     * @dev Transfer tokens from an excluded account to another account
     * @param sender The address of the sender
     * @param recipient The address of the recipient
     * @param tAmount The amount of tokens to transfer
     */
    function _transferFromExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 tTransferAmount,
            BridgesSystemData memory systemData,
            BridgesTeamData memory teamData,
            BridgesMarketingData memory marketingData
        ) = _getValues(tAmount);

        // Decrease the token balance of the sender
        _tOwned[sender] -= tAmount;
        _rOwned[sender] -= rAmount;

        // Increase the token balance of the recipient
        _rOwned[recipient] += rTransferAmount;

        // Take the fees
        _takeFees(
            address(this),
            systemData.fees[0],
            _isExcluded[address(this)]
        );
        _takeFees(
            _lottoPotAddress,
            systemData.fees[1],
            _isExcluded[_lottoPotAddress]
        );

        _takeFees(
            _marketingAsiaWallet,
            marketingData.fees[0],
            _isExcluded[_marketingAsiaWallet]
        );
        _takeFees(
            _marketingAfricaWallet,
            marketingData.fees[1],
            _isExcluded[_marketingAfricaWallet]
        );
        _takeFees(
            _marketingNorthAmericaWallet,
            marketingData.fees[2],
            _isExcluded[_marketingNorthAmericaWallet]
        );
        _takeFees(
            _marketingSouthAmericaWallet,
            marketingData.fees[3],
            _isExcluded[_marketingSouthAmericaWallet]
        );
        _takeFees(
            _marketingAntarcticaWallet,
            marketingData.fees[4],
            _isExcluded[_marketingAntarcticaWallet]
        );
        _takeFees(
            _marketingEuropeWallet,
            marketingData.fees[5],
            _isExcluded[_marketingEuropeWallet]
        );
        _takeFees(
            _marketingAustraliaWallet,
            marketingData.fees[6],
            _isExcluded[_marketingAustraliaWallet]
        );

        _takeFees(_devWallet, teamData.fees[0], _isExcluded[_devWallet]);
        _takeFees(
            _exchangeWallet,
            teamData.fees[1],
            _isExcluded[_exchangeWallet]
        );
        _takeFees(_teamWallet, teamData.fees[2], _isExcluded[_teamWallet]);

        // Emit a transfer event
        emit Transfer(sender, recipient, tTransferAmount);
    }


    //-------------------------------------------------------------------------
    //Lottery-related Functions
    //-------------------------------------------------------------------------


    /**
     * @dev Randomly selects an address from the list of holders to receive the lottery prize.
     * @return The address of the selected holder, or the lottery wallet address if no holder is selected.
     */
    function lotterize() private view returns (address) {
        // Generate a random number between 0 and the number of addresses in the list
        uint256 randomNumber = random() % _addressList.length;
        // Select the address at the random index
        address selectedAddress = _addressList[randomNumber];
        // Get the amount of tokens owned by the selected address
        uint256 ownedAmount = _rOwned[selectedAddress];

        // Check if the selected address meets the requirements to receive the lottery prize
        if (
            ownedAmount >= _minLottoBalance &&
            selectedAddress != address(this) &&
            selectedAddress != address(pancakePair) &&
            selectedAddress != _lottoPotAddress &&
            !_isExcludedFromLottery[selectedAddress]
        ) {
            // If the selected address meets the requirements, return it
            return selectedAddress;
        }
        // If no eligible address is found, return the lottery wallet address
        return _lottoWallet;
    }

    /**
     * @dev Draws the lottery by selecting a holder to receive the lottery prize and transferring the prize amount to them.
     */
    function drawLotto() private nonReentrant lockTheLottery {
        // Get the current balance of the lottery pot
        uint256 lottoBalance = balanceOf(_lottoPotAddress);

        // If the balance is less than the lottery threshold, skip the draw
        if (lottoBalance < lotteryThreshold) {
            emit SkippedDrawLotto(lottoBalance, lotteryThreshold);
            return;
        }

        // Randomly select a holder to receive the lottery prize
        _lottoWalletAddress = lotterize();
        // Transfer the lottery prize amount to the selected holder
        _transfer(_lottoPotAddress, _lottoWalletAddress, lotteryThreshold);
        // Update the last lottery winner amount, total lottery prize, and draw count
        _lastLottoWinnerAmount = lotteryThreshold;
        _totalLottoPrize += lotteryThreshold;
        ++_lottoDrawCount;
        emit DrawLotto(lotteryThreshold, _lottoDrawCount);
    }

    /**
     * @dev Generates a random number based on the previous block's randomness, timestamp, and number.
     * @return A random number.
     */
    function random() private view returns (uint) {
        return
            uint(
                keccak256(
                    abi.encodePacked(
                        block.prevrandao,
                        block.timestamp,
                        block.number
                    )
                )
            );
    }

    //-------------------------------------------------------------------------
    //liquify-related Functions
    //-------------------------------------------------------------------------

    /**
     * @dev Swaps tokens for BNB and adds liquidity to the PancakeSwap pool
     * @param contractTokenBalance The balance of tokens held by the contract to be swapped and added to liquidity
     */
    function swapAndLiquify(uint256 contractTokenBalance) private lockTheSwap {
        // Approve token transfer to PancakeSwap router
        _approve(address(this), address(pancakeRouter), type(uint256).max);

        // Split the token balance into halves
        uint256 half = contractTokenBalance / 2;
        uint256 otherHalf = contractTokenBalance - half;

        // Record the initial BNB balance of the contract
        uint256 initialBalance = address(this).balance;

        // Swap half of the tokens for BNB
        swapTokensForBNB(half);

        // Calculate the amount of BNB received from the swap
        uint256 newBalance = address(this).balance - initialBalance;

        // Add liquidity with the other half of the tokens and the received BNB
        addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    /**
     * @dev Swaps tokens for BNB using the PancakeSwap router
     * @param tokenAmount The amount of tokens to swap for BNB
     */
    function swapTokensForBNB(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = pancakeRouter.WETH();

        // Approve token transfer to PancakeSwap router
        _approve(address(this), address(pancakeRouter), tokenAmount);

        pancakeRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    /**
     * @dev Performs custom swap and liquify by executing multiple swap and add liquidity cycles
     * @param customNumTokensSellToAddToLiquidity The number of tokens to sell in each swap cycle
     */
    function doCustomSwapAndLiquify(
        uint256 customNumTokensSellToAddToLiquidity
    ) private {
        uint256 contractTokenBalance = balanceOf(address(this));

        // Calculate the number of times to execute swap and add liquidity cycle
        uint256 timesToExecute = contractTokenBalance /
            customNumTokensSellToAddToLiquidity;

        if (timesToExecute > maxIterations) {
            timesToExecute = maxIterations;
        }

        // Execute swap and add liquidity cycles
        for (uint256 i = 0; i < timesToExecute; i++) {
            uint256 half = customNumTokensSellToAddToLiquidity / 2;
            uint256 otherHalf = customNumTokensSellToAddToLiquidity - half;

            uint256 initialBalance = address(this).balance;

            swapTokensForBNB(half);

            uint256 newBalance = address(this).balance - initialBalance;

            addLiquidity(otherHalf, newBalance);

            emit SwapAndLiquify(half, newBalance, otherHalf);
        }
    }

    /**
     * @dev Adds liquidity to PancakeSwap pool using the PancakeSwap router
     * @param tokenAmount The amount of tokens to add to the liquidity pool
     * @param bnbAmount The amount of BNB to add to the liquidity pool
     */
    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
        // Approve token transfer to PancakeSwap router
        _approve(address(this), address(pancakeRouter), tokenAmount);

        pancakeRouter.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            address(this),
            block.timestamp
        );
    }


    //-------------------------------------------------------------------------
    // Token Settings
    //-------------------------------------------------------------------------


    /**
     * @dev Sets the number of tokens to add to liquidity when selling.
     * @param newNumTokensSellToAddToLiquidity The new number of tokens to add to liquidity.
     */
    function setNumTokensSellToAddToLiquidity(
        uint256 newNumTokensSellToAddToLiquidity
    ) external onlyOwner {
        // Update the number of tokens to add to liquidity.
        numTokensSellToAddToLiquidity = newNumTokensSellToAddToLiquidity;

        // Emit event.
        emit NumTokensSellToAddToLiquidityUpdated(
            newNumTokensSellToAddToLiquidity
        );
    }

    /**
     * @dev Sets the number of tokens to add to liquidity two when selling.
     * @param newNumTokensSellToAddToLiquidityTrigger The new number of tokens to add to liquidity two.
     */
    function setNumTokensSellToAddToLiquidityTrigger(
        uint256 newNumTokensSellToAddToLiquidityTrigger
    ) external onlyOwner {
        // Update the number of tokens to add to liquidity two.
        numTokensSellToAddToLiquidityTrigger = newNumTokensSellToAddToLiquidityTrigger;

        // Emit event.
        emit NumTokensSellToAddToLiquidityUpdatedTrigger(
            newNumTokensSellToAddToLiquidityTrigger
        );
    }

    /**
     * @dev Set the maximum transaction amount.
     * @param maxTxPercent The maximum transaction amount as a percentage of the total supply.
     */
    function setMaxTxPercent(
        uint256 maxTxPercent
    ) external onlyOwner {
        // Calculate the maximum transaction amount.
        _maxTxAmount = (_tTotal * maxTxPercent) / 10 ** 4;
    }

    /**
     * @dev Transfers `amount` tokens to `recipient`.
     * @param recipient The address to transfer tokens to.
     * @param amount The amount of tokens to transfer.
     * @return A boolean indicating whether the transfer was successful.
     */
    function transfer(
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev Transfers tokens from `sender` to `recipient`.
     * @param sender The address to transfer tokens from.
     * @param recipient The address to transfer tokens to.
     * @param amount The amount of tokens to transfer.
     * @return A boolean indicating whether the transfer was successful.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        // Decrease allowance by the transferred amount
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()] - amount
        );
        return true;
    }

    /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of the sender.
     * @param spender The address which will spend the funds.
     * @param amount The amount of tokens to be spent.
     * @return A boolean indicating whether the approval was successful or not.
     */
    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev Increases the amount of tokens that `spender` is allowed to spend on behalf of the sender.
     * @param spender The address which will spend the funds.
     * @param addedValue The amount of tokens to increase the allowance by.
     * @return A boolean indicating whether the increase was successful.
     */
    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) public virtual returns (bool) {
        uint256 currentAllowance = _allowances[_msgSender()][spender];
        uint256 newAllowance = currentAllowance + addedValue;
        _approve(_msgSender(), spender, newAllowance);
        return true;
    }

    /**
     * @dev Decreases the amount of tokens that `spender` is allowed to spend on behalf of the sender.
     * @param spender The address which will spend the funds.
     * @param subtractedValue The amount of tokens to decrease the allowance by.
     * @return A boolean indicating whether the decrease was successful.
     */
    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) public virtual returns (bool) {
        // Decrease allowance by the specified value
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] - subtractedValue
        );
        return true;
    }

    /**
     * @dev Distributes the specified amount of tokens to all holders based on their current percentage of the total supply.
     *      This function is used to distribute tokens for rewards and lotto payouts.
     * @param tAmount The amount of tokens to distribute.
     */
    function deliver(uint256 tAmount) private {
        address sender = _msgSender();
        // Ensure that excluded addresses cannot call this function
        require(
            !_isExcluded[sender],
            "Excluded addresses cannot call this function"
        );
        (uint256 rAmount, , , , , ) = _getValues(tAmount);
        _rOwned[sender] -= rAmount;
        _rTotal -= rAmount;
    }


    //-------------------------------------------------------------------------
    // Fee Settings
    //-------------------------------------------------------------------------


    /**
     * @dev Exclude accounts from the transaction fee.
     * @param account The accounts to exclude from the transaction fee.
     */
     function excludeFromFee(address account) public onlyOwner {	
        _isExcludedFromFee[account] = true;	
    }

    /**
     * @dev Include an account in the transaction fee.
     * @param account The account to include in the transaction fee.
     */
    function includeInFee(address account) public onlyOwner {
        // Set excluded from fee flag for the account.
        _isExcludedFromFee[account] = false;
    }

    /**
     * @dev Check if the total fee is less than or equal to the max fee.
     * @param newFees The new fees to check.
     */
     function enforceFeeCap(uint256[] memory newFees) private view {
        uint256 noChange = type(uint256).max;
    
        // Calculate the total fee.
        uint256 totalFee = 0;
        for (uint256 i = 0; i < newFees.length; i++) {
            if (newFees[i] != noChange) {
                totalFee += newFees[i];
            } else {
                totalFee += fees[i];
            }
        }
    
        // Require the total fee to be less than or equal to the max fee.
        require(totalFee <= MAX_ALLOWED_FEE, "Total fee cannot be more than 15%");
    }

    /**
     * @dev Set the fees.
     * @param newLiquidityFee The new liquidity fee.
     * @param newLottoFee The new lotto fee.
     * @param newDevFee The new dev fee.
     * @param newTeamFee The new team fee.
     * @param newExchangeFee The new exchange fee.
     * @param newMarketingAsiaFee The new marketing fee for Asia.
     * @param newMarketingAfricaFee The new marketing fee for Africa.
     * @param newMarketingNorthAmericaFee The new marketing fee for North America.
     * @param newMarketingSouthAmericaFee The new marketing fee for South America.
     * @param newMarketingAntarcticaFee The new marketing fee for Antarctica.
     * @param newMarketingEuropeFee The new marketing fee for Europe.
     * @param newMarketingAustraliaFee The new marketing fee for Australia.
     */
     function setFees(
        uint256 newLiquidityFee,
        uint256 newLottoFee,
        uint256 newDevFee,
        uint256 newTeamFee,
        uint256 newExchangeFee,
        uint256 newMarketingAsiaFee,
        uint256 newMarketingAfricaFee,
        uint256 newMarketingNorthAmericaFee,
        uint256 newMarketingSouthAmericaFee,
        uint256 newMarketingAntarcticaFee,
        uint256 newMarketingEuropeFee,
        uint256 newMarketingAustraliaFee
    ) external onlyOwner {
        // Placeholder value used to indicate an empty value
        uint256 noChange = type(uint256).max;

        // Create array of new fees to pass to enforceFeeCap function
        uint256[] memory newFees = new uint256[](12);
        newFees[0] = newLiquidityFee;
        newFees[1] = newLottoFee;
        newFees[2] = newDevFee;
        newFees[3] = newTeamFee;
        newFees[4] = newExchangeFee;
        newFees[5] = newMarketingAsiaFee;
        newFees[6] = newMarketingAfricaFee;
        newFees[7] = newMarketingNorthAmericaFee;
        newFees[8] = newMarketingSouthAmericaFee;
        newFees[9] = newMarketingAntarcticaFee;
        newFees[10] = newMarketingEuropeFee;
        newFees[11] = newMarketingAustraliaFee;

        // Call the enforceFeeCap function before setting new fees
        enforceFeeCap(newFees);

        // Update fees if specified
        if (newLiquidityFee != noChange) {
            previousFees[uint256(FeeType._LiquidityFee)] = fees[
                uint256(FeeType._LiquidityFee)
            ];
            fees[uint256(FeeType._LiquidityFee)] = newLiquidityFee;
        }

        if (newLottoFee != noChange) {
            previousFees[uint256(FeeType._LottoFee)] = fees[
                uint256(FeeType._LottoFee)
            ];
            fees[uint256(FeeType._LottoFee)] = newLottoFee;
        }

        if (newDevFee != noChange) {
            previousFees[uint256(FeeType._DevFee)] = fees[
                uint256(FeeType._DevFee)
            ];
            fees[uint256(FeeType._DevFee)] = newDevFee;
        }

        if (newTeamFee != noChange) {
            previousFees[uint256(FeeType._TeamFee)] = fees[
                uint256(FeeType._TeamFee)
            ];
            fees[uint256(FeeType._TeamFee)] = newTeamFee;
        }

        if (newExchangeFee != noChange) {
            previousFees[uint256(FeeType._ExchangeFee)] = fees[
                uint256(FeeType._ExchangeFee)
            ];
            fees[uint256(FeeType._ExchangeFee)] = newExchangeFee;
        }

        if (newMarketingAsiaFee != noChange) {
            previousFees[uint256(FeeType._MarketingAsiaFee)] = fees[
                uint256(FeeType._MarketingAsiaFee)
            ];
            fees[uint256(FeeType._MarketingAsiaFee)] = newMarketingAsiaFee;
        }

        if (newMarketingAfricaFee != noChange) {
            previousFees[uint256(FeeType._MarketingAfricaFee)] = fees[
                uint256(FeeType._MarketingAfricaFee)
            ];
            fees[uint256(FeeType._MarketingAfricaFee)] = newMarketingAfricaFee;
        }

        if (newMarketingNorthAmericaFee != noChange) {
            previousFees[uint256(FeeType._MarketingNorthAmericaFee)] = fees[
                uint256(FeeType._MarketingNorthAmericaFee)
            ];
            fees[
                uint256(FeeType._MarketingNorthAmericaFee)
            ] = newMarketingNorthAmericaFee;
        }

        if (newMarketingSouthAmericaFee != noChange) {
            previousFees[uint256(FeeType._MarketingSouthAmericaFee)] = fees[
                uint256(FeeType._MarketingSouthAmericaFee)
            ];
            fees[
                uint256(FeeType._MarketingSouthAmericaFee)
            ] = newMarketingSouthAmericaFee;
        }

        if (newMarketingAntarcticaFee != noChange) {
            previousFees[uint256(FeeType._MarketingAntarcticaFee)] = fees[
                uint256(FeeType._MarketingAntarcticaFee)
            ];
            fees[
                uint256(FeeType._MarketingAntarcticaFee)
            ] = newMarketingAntarcticaFee;
        }

        if (newMarketingEuropeFee != noChange) {
            previousFees[uint256(FeeType._MarketingEuropeFee)] = fees[
                uint256(FeeType._MarketingEuropeFee)
            ];
            fees[uint256(FeeType._MarketingEuropeFee)] = newMarketingEuropeFee;
        }
        if (newMarketingAustraliaFee != noChange) {
            previousFees[uint256(FeeType._MarketingAustraliaFee)] = fees[
                uint256(FeeType._MarketingAustraliaFee)
            ];
            fees[
                uint256(FeeType._MarketingAustraliaFee)
            ] = newMarketingAustraliaFee;
        }
    }

    /**
     * @dev Set the wallet addresses for each fee recipient.
     * @param dev The address of the development team wallet.
     * @param exchange The address of the exchange wallet.
     * @param team The address of the team wallet.
     * @param marketingAsia The address of the marketing wallet for Asia.
     * @param marketingAfrica The address of the marketing wallet for Africa.
     * @param marketingNorthAmerica The address of the marketing wallet for North America.
     * @param marketingSouthAmerica The address of the marketing wallet for South America.
     * @param marketingAntarctica The address of the marketing wallet for Antarctica.
     * @param marketingEurope The address of the marketing wallet for Europe.
     * @param marketingAustralia The address of the marketing wallet for Australia.
     * @param lotto The address of the lottery wallet.
     */
    function setWalletAddress(
        address payable dev,
        address payable exchange,
        address payable team,
        address payable marketingAsia,
        address payable marketingAfrica,
        address payable marketingNorthAmerica,
        address payable marketingSouthAmerica,
        address payable marketingAntarctica,
        address payable marketingEurope,
        address payable marketingAustralia,
        address payable lotto
    ) public onlyOwner {
        // Placeholder address used to indicate an empty value
        address payable placeholder = payable(address(0));

        if (dev != placeholder) {
            _devWallet = dev;
        }
        if (exchange != placeholder) {
            _exchangeWallet = exchange;
        }
        if (team != placeholder) {
            _teamWallet = team;
        }
        if (marketingAsia != placeholder) {
            _marketingAsiaWallet = marketingAsia;
        }
        if (marketingAfrica != placeholder) {
            _marketingAfricaWallet = marketingAfrica;
        }
        if (marketingNorthAmerica != placeholder) {
            _marketingNorthAmericaWallet = marketingNorthAmerica;
        }
        if (marketingSouthAmerica != placeholder) {
            _marketingSouthAmericaWallet = marketingSouthAmerica;
        }
        if (marketingAntarctica != placeholder) {
            _marketingAntarcticaWallet = marketingAntarctica;
        }
        if (marketingEurope != placeholder) {
            _marketingEuropeWallet = marketingEurope;
        }
        if (marketingAustralia != placeholder) {
            _marketingAustraliaWallet = marketingAustralia;
        }
        if (lotto != placeholder) {
            _lottoWallet = lotto;
        }
    }


    //-------------------------------------------------------------------------
    // Whale Settings
    //-------------------------------------------------------------------------


    /**
     * @dev Set whether anti-whale is enabled.
     * @param e Whether anti-whale is enabled.
     */
    function setAntiWhaleEnabled(bool e) external onlyOwner {
        // Update whether anti-whale is enabled.
        _isAntiWhaleEnabled = e;
    }

    /**
     * @dev Set excluded from anti-whale flag for an account.
     * @param account The account to set the flag for.
     * @param e Whether the account should be excluded.
     */
    function setExcludedFromAntiWhale(
        address account,
        bool e
    ) external onlyOwner {
        // Set excluded from anti-whale flag for the account.
        _isExcludedFromAntiWhale[account] = e;
    }

    /**
     * @dev Set the anti-whale threshold.
     * @param amount The anti-whale threshold.
     */
    function setAntiWhaleThreshold(
        uint256 amount
    ) external onlyOwner {
        // Update the anti-whale threshold.
        _AntiWhaleThreshold = amount;
    }


    //-------------------------------------------------------------------------
    // LiquiditySwap Settings
    //-------------------------------------------------------------------------


    /**
     * @dev Set whether swapping and liquidity addition is enabled.
     * @param _enabled Whether swapping and liquidity addition is enabled.
     */
    function setSwapAndLiquifyEnabled(
        bool _enabled
    ) public onlyOwner {
        // Update whether swapping and liquidity addition is enabled.
        swapAndLiquifyEnabled = _enabled;

        // Emit event.
        emit SwapAndLiquifyEnabledUpdated(_enabled);
    }

    /**
     * @dev Sets the PancakeSwap Router contract address.
     * @param r The PancakeSwap Router contract address.
     */
    function setPancakeRouter(
        address r
    ) external onlyOwner {
        IPancakeRouter02 _pancakeRouter = IPancakeRouter02(r);
        pancakeRouter = _pancakeRouter;
    }

    /**
     * @dev Sets the PancakeSwap Pair contract address.
     * @param p The PancakeSwap Pair contract address.
     */
    function setPancakePair(
        address p
    ) external onlyOwner {
        pancakePair = IPancakePair(p);
    }

    /**
     * @dev Triggers custom swap and liquify function when called by the contract owner
     */
    function triggerSwapAndLiquify()
        external
        lockTheSwap
    {
        require((_msgSender() == owner()) && swapAndLiquifyEnabled, "Error");
        doCustomSwapAndLiquify(numTokensSellToAddToLiquidityTrigger);
    }


    //-------------------------------------------------------------------------
    // Lottery Settings
    //-------------------------------------------------------------------------


    /**
     * @dev Set whether lotto is enabled.
     * @param enabled Whether lotto is enabled.
     */
    function setLottoEnabled(bool enabled) public onlyOwner {
        // Update whether lotto is enabled.
        lottoEnabled = enabled;
    }

    /**
     * @dev Excludes an account from the lottery.
     * @param account The account to exclude.
     */
    function excludeFromLottery(
        address account
    ) public onlyOwner {
        // Make sure the account isn't already excluded
        require(
            !_isExcludedFromLottery[account],
            "Account is already excluded from lottery"
        );
        // Exclude the account
        _isExcludedFromLottery[account] = true;
    }

    /**
     * @dev Includes an account in the lottery.
     * @param account The account to include.
     */
    function includeInLottery(
        address account
    ) public onlyOwner {
        // Make sure the account is already excluded
        require(
            _isExcludedFromLottery[account],
            "Account is already included in lottery"
        );
        // Include the account
        _isExcludedFromLottery[account] = false;
    }

    /**
     * @dev Set the minimum balance for the lottery pool.
     * @param minBalance The minimum balance for the lottery pool.
     */
    function setMinLottoBalance(
        uint256 minBalance
    ) public onlyOwner {
        // Update the minimum balance for the lottery pool.
        _minLottoBalance = minBalance;
    }

    /**
     * @dev Set the lottery threshold.
     * @param threshold The lottery threshold.
     */
    function setLotteryThresHold(
        uint256 threshold
    ) public onlyOwner {
        // Update the lottery threshold.
        lotteryThreshold = threshold;
    }


    //-------------------------------------------------------------------------
    // Other Functions Settings
    //-------------------------------------------------------------------------


    /**
     * @dev Withdraws any stuck BNB in the contract and sends it to the contract owner.
     */
    function withdrawStuckBNB() external onlyOwner {
        uint256 balance = address(this).balance;
        require(balance > 0, "Contract has no BNB balance");
        address payable owner = payable(_msgSender());
        owner.transfer(balance);
    }

    /**
     * @dev Withdraws any stuck tokens in the contract and sends them to the contract owner.
     * @param _tokenAddress The contract address of the token being withdrawn.
     */
    function withdrawStuckTokens(
        address _tokenAddress
    ) public onlyOwner {
        IBEP20 token = IBEP20(_tokenAddress);
        uint256 balance = token.balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        require(token.transfer(msg.sender, balance), "Token transfer failed");

        emit TokensWithdrawn(_tokenAddress, msg.sender, balance);
    }

    /**
     * @dev Returns the name of the token.
     * @return The name of the token as a string.
     */
    function name() public view returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token.
     * @return The symbol of the token as a string.
     */
    function symbol() public view returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the total supply of the token.
     * @return The total supply of the token as a uint256.
     */
    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    /**
    * @dev Calculates and returns the total fees from the `fees` array.
    * @return The total fees as a uint256.
    */
    function getTotalFees() public view returns (uint256) {
        uint256 totalFees = 0;
        for (uint256 i = 0; i < fees.length; i++) {
            totalFees += fees[i];
        }
        return totalFees;
    }

    /**
     * @dev Returns the minimum lotto balance required to participate in the lotto.
     * @return The minimum lotto balance required to participate as a uint256.
     */
    function minLottoBalance() public view returns (uint256) {
        return _minLottoBalance;
    }

    /**
     * @dev Returns the current balance of the lotto pool.
     * @return The current balance of the lotto pool as a uint256.
     */
    function currentLottoPool() public view returns (uint256) {
        return balanceOf(_lottoPotAddress);
    }

    /**
     * @dev Returns the balance of the specified account.
     * @param account The address of the account to retrieve the balance of.
     * @return The balance of the specified account as a uint256.
     */
    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    /**
     * @dev Checks if the specified account is excluded from fees.
     * @param account The account to check.
     * @return True if the account is excluded from fees, false otherwise.
     */
    function isExcludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFee[account];
    }

    /**
     * @dev Returns the amount of tokens that `spender` is allowed to spend on behalf of `owner`.
     * @param owner The address that owns the tokens.
     * @param spender The address that is allowed to spend the tokens.
     * @return The amount of tokens that `spender` is allowed to spend on behalf of `owner` as a uint256.
     */
    function allowance(
        address owner,
        address spender
    ) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev Converts an amount of reflections to the corresponding amount of tokens.
     * @param rAmount The amount of reflections to convert.
     * @return The corresponding amount of tokens as a uint256.
     */
    function tokenFromReflection(
        uint256 rAmount
    ) internal view returns (uint256) {
        require(
            rAmount <= _rTotal,
            "Amount must be less than total reflections"
        );
        uint256 currentRate = _getRate();
        return rAmount / currentRate;
    }

    /**
     * @dev Returns whether the specified address is included in the lotto pool.
     * @param account The address to check for inclusion in the lotto pool.
     * @return A boolean indicating whether the address is included in the lotto pool.
     */
    function isIncludeFromLotto(address account) public view returns (bool) {
        return _AddressExists[account];
    }
}
