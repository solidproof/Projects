// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./Ownable.sol";

enum TaxId {
    Liquidity,
    Marketing,
    Team,
    Jackpot,
    BronzeJackpot,
    SilverJackpot,
    GoldJackpot
}

struct Tax {
    uint256 buyFee;
    uint256 sellFee;
    uint256 pendingTokens;
    uint256 pendingBalance;
    uint256 claimedBalance;
}

abstract contract Treasury is Ownable {
    using Address for address;
    using EnumerableSet for EnumerableSet.AddressSet;

    uint256 private constant MAX_PCT = 10000;
    // At any given time, buy and sell fees can NOT exceed 25% each
    uint256 private constant TOTAL_FEES_LIMIT = 2500;

    uint256 private totalSupply;

    uint256 public maxWalletSize;

    // The minimum transaction limit that can be set is 0.1% of the total supply
    uint256 internal constant MIN_TX_LIMIT = 10;
    uint256 public maxTxAmount;

    uint256 public numTokensSellToAddToLiquidity;

    EnumerableSet.AddressSet private _txLimitExempt;
    EnumerableSet.AddressSet private _maxWalletExempt;
    EnumerableSet.AddressSet private _feeExempt;
    EnumerableSet.AddressSet private _swapExempt;

    mapping(TaxId => Tax) private taxes;

    event BuyFeesChanged(
        uint256 liquidityFee,
        uint256 marketingFee,
        uint256 teamFee
    );

    event JackpotBuyFeesChanged(
        uint256 jackpotFee,
        uint256 bronzeJackpotFee,
        uint256 silverJackpotFee,
        uint256 goldJackpotFee
    );

    event SellFeesChanged(
        uint256 liquidityFee,
        uint256 marketingFee,
        uint256 teamFee
    );

    event JackpotSellFeesChanges(
        uint256 jackpotFee,
        uint256 bronzeJackpotFee,
        uint256 silverJackpotFee,
        uint256 goldJackpotFee
    );

    event MaxTransferAmountChanged(uint256 maxTxAmount);

    event MaxWalletSizeChanged(uint256 maxWalletSize);

    event TokenToSellOnSwapChanged(uint256 numTokens);

    event FeesCollected(uint256 bnbCollected);

    constructor(uint256 total, uint256 decimals) {
        totalSupply = total;
        // Max wallet size initially set to 1%
        maxWalletSize = total / 100;
        // Initially, max TX amount is set to the total supply
        maxTxAmount = total;

        numTokensSellToAddToLiquidity = 2000 * 10**decimals;

        Tax storage liqTax = taxes[TaxId.Liquidity];
        // Initial liquidity taxes = Buy (0%) Sell (0%)
        liqTax.buyFee = 0;
        liqTax.sellFee = 0;

        Tax storage marketingTax = taxes[TaxId.Marketing];
        // Initial marketing taxes = Buy (2%) Sell (2%)
        marketingTax.buyFee = 200;
        marketingTax.sellFee = 200;

        Tax storage teamTax = taxes[TaxId.Team];
        // Initial team taxes = Buy (2%) Sell (2%)
        // Who wants to work for free?
        teamTax.buyFee = 200;
        teamTax.sellFee = 200;

        Tax storage jackpotTax = taxes[TaxId.Jackpot];
        // Initial MAIN jackpot taxes = Buy (4%) Sell (4%)
        jackpotTax.buyFee = 400;
        jackpotTax.sellFee = 400;

        Tax storage bronzeJackpotTax = taxes[TaxId.BronzeJackpot];
        // Initial bronze jackpot taxes = Buy (2%) Sell (2%)
        bronzeJackpotTax.buyFee = 200;
        bronzeJackpotTax.sellFee = 200;

        Tax storage silverJackpotTax = taxes[TaxId.SilverJackpot];
        // Initial silver jackpot taxes = Buy (1%) Sell (1%)
        silverJackpotTax.buyFee = 100;
        silverJackpotTax.sellFee = 100;

        Tax storage goldJackpotTax = taxes[TaxId.GoldJackpot];
        // Initial gold jackpot taxes = Buy (1%) Sell (1%)
        goldJackpotTax.buyFee = 100;
        goldJackpotTax.sellFee = 100;
    }

    function isTxLimitExempt(address account) public view returns (bool) {
        return _txLimitExempt.contains(account);
    }

    function exemptFromTxLimit(address account) public onlyAuthorized {
        _txLimitExempt.add(account);
    }

    function includeInTxLimit(address account) public onlyAuthorized {
        _txLimitExempt.remove(account);
    }

    function isMaxWalletExempt(address account) public view returns (bool) {
        return _maxWalletExempt.contains(account);
    }

    function exemptFromMaxWallet(address account) public onlyAuthorized {
        _maxWalletExempt.add(account);
    }

    function includeInMaxWallet(address account) public onlyAuthorized {
        _maxWalletExempt.remove(account);
    }

    function isFeeExempt(address account) public view returns (bool) {
        return _feeExempt.contains(account);
    }

    function exemptFromFee(address account) public onlyAuthorized {
        _feeExempt.add(account);
    }

    function includeInFee(address account) public onlyAuthorized {
        _feeExempt.remove(account);
    }

    function isSwapAndLiquifyExempt(address account)
        public
        view
        returns (bool)
    {
        return _swapExempt.contains(account);
    }

    function exemptFromSwapAndLiquify(address account) public onlyOwner {
        _swapExempt.add(account);
    }

    function includeInSwapAndLiquify(address account) public onlyOwner {
        _swapExempt.remove(account);
    }

    function exemptFromAll(address account) public onlyOwner {
        exemptFromFee(account);
        exemptFromMaxWallet(account);
        exemptFromTxLimit(account);
    }

    function setBuyFees(
        uint256 liquidityFee,
        uint256 marketingFee,
        uint256 teamFee
    ) external onlyAuthorized {
        require(
            (liquidityFee +
                marketingFee +
                teamFee +
                taxes[TaxId.Jackpot].buyFee +
                taxes[TaxId.BronzeJackpot].buyFee +
                taxes[TaxId.SilverJackpot].buyFee +
                taxes[TaxId.GoldJackpot].buyFee) <= TOTAL_FEES_LIMIT,
            "Total buy fees can not exceed the declared limit"
        );
        taxes[TaxId.Liquidity].buyFee = liquidityFee;
        taxes[TaxId.Marketing].buyFee = marketingFee;
        taxes[TaxId.Team].buyFee = teamFee;

        emit BuyFeesChanged(liquidityFee, marketingFee, teamFee);
    }

    function setJackpotBuyFees(
        uint256 jackpotFee,
        uint256 bronzeJackpotFee,
        uint256 silverJackpotFee,
        uint256 goldJackpotFee
    ) external onlyAuthorized {
        require(
            (taxes[TaxId.Liquidity].buyFee +
                taxes[TaxId.Marketing].buyFee +
                taxes[TaxId.Team].buyFee +
                jackpotFee +
                bronzeJackpotFee +
                silverJackpotFee +
                goldJackpotFee) <= TOTAL_FEES_LIMIT,
            "Total jackpot buy fees can not exceed the declared limit"
        );
        taxes[TaxId.Jackpot].buyFee = jackpotFee;
        taxes[TaxId.BronzeJackpot].buyFee = bronzeJackpotFee;
        taxes[TaxId.SilverJackpot].buyFee = silverJackpotFee;
        taxes[TaxId.GoldJackpot].buyFee = goldJackpotFee;

        emit JackpotBuyFeesChanged(
            jackpotFee,
            bronzeJackpotFee,
            silverJackpotFee,
            goldJackpotFee
        );
    }

    function getBuyTax() public view returns (uint256) {
        uint8 min = uint8(type(TaxId).min);
        uint8 max = uint8(type(TaxId).max);
        uint256 buyTax = 0;

        for (uint8 i = min; i <= max; i++) {
            buyTax += taxes[TaxId(i)].buyFee;
        }

        return buyTax;
    }

    function getBuyFee(TaxId id) public view returns (uint256) {
        return taxes[id].buyFee;
    }

    function setSellFees(
        uint256 liquidityFee,
        uint256 marketingFee,
        uint256 teamFee
    ) external onlyAuthorized {
        require(
            (liquidityFee +
                marketingFee +
                teamFee +
                taxes[TaxId.Jackpot].sellFee +
                taxes[TaxId.BronzeJackpot].sellFee +
                taxes[TaxId.SilverJackpot].sellFee +
                taxes[TaxId.GoldJackpot].sellFee) <= TOTAL_FEES_LIMIT,
            "Total sell fees can not exceed the declared limit"
        );

        taxes[TaxId.Liquidity].sellFee = liquidityFee;
        taxes[TaxId.Marketing].sellFee = marketingFee;
        taxes[TaxId.Team].sellFee = teamFee;

        emit SellFeesChanged(liquidityFee, marketingFee, teamFee);
    }

    function setJackpotSellFees(
        uint256 jackpotFee,
        uint256 bronzeJackpotFee,
        uint256 silverJackpotFee,
        uint256 goldJackpotFee
    ) external onlyAuthorized {
        require(
            (taxes[TaxId.Liquidity].sellFee +
                taxes[TaxId.Marketing].sellFee +
                taxes[TaxId.Team].sellFee +
                jackpotFee +
                bronzeJackpotFee +
                silverJackpotFee +
                goldJackpotFee) <= TOTAL_FEES_LIMIT,
            "Total jackpot sell fees can not exceed the declared limit"
        );
        taxes[TaxId.Jackpot].sellFee = jackpotFee;
        taxes[TaxId.BronzeJackpot].sellFee = bronzeJackpotFee;
        taxes[TaxId.SilverJackpot].sellFee = silverJackpotFee;
        taxes[TaxId.GoldJackpot].sellFee = goldJackpotFee;

        emit JackpotBuyFeesChanged(
            jackpotFee,
            bronzeJackpotFee,
            silverJackpotFee,
            goldJackpotFee
        );
    }

    function getSellTax() public view returns (uint256) {
        uint8 min = uint8(type(TaxId).min);
        uint8 max = uint8(type(TaxId).max);
        uint256 sellTax = 0;

        // Enums hold a max of 256 entries, so uint8 will suffice
        for (uint8 i = min; i <= max; i++) {
            sellTax += taxes[TaxId(i)].sellFee;
        }

        return sellTax;
    }

    function getSellFee(TaxId id) public view returns (uint256) {
        return taxes[id].sellFee;
    }

    function setMaxTxAmount(uint256 txAmount) external onlyAuthorized {
        require(
            txAmount >= (totalSupply * MIN_TX_LIMIT) / MAX_PCT,
            "Maximum transaction limit can't be less than 0.1% of the total supply"
        );
        maxTxAmount = txAmount;

        emit MaxTransferAmountChanged(maxTxAmount);
    }

    function setMaxWallet(uint256 amount) external onlyAuthorized {
        require(
            amount >= totalSupply / 1000,
            "Max wallet size must be at least 0.1% of the total supply"
        );
        maxWalletSize = amount;

        emit MaxWalletSizeChanged(maxWalletSize);
    }

    function setNumTokensSellToAddToLiquidity(uint256 numTokens)
        external
        onlyAuthorized
    {
        numTokensSellToAddToLiquidity = numTokens;

        emit TokenToSellOnSwapChanged(numTokensSellToAddToLiquidity);
    }

    function getPendingAssets(TaxId id) public view returns (uint256, uint256) {
        return (taxes[id].pendingBalance, taxes[id].pendingTokens);
    }

    function getClaimedBalance(TaxId id) public view returns (uint256) {
        return taxes[id].claimedBalance;
    }

    function collectFees(TaxId id, address payable wallet) internal {
        uint256 toTransfer = getPendingBalance(id);
        decPendingBalance(id, toTransfer, true);
        Address.sendValue(wallet, toTransfer);
        emit FeesCollected(toTransfer);
    }

    function collectMarketingFees() external onlyMarketing {
        collectFees(TaxId.Marketing, marketingWallet());
    }

    function collectTeamFees() external onlyTeam {
        collectFees(TaxId.Team, teamWallet());
    }

    function getPendingTokens() public view returns (uint256[] memory) {
        uint8 min = uint8(type(TaxId).min);
        uint8 max = uint8(type(TaxId).max);
        uint256[] memory tokens = new uint256[](max - min + 1);

        for (uint8 i = min; i <= max; i++) {
            tokens[i] = taxes[TaxId(i)].pendingTokens;
        }

        return tokens;
    }

    function getPendingTokensTotal() public view returns (uint256) {
        uint256[] memory tokens = getPendingTokens();
        uint256 pendingTokensTotal = 0;

        for (uint8 i = 0; i < tokens.length; i++) {
            pendingTokensTotal += tokens[i];
        }

        return pendingTokensTotal;
    }

    function getPendingBalances() public view returns (uint256[] memory) {
        uint8 min = uint8(type(TaxId).min);
        uint8 max = uint8(type(TaxId).max);

        uint256[] memory balances = new uint256[](max - min + 1);

        for (uint8 i = min; i <= max; i++) {
            balances[i] = taxes[TaxId(i)].pendingBalance;
        }

        return balances;
    }

    function getPendingBalancesTotal() external view returns (uint256) {
        uint256[] memory balances = getPendingBalances();
        uint256 pendingBalancesTotal = 0;
        for (uint8 i = 0; i < balances.length; i++) {
            pendingBalancesTotal += balances[i];
        }

        return pendingBalancesTotal;
    }

    function getPendingBalance(TaxId id) internal view returns (uint256) {
        return taxes[id].pendingBalance;
    }

    function incPendingBalance(TaxId id, uint256 amount) internal {
        taxes[id].pendingBalance += amount;
    }

    function decPendingBalance(
        TaxId id,
        uint256 amount,
        bool claim
    ) internal {
        taxes[id].pendingBalance -= amount;
        if (claim) {
            taxes[id].claimedBalance += amount;
        }
    }

    function resetPendingBalances() internal {
        uint8 min = uint8(type(TaxId).min);
        uint8 max = uint8(type(TaxId).max);

        for (uint8 i = min; i <= max; i++) {
            decPendingBalance(TaxId(i), taxes[TaxId(i)].pendingBalance, false);
        }
    }

    function getPendingTokens(TaxId id) internal view returns (uint256) {
        return taxes[id].pendingTokens;
    }

    function setPendingTokens(TaxId id, uint256 amount) internal {
        taxes[id].pendingTokens = amount;
    }

    function incPendingTokens(TaxId id, uint256 amount) internal {
        taxes[id].pendingTokens += amount;
    }

    function decPendingTokens(TaxId id, uint256 amount) internal {
        taxes[id].pendingTokens -= amount;
    }

    function resetPendingTokens() internal {
        uint8 min = uint8(type(TaxId).min);
        uint8 max = uint8(type(TaxId).max);

        for (uint8 i = min; i <= max; i++) {
            taxes[TaxId(i)].pendingTokens = 0;
        }
    }
}
