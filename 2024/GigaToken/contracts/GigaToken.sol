// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

/**
 *    GigaToken
 *    Utility Token of the Gigaconomy, powering GigaBots!
 *
 *    Website: https://www.gigabots.ai
 *    Twitter: https://twitter.com/gigabots_ai
 *    Telegram: https://t.me/GigaBotsCommunity
 *    Bot: https://t.me/OfficialGigaTraderBot
 *
 */
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IUniswapV2Router} from "./interfaces/IUniswapV2Router.sol";
import {IUniswapV2Factory} from "./interfaces/IUniswapV2Factory.sol";

/**
 * @title GigaToken
 * @author GigaDev
 * @notice This contract represents the GigaToken ERC20 token.
 * It inherits from ERC20, ERC20Burnable, and Ownable contracts from OpenZeppelin.
 * @custom:security-contact gigadev@gigabots.ai
 */
contract GigaToken is ERC20, ERC20Burnable, Ownable {
    address public marketingWallet;
    address public operationsWallet;

    uint8 public buyFee = 50;
    uint8 public sellFee = 50;

    uint8 public liquidityFeePercent = 20;
    uint8 public marketingFeePercent = 20;
    uint8 public operationsFeePercent = 60;

    uint256 public swapTokensAtAmount = 50_000 * 1e18; // 0.05% of TS
    bool private _distributingFees;

    mapping(address => bool) private _excludedFromFees;

    bool public limitsInEffect = true;
    uint256 public maxWalletBalance = 1_000_000 * 1e18; // 1% of TS
    uint256 public maxTransactionAmount = 1_000_000 * 1e18; // 1% of TS
    mapping(address => bool) private _excludedFromMaxTransaction;

    address public immutable uniV2Pair;
    mapping(address => bool) public ammPairs;
    IUniswapV2Router public constant uniV2Router = IUniswapV2Router(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);

    bool public tradingEnabled;

    event LimitsRemoved();
    event TradingEnabled();
    event BuyFeeSet(uint8 newBuyFee);
    event SellFeeSet(uint8 newSellFee);
    event AMMPairSet(address pair, bool isSet);
    event MarketingWalletUpdated(address newAddress);
    event OperationsWalletUpdated(address newAddress);
    event MaxWalletBalanceUpdated(uint256 newMaxWalletBalance);
    event MaxTransactionAmountUpdated(uint256 newMaxTransactionAmount);
    event SwapTokensAtAmountSet(uint256 newSwapTokensAtAmount);
    event FeesDistributionSet(
        uint8 newLiquidityFeePercent, uint8 newMarketingFeePercent, uint8 newOperationsFeePercent
    );
    event FeesDistributed(
        uint256 totalTokensDistributed,
        uint256 tokensToLiquidity,
        uint256 ethToLiquidity,
        uint256 ethToMarketing,
        uint256 ethToOperations
    );

    /**
     * @notice Constructor function for the GigaToken contract.
     * It initializes the contract by setting the token name and symbol,
     * creates a Uniswap V2 pair for the token, sets initial values for marketing and operations wallets and
     * mints total token supply.
     * It also approves the Uniswap V2 router to spend an unlimited amount of tokens on behalf of the contract.
     */
    constructor() ERC20("GigaToken", "GIGA") {
        uniV2Pair = IUniswapV2Factory(uniV2Router.factory()).createPair(address(this), uniV2Router.WETH());
        ammPairs[uniV2Pair] = true;
        _excludedFromMaxTransaction[uniV2Pair] = true;

        _excludedFromFees[owner()] = true;
        marketingWallet = owner();
        operationsWallet = owner();

        _mint(owner(), 100_000_000 * 1e18);

        _approve(address(this), address(uniV2Router), type(uint256).max);
    }

    receive() external payable {}

    /**
     * @notice This function is used to transfer tokens internally within the contract.
     * It performs various checks such as trading enablement, maximum transaction and balance limits,
     * fee distribution, and fee deduction.
     * It then calls the _transfer function from the parent contract to perform the actual token transfer.
     * @param from The address to transfer tokens from.
     * @param to The address to transfer tokens to.
     * @param amount The amount of tokens to transfer.
     */
    function _transfer(address from, address to, uint256 amount) internal override {
        require(amount > 0, "GigaToken: transfer amount must be greater than 0");

        // Check if trading has been enabled
        if (!tradingEnabled) {
            require(from == owner() || to == owner(), "GigaToken: trading has not been enabled yet");
        }

        // Max TX and Max Balance Limits
        if (limitsInEffect) {
            if (from != owner() && to != owner() && to != address(0) && to != address(0xdead) && !_distributingFees) {
                // On Buys
                if (ammPairs[from] && !_excludedFromMaxTransaction[to]) {
                    require(amount <= maxTransactionAmount, "GigaToken: amount exceeds max transaction amount");
                    require(
                        amount + balanceOf(to) <= maxWalletBalance, "GigaToken: balance would exceed max wallet balance"
                    );
                }
                // On Sells
                else if (ammPairs[to] && !_excludedFromMaxTransaction[from]) {
                    require(amount <= maxTransactionAmount, "GigaToken: amount exceeds max transaction amount");
                }
                // On Transfers to non-excluded "to" address
                else if (!_excludedFromMaxTransaction[to]) {
                    require(
                        amount + balanceOf(to) <= maxWalletBalance, "GigaToken: balance would exceed max wallet balance"
                    );
                }
            }
        }

        // Swap any tokens held as fees for ETH and distribute
        bool shouldSwap = balanceOf(address(this)) >= swapTokensAtAmount;
        if (shouldSwap && !_distributingFees && !ammPairs[from] && !_excludedFromFees[from] && !_excludedFromFees[to]) {
            _distributingFees = true;
            _distributeFees();
            _distributingFees = false;
        }

        // Determine if we should take fees
        bool takeFees = !_distributingFees;
        if (_excludedFromFees[from] || _excludedFromFees[to]) {
            takeFees = false;
        }

        uint256 fees = 0;
        // Take Fees if necessary
        if (takeFees) {
            // Fees on buys
            if (ammPairs[from] && buyFee > 0) {
                fees = (amount * buyFee) / 1_000;
            }
            // Fees on sells
            else if (ammPairs[to] && sellFee > 0) {
                fees = (amount * sellFee) / 1_000;
            }

            // If there are fees to be taken, transfer and substract from amount
            if (fees > 0) {
                super._transfer(from, address(this), fees);
                amount -= fees;
            }
        }

        // Make final transfer
        super._transfer(from, to, amount);
    }

    /**
     * @notice Distributes fees collected by the contract.
     * The function calculates the amount of fees to distribute based on the balance of the contract.
     * It then swaps a portion of the fees for ETH and adds liquidity to the token.
     * The remaining ETH is distributed to the marketing and operations wallets.
     * @dev Emits a `FeesDistributed` event with the details of the distribution.
     */
    function _distributeFees() private {
        // Determine amount of held fees to distribute
        uint256 tokensToDistribute = balanceOf(address(this));
        if (tokensToDistribute > swapTokensAtAmount * 20) {
            tokensToDistribute = swapTokensAtAmount * 20;
        }

        // Calculate how many tokens we should swap for ETH (some will be used for liquidity)
        uint256 tokensForLiquidityHalf = ((tokensToDistribute * liquidityFeePercent) / 100) / 2;
        uint256 tokensToSwapForEth = tokensToDistribute - tokensForLiquidityHalf;

        // Swap tokens for ETH
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniV2Router.WETH();
        try uniV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokensToSwapForEth, 0, path, address(this), block.timestamp
        ) {} catch {}

        // Distribute ETH and add liquidity
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            // Add Liquidity
            uint256 ethForLiquidity = (ethBalance * tokensForLiquidityHalf) / tokensToSwapForEth;
            if (ethForLiquidity > 0) {
                try uniV2Router.addLiquidityETH{value: ethForLiquidity}(
                    address(this), tokensForLiquidityHalf, 0, 0, address(0), block.timestamp
                ) {} catch {}
            }

            bool success;

            // Send ETH to Marketing
            uint256 tokensForMarketing = (tokensToDistribute * marketingFeePercent) / 100;
            uint256 ethForMarketing = (ethBalance * tokensForMarketing) / tokensToSwapForEth;
            if (ethForMarketing > 0) {
                (success,) = marketingWallet.call{value: ethForMarketing}("");
            }

            // Send ETH to Operations
            uint256 ethForOperations = 0;
            if (operationsFeePercent != 0) {
                ethForOperations = address(this).balance;
                (success,) = operationsWallet.call{value: ethForOperations}("");
            }

            emit FeesDistributed(
                tokensToDistribute, tokensForLiquidityHalf, ethForLiquidity, ethForMarketing, ethForOperations
            );
        }
    }

    /**
     * @notice Returns whether the specified account is excluded from fees.
     * @param account The address to check.
     * @return A boolean indicating whether the account is excluded from fees.
     */
    function isExcludedFromFees(address account) public view returns (bool) {
        return _excludedFromFees[account];
    }

    /**
     * @notice Returns whether the specified account is excluded from the maximum transaction limit.
     * @param account The address to check.
     * @return A boolean indicating whether the account is excluded from the maximum transaction limit.
     */
    function isExcludedFromMaxTransaction(address account) public view returns (bool) {
        return _excludedFromMaxTransaction[account];
    }

    /**
     * @notice Enables trading of the token.
     * @dev Can only be called by the contract owner.
     * @dev Emits a `TradingEnabled` event.
     */
    function enableTrading() external onlyOwner {
        tradingEnabled = true;
        emit TradingEnabled();
    }

    /**
     * @notice Updates the marketing wallet address.
     * @param newAddress The new address for the marketing wallet.
     * @dev Can only be called by the contract owner.
     * @dev `newAddress` cannot be the zero address.
     * @dev Emits a `MarketingWalletUpdated` event.
     */
    function updateMarketingWallet(address newAddress) external onlyOwner {
        require(newAddress != address(0), "GigaToken: address cannot be 0 address");
        marketingWallet = newAddress;
        emit MarketingWalletUpdated(newAddress);
    }

    /**
     * @notice Updates the operations wallet address.
     * @param newAddress The new address to set as the operations wallet.
     * @dev Can only be called by the contract owner.
     * @dev `newAddress` cannot be the zero address.
     * @dev Emits a `OperationsWalletUpdated` event.
     */
    function updateOperationsWallet(address newAddress) external onlyOwner {
        require(newAddress != address(0), "GigaToken: address cannot be 0 address");
        operationsWallet = newAddress;
        emit OperationsWalletUpdated(newAddress);
    }

    /**
     * @notice Removes the max transcation and max wallet balance limits on the token.
     * @dev Can only be called by the contract owner.
     * @dev Once turned off, the limits cannot be turned back on.
     * @dev Emits a `LimitsRemoved` event.
     */
    function removeLimits() external onlyOwner {
        limitsInEffect = false;
        emit LimitsRemoved();
    }

    /**
     * @notice Sets the amount of tokens required for a fee tokens swap.
     * @param newSwapTokensAtAmount The new amount of tokens required for a swap.
     * @dev Can only be called by the contract owner.
     * @dev The newSwapTokensAtAmount must be greater than or equal to 0.001% of the total supply,
     * and less than or equal to 0.5% of the total supply.
     * @dev Emits a `SwapTokensAtAmountSet` event.
     */
    function setSwapTokensAtAmount(uint256 newSwapTokensAtAmount) external onlyOwner {
        require(
            newSwapTokensAtAmount >= totalSupply() / 100_000,
            "GigaToken: swap tokens at amount cannot be lower than 0.001% of total supply"
        );
        require(
            newSwapTokensAtAmount <= (totalSupply() * 5) / 1_000,
            "GigaToken: swap tokens at amount cannot be higher than 0.5% of total supply"
        );
        swapTokensAtAmount = newSwapTokensAtAmount;
        emit SwapTokensAtAmountSet(newSwapTokensAtAmount);
    }

    /**
     * @notice Sets the buy fee for GigaToken.
     * @param newBuyFee The new buy fee to be set.
     * @dev Can only be called by the contract owner.
     * @dev The new buy fee cannot be greater than 50 (5%).
     * @dev Emits a `BuyFeeSet` event.
     */
    function setBuyFee(uint8 newBuyFee) external onlyOwner {
        require(newBuyFee <= 50, "GigaToken: fee cannot be greater than 5%");
        buyFee = newBuyFee;
        emit BuyFeeSet(newBuyFee);
    }

    /**
     * @notice Sets the sell fee for GigaToken.
     * @param newSellFee The new sell fee to be set.
     * @dev Can only be called by the contract owner.
     * @dev The new sell fee cannot be greater than 50 (5%).
     * @dev Emits a `SellFeeSet` event.
     */
    function setSellFee(uint8 newSellFee) external onlyOwner {
        require(newSellFee <= 50, "GigaToken: fee cannot be greater than 5%");
        sellFee = newSellFee;
        emit SellFeeSet(newSellFee);
    }

    /**
     * @notice Sets the fees distribution for the GigaToken contract.
     * @param newLiquidityFeePercent The new percentage of fees allocated to liquidity.
     * @param newMarketingFeePercent The new percentage of fees allocated to marketing.
     * @param newOperationsFeePercent The new percentage of fees allocated to operations.
     * @dev Can only be called by the contract owner.
     * @dev The sum of `newLiquidityFeePercent`, `newMarketingFeePercent`, and `newOperationsFeePercent` must equal 100.
     * @dev Emits a `FeesDistributionSet` event.
     */
    function setFeesDistribution(
        uint8 newLiquidityFeePercent,
        uint8 newMarketingFeePercent,
        uint8 newOperationsFeePercent
    ) external onlyOwner {
        require(
            newLiquidityFeePercent + newMarketingFeePercent + newOperationsFeePercent == 100,
            "GigaToken: fees distribution total must equal 100"
        );
        liquidityFeePercent = newLiquidityFeePercent;
        marketingFeePercent = newMarketingFeePercent;
        operationsFeePercent = newOperationsFeePercent;
        emit FeesDistributionSet(newLiquidityFeePercent, newMarketingFeePercent, newOperationsFeePercent);
    }

    /**
     * @notice Updates the maximum transaction amount allowed.
     * @dev Only the contract owner can call this function.
     * @dev `newMaxTransactionAmount` must be greater than or equal to 0.1% of the total supply.
     * @dev Emits a `MaxTransactionAmountUpdated` event.
     */
    function updateMaxTransactionAmount(uint256 newMaxTransactionAmount) external onlyOwner {
        require(
            newMaxTransactionAmount >= totalSupply() / 1_000,
            "GigaToken: cannot set max transaction amount below 0.1% of totalSupply"
        );
        maxTransactionAmount = newMaxTransactionAmount;
        emit MaxTransactionAmountUpdated(newMaxTransactionAmount);
    }

    /**
     * @notice Updates the maximum wallet balance allowed for token holders.
     * @param newMaxWalletBalance The new maximum wallet balance to be set.
     * @dev Only the contract owner can call this function.
     * @dev The new maximum wallet balance must be greater than or equal to 0.1% of the total supply.
     * @dev Emits a `MaxWalletBalanceUpdated` event.
     */
    function updateMaxWalletBalance(uint256 newMaxWalletBalance) external onlyOwner {
        require(
            newMaxWalletBalance >= totalSupply() / 1_000,
            "GigaToken: cannot set max wallet balance below 0.1% of totalSupply"
        );
        maxWalletBalance = newMaxWalletBalance;
        emit MaxWalletBalanceUpdated(newMaxWalletBalance);
    }

    /**
     * @notice Sets the excluded status of an account from fees.
     * @param account The address of the account.
     * @param excluded The excluded status to be set.
     * @dev Only the contract owner can call this function.
     */
    function setExcludedFromFees(address account, bool excluded) external onlyOwner {
        _excludedFromFees[account] = excluded;
    }

    /**
     * @notice Sets whether an account is excluded from the maximum transaction limit.
     * @param account The address of the account to be excluded or included.
     * @param excluded A boolean indicating whether the account should be excluded or included.
     * @dev Only the contract owner can call this function.
     */
    function setExcludedFromMaxTransaction(address account, bool excluded) external onlyOwner {
        _excludedFromMaxTransaction[account] = excluded;
    }

    /**
     * @notice Sets the AMM pair for the GigaToken contract.
     * @param pair The address of the AMM pair.
     * @param isSet A boolean indicating whether the pair is set or not.
     * @dev Only the contract owner can call this function.
     * @dev The original uniV2Pair cannot be altered.
     * @dev Emits an `AMMPairSet` event.
     */
    function setAMMPair(address pair, bool isSet) external onlyOwner {
        require(pair != uniV2Pair, "GigaToken: original uniV2Pair cannot be altered");
        ammPairs[pair] = isSet;
        emit AMMPairSet(pair, isSet);
    }
}
