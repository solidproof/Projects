//                                   @@@@@@@&&##&%
//                            %&&&@@@@@@@@&&&%%&&%%&%&%/*
//                        #%&&@@@@@@@@@@&@@&&&%(&%&&&&/***.,.
//                     .#%&@@@@@@@@@@@@@@&&&&&*/&(%%%%&*#(/,/*.
//                   (#%&@@@@@@@@@@@@&@@&&&&%%%%%##/((/**%#**.*/**
//                  (##%%%%%##(*,,,%&&#,,,,,,,,,,,,,,,,,((##(#,,,(/
//              ,&%%#%%%%..%%%%%#%.*&&#.%%%%#&&..%#%%%%%##./(/.%&%%%#%,,%,,,,,,,
//              .&%%%%%%%.%%%&%%%&,*%%#.%&%%%%%,,%%%%&&%%&%,//,&%&%%%%,,%%%%%&%,.
//              ,&#%#%%&,,%%%&#%#&,*%%(,%%#%#%%,,&#%%%#%#%%&,.,&%&#%#%,,%%#%%&#&,
//              ,&&%#%&&,,%&&&%%%&,*%&/*&&&%#&&,,%#%&&&&%&&&&%,&&&%%#&(,&%#%&&&%,
//             .,&#%&%&&,,&%&&#&&#,*%%*,@&#&&#&,,%&#&&#%,#&&#%&(&&#%&%@,,%&#&&#%,
//     ,,,,,,,,#,&&&#&&&,,#&&&&&#&,*%%,&&&&&#&&,,&#&&&&&**&&&&#&&&&&#&&,,&#&&&&&,
//   ,&&&@&%&&*%*%&&&@&%,,&@&%&&&@&,,,&@&%&&&@&,,&&@&%&&,.,,&&&@&#&&&@&,,&&@&#&&,.
//   ,%&&@@@%&&&@@%&&@@,.(,&@@%&&&@@%&&&@@%&&,***&&&@@&&,.((.&&&@@&&&&@,,&&&@@%&,.
//    *@&@&@@@&@@@@@&,..//*#,,(&%@&@@@&@&@,,.*#*,&%&&@@@,.///,%@@@@@&@&,,@&@&@@@%,
//      ,,,,,,,,,,,.(###(#%%%%**////(((/////%&%(///////**(#*/(#(............,@@&&.
//       .,//*((//***#%&&&&%#%%%&&&&&&%&&&&&/#%#&&&&&&#(/#(#%####((***/((/**///*
//         .*/((((((%%%%%%%%%#%%%%%#%%%%&#%*%##%&&&###(%####/%((%##/(((((#((*.
//             ..... **(#######%%####%%%%%%%%%%%%%%(&(%%%%#%(/(/*,   .....,..
//                     ,/(###%%%#%%%%%%&%%(&&&%&*(%(%&&&&%##%(/
//                        ///###%%%%%&&&@&&&&&%/%,&&&&&%%%%/*
//                            /((##%%&&&&@&&&&&&&%&&&%%%#
//                                   (##%%%%%%&&&&

/*                                                                             
This is the official contract of JackpotUniverse token. This token
is the official successor of LAS (Last Ape Standing) BSC token.
LAS was the first token of its kind to implement an innovative jackpot mechanism.
JUNI builds upon that innovation and brings in a creative referral system and expands
on the jackpot paradigm.

Every buy and sell will feed 1 main and 3 secondary jackpots (bronze, silver and gold).
Secondary jackpots will be cashed out at specific intervals of time as a true lottery-ticket system. The main
jackpot adheres to the same rules as that of LAS. If for 10 mins, no buys are recorded, the last buyer
will receive a portion of the jackpot.

The main jackpot has a hard limit ($100K) that, if reached, will trigger the big bang event. A portion
of the jackpot will be cashed out to the buyback wallet. The buyback wallet will
then either burn the tokens or dedicate a portion of it towards staking.

Website: https://www.juni.gg
Twitter: https://twitter.com/JUNIBSC
Instagram: https://www.instagram.com/juniversebsc/
*/

// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "./Ownable.sol";
import "./IJackpotGuard.sol";
import "./IJackpotBroker.sol";
import "./IJackpotReferral.sol";
import "./JackpotToken.sol";

contract JackpotUniverse is IERC20, JackpotToken {
    using Address for address;
    using EnumerableSet for EnumerableSet.AddressSet;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;

    string private constant NAME = "JackpotUniverse";
    string private constant SYMBOL = "JUNI";
    uint8 private constant DECIMALS = 9;
    uint256 private constant TOTAL = 10000000 * 10**DECIMALS;

    // We don't add to liquidity unless we have at least 1 JUNI token
    uint256 private constant LIQ_SWAP_THRESH = 10**DECIMALS;

    // Liquidity
    bool public swapAndLiquifyEnabled = true;
    bool private _inSwapAndLiquify;

    bool public tradingOpen = false;
    bool public jackpotLimited = true;

    IJackpotBroker private jBroker;
    IJackpotGuard private jGuard;
    IJackpotReferral private jReferral;

    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 bnbReceived,
        uint256 tokensIntoLiquidity
    );

    event ValueReceived(address origin, address user, uint256 amount);

    event ValueReceivedInFallback(address origin, address user, uint256 amount);

    event JackpotGuardChanged(address oldGuard, address newGuard);

    event JackpotReferralChanged(address oldBroker, address newBroker);

    event JackpotBrokerChanged(address oldBroker, address newBroker);

    event JackpotLimited(bool limited);

    event TradingStatusChanged(bool status);

    modifier lockTheSwap() {
        _inSwapAndLiquify = true;
        _;
        _inSwapAndLiquify = false;
    }

    constructor(
        address jGuardAddr,
        address jReferralAddr,
        address jBrokerAddr
    ) Treasury(TOTAL, DECIMALS) {
        jGuard = IJackpotGuard(jGuardAddr);
        emit JackpotGuardChanged(address(0), jGuardAddr);

        jReferral = IJackpotReferral(jReferralAddr);
        emit JackpotReferralChanged(address(0), jReferralAddr);

        jBroker = IJackpotBroker(jBrokerAddr);
        emit JackpotBrokerChanged(address(0), jBrokerAddr);

        _balances[msg.sender] = TOTAL;

        // Exempts from fees, tx limit and max wallet
        exemptFromAll(owner());
        exemptFromAll(address(this));

        emit Transfer(address(0), msg.sender, TOTAL);
    }

    receive() external payable {
        if (msg.value > 0) {
            emit ValueReceived(tx.origin, msg.sender, msg.value);
        }
    }

    fallback() external payable {
        if (msg.value > 0) {
            emit ValueReceivedInFallback(tx.origin, msg.sender, msg.value);
        }
    }

    function name() public pure returns (string memory) {
        return NAME;
    }

    function symbol() public pure returns (string memory) {
        return SYMBOL;
    }

    function decimals() public pure returns (uint8) {
        return DECIMALS;
    }

    function totalSupply() public pure returns (uint256) {
        return TOTAL;
    }

    function balanceOf(address account) public view returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address wallet, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[wallet][spender];
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        approve(_msgSender(), spender, amount);
        return true;
    }

    function approve(
        address wallet,
        address spender,
        uint256 amount
    ) private {
        require(wallet != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");

        _allowances[wallet][spender] = amount;
        emit Approval(wallet, spender, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        require(
            _allowances[sender][_msgSender()] >= amount,
            "BEP20: transfer amount exceeds allowance"
        );
        transfer(sender, recipient, amount);
        approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()] - amount
        );
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        require(
            _allowances[_msgSender()][spender] >= subtractedValue,
            "BEP20: decreased allowance below zero"
        );
        approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] - subtractedValue
        );
        return true;
    }

    function fundJackpot(uint256 tokenAmount) external payable onlyAuthorized {
        require(
            balanceOf(msg.sender) >= tokenAmount,
            "You don't have enough tokens to fund the jackpot"
        );
        uint256 bnbSent = msg.value;
        incPendingBalance(TaxId.Jackpot, bnbSent);
        if (tokenAmount > 0) {
            transferBasic(msg.sender, address(this), tokenAmount);
            incPendingTokens(TaxId.Jackpot, tokenAmount);
        }

        emit JackpotFund(bnbSent, tokenAmount);
    }

    function getUsedTokens(
        uint256 accSum,
        uint256 tokenAmount,
        uint256 tokens
    ) private pure returns (uint256, uint256) {
        if (accSum >= tokenAmount) {
            return (0, accSum);
        }
        uint256 available = tokenAmount - accSum;
        if (tokens <= available) {
            return (tokens, accSum + tokens);
        }
        return (available, accSum + available);
    }

    function getTokenShares(uint256 tokenAmount)
        private
        returns (uint256[] memory, uint256)
    {
        uint256 accSum = 0;
        uint8 min = uint8(type(TaxId).min);
        uint8 max = uint8(type(TaxId).max);
        uint256[] memory tokens = new uint256[](max - min + 1);

        for (uint8 i = min; i <= max; i++) {
            TaxId id = TaxId(i);
            uint256 pendingTokens = getPendingTokens(id);
            (tokens[i], accSum) = getUsedTokens(
                accSum,
                tokenAmount,
                pendingTokens
            );
            decPendingTokens(id, tokens[i]);
        }

        return (tokens, accSum);
    }

    function setSwapAndLiquifyEnabled(bool enabled) public onlyOwner {
        swapAndLiquifyEnabled = enabled;
        emit SwapAndLiquifyEnabledUpdated(enabled);
    }

    function setJackpotBroker(address otherBroker) external onlyOwner {
        address oldBroker = address(jBroker);
        jBroker = IJackpotBroker(otherBroker);

        emit JackpotBrokerChanged(oldBroker, otherBroker);
    }

    function setJackpotGuard(address otherGuard) external onlyOwner {
        address oldGuard = address(jGuard);
        jGuard = IJackpotGuard(otherGuard);

        emit JackpotGuardChanged(oldGuard, otherGuard);
    }

    function setJackpotLimited(bool limited) external onlyOwner {
        jackpotLimited = limited;

        emit JackpotLimited(limited);
    }

    function transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "BEP20: transfer from the zero address");
        require(to != address(0), "BEP20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(!jGuard.isRestricted(from), "Source wallet is banned");
        require(!jGuard.isRestricted(to), "Destination wallet is banned");

        if (from != owner() && to != owner()) {
            require(
                isTxLimitExempt(from) ||
                    isTxLimitExempt(to) ||
                    amount <= maxTxAmount,
                "Transfer amount exceeds the maxTxAmount"
            );
        }

        if (!isAuthorized(from) && !isAuthorized(to)) {
            require(tradingOpen, "Trading is currently not open");
        }

        // Jackpot mechanism locks the swap if triggered. We should handle it as
        // soon as possible so that we could award the jackpot on a sell and on a buy
        if (
            !_inSwapAndLiquify &&
            jackpotEnabled &&
            jGuard.usdEquivalent(
                address(swapRouter),
                getPendingBalance(TaxId.Jackpot)
            ) >=
            jackpotHardLimit
        ) {
            processBigBang();
            resetJackpot();
        } else if (
            // We can't award the jackpot in swap and liquify
            // Pending balances need to be untouched (externally) for swaps
            !_inSwapAndLiquify &&
            jackpotEnabled &&
            _lastBuyer != address(0) &&
            _lastBuyer != address(this) &&
            (block.timestamp - _lastBuyTimestamp) >= jackpotTimespan
        ) {
            awardJackpot();
        }

        uint256 pendingTokens = getPendingTokensTotal();

        if (pendingTokens >= maxTxAmount) {
            pendingTokens = maxTxAmount;
        }

        if (
            pendingTokens >= numTokensSellToAddToLiquidity &&
            !_inSwapAndLiquify &&
            !isSwapAndLiquifyExempt(from) &&
            swapAndLiquifyEnabled
        ) {
            swapAndLiquify(numTokensSellToAddToLiquidity);
            fundJackpots();
        }
        // Check if any secondary jackpots are ready to be awarded
        jBroker.processBroker();

        tokenTransfer(from, to, amount);
    }

    function withdrawBnb() external onlyOwner {
        uint256 excess = address(this).balance;
        require(excess > 0, "No BNBs to withdraw");
        resetPendingBalances();
        Address.sendValue(payable(_msgSender()), excess);
    }

    function withdrawNativeTokens() external onlyOwner {
        uint256 excess = balanceOf(address(this));
        require(excess > 0, "No tokens to withdraw");
        resetPendingTokens();
        transferBasic(address(this), _msgSender(), excess);
    }

    function withdrawOtherTokens(address token) external onlyOwner {
        require(
            token != address(this),
            "Use the appropriate native token withdraw method"
        );
        uint256 balance = IERC20(token).balanceOf(address(this));
        require(balance > 0, "No tokens to withdraw");
        IERC20(token).transfer(_msgSender(), balance);
    }

    function setTradingStatus(bool status) external onlyOwner {
        tradingOpen = status;
        emit TradingStatusChanged(status);
    }

    function jackpotBuyerShareAmount()
        external
        view
        returns (uint256, uint256)
    {
        TaxId id = TaxId.Jackpot;
        uint256 bnb = (getPendingBalance(id) *
            jackpotCashout *
            jackpotBuyerShare) / MAX_PCT**2;
        uint256 tokens = (getPendingTokens(id) *
            jackpotCashout *
            jackpotBuyerShare) / MAX_PCT**2;
        return (bnb, tokens);
    }

    function jackpotBuybackAmount() external view returns (uint256, uint256) {
        TaxId id = TaxId.Jackpot;
        uint256 bnb = (getPendingBalance(id) *
            jackpotCashout *
            (MAX_PCT - jackpotBuyerShare)) / MAX_PCT**2;
        uint256 tokens = (getPendingTokens(id) *
            jackpotCashout *
            (MAX_PCT - jackpotBuyerShare)) / MAX_PCT**2;

        return (bnb, tokens);
    }

    function processBigBang() internal override lockTheSwap {
        TaxId id = TaxId.Jackpot;
        uint256 cashedOut = (getPendingBalance(id) * jackpotHardBuyback) /
            MAX_PCT;
        uint256 tokensOut = (getPendingTokens(id) * jackpotHardBuyback) /
            MAX_PCT;

        _lastBigBangCash = cashedOut;
        _lastBigBangTokens = tokensOut;
        _lastBigBangTimestamp = block.timestamp;

        decPendingBalance(id, cashedOut, true);
        decPendingTokens(id, tokensOut);

        _totalJackpotCashedOut += cashedOut;
        _totalJackpotBuyback += cashedOut;
        _totalJackpotTokensOut += tokensOut;
        _totalJackpotBuybackTokens += tokensOut;

        transferBasic(address(this), buybackWallet(), tokensOut);
        Address.sendValue(buybackWallet(), cashedOut);

        emit BigBang(cashedOut, tokensOut);
    }

    function awardJackpot() internal override lockTheSwap {
        require(
            _lastBuyer != address(0) && _lastBuyer != address(this),
            "No last buyer detected"
        );

        // Just in case something thought they're smart to circumvent the contract code length check,
        // This will prevent them from winning the jackpot since the contract has been already deployed.
        // So, the next check for jackpot eligibility must fail if the address was truly a contract
        if (!jGuard.isJackpotEligibleOnAward(_lastBuyer)) {
            // Nice try, you win absolutely nothing. Let's reset the jackpot.
            resetJackpot();
            return;
        }

        TaxId id = TaxId.Jackpot;
        uint256 cashedOut = (getPendingBalance(id) * jackpotCashout) / MAX_PCT;
        uint256 tokensOut = (getPendingTokens(id) * jackpotCashout) / MAX_PCT;
        uint256 buyerShare = (cashedOut * jackpotBuyerShare) / MAX_PCT;
        uint256 tokensToBuyer = (tokensOut * jackpotBuyerShare) / MAX_PCT;
        uint256 toBuyback = cashedOut - buyerShare;
        uint256 tokensToBuyback = tokensOut - tokensToBuyer;

        decPendingBalance(id, cashedOut, true);
        decPendingTokens(id, tokensOut);

        _lastAwarded = _lastBuyer;
        _lastAwardedTimestamp = block.timestamp;
        _lastAwardedCash = buyerShare;
        _lastAwardedTokens = tokensToBuyer;

        _lastBuyer = payable(address(this));
        _lastBuyTimestamp = 0;

        _totalJackpotCashedOut += cashedOut;
        _totalJackpotTokensOut += tokensOut;
        _totalJackpotBuyer += buyerShare;
        _totalJackpotBuyerTokens += tokensToBuyer;
        _totalJackpotBuyback += toBuyback;
        _totalJackpotBuybackTokens += tokensToBuyback;

        transferBasic(address(this), _lastAwarded, tokensToBuyer);
        transferBasic(address(this), buybackWallet(), tokensToBuyback);
        // This will never fail since the jackpot is only awarded to wallets
        Address.sendValue(payable(_lastAwarded), buyerShare);
        Address.sendValue(buybackWallet(), toBuyback);

        emit JackpotAwarded(
            _lastAwarded,
            cashedOut,
            tokensOut,
            buyerShare,
            tokensToBuyer,
            toBuyback,
            tokensToBuyback
        );
    }

    function resetJackpotExt() external onlyAuthorized {
        resetJackpot();
    }

    function fundJackpots() internal {
        uint256 bronzeBalance = getPendingBalance(TaxId.BronzeJackpot);
        uint256 silverBalance = getPendingBalance(TaxId.SilverJackpot);
        uint256 goldBalance = getPendingBalance(TaxId.GoldJackpot);
        uint256 totalJpBalance = bronzeBalance + silverBalance + goldBalance;
        if (totalJpBalance > 0) {
            jBroker.fundJackpots{value: totalJpBalance}(
                bronzeBalance,
                silverBalance,
                goldBalance
            );
            decPendingBalance(TaxId.BronzeJackpot, bronzeBalance, true);
            decPendingBalance(TaxId.SilverJackpot, silverBalance, true);
            decPendingBalance(TaxId.GoldJackpot, goldBalance, true);
        }
    }

    function swapAndLiquify(uint256 tokenAmount) private lockTheSwap {
        (uint256[] memory tokens, uint256 toBeSwapped) = getTokenShares(
            tokenAmount
        );
        uint256 liqTokens = tokens[uint8(TaxId.Liquidity)];
        if (liqTokens < LIQ_SWAP_THRESH) {
            // We're not gonna add to liquidity
            incPendingTokens(TaxId.Liquidity, liqTokens);
            liqTokens = 0;
        }

        // This variable holds the liquidity tokens that won't be converted
        uint256 pureLiqTokens = liqTokens / 2;

        // Everything else from the tokens should be converted
        uint256 tokensForBnbExchange = toBeSwapped - pureLiqTokens;

        uint256 initialBalance = address(this).balance;
        swapTokensForBnb(tokensForBnbExchange);

        // How many BNBs did we gain after this conversion?
        uint256 gainedBnb = address(this).balance - initialBalance;

        uint8 min = uint8(type(TaxId).min);
        uint8 max = uint8(type(TaxId).max);
        uint256 grantedBalances = 0;
        // Skip liquidity here when processing pending balances
        for (uint8 i = min + 1; i <= max; i++) {
            TaxId id = TaxId(i);
            uint256 balanceToAdd = (gainedBnb * tokens[i]) /
                tokensForBnbExchange;
            incPendingBalance(id, balanceToAdd);
            grantedBalances += balanceToAdd;
        }

        uint256 remainingBnb = gainedBnb - grantedBalances;

        if (liqTokens >= LIQ_SWAP_THRESH) {
            // The leftover BNBs are purely for liquidity here
            // We are not guaranteed to have all the pure liq tokens to be transferred to the pair
            // This is because the uniswap router, PCS in this case, will make a quote based
            // on the current reserves of the pair, so one of the parameters will be fully
            // consumed, but the other will have leftovers.
            uint256 prevBalance = balanceOf(address(this));
            uint256 prevBnbBalance = address(this).balance;
            addLiquidity(pureLiqTokens, remainingBnb);
            uint256 usedBnbs = prevBnbBalance - address(this).balance;
            uint256 usedTokens = prevBalance - balanceOf(address(this));
            // Reallocate the tokens that weren't used back to the internal liquidity tokens tracker
            if (usedTokens < pureLiqTokens) {
                incPendingTokens(TaxId.Liquidity, pureLiqTokens - usedTokens);
            }
            // Reallocate the unused BNBs to the pending marketing wallet balance
            if (usedBnbs < remainingBnb) {
                incPendingBalance(TaxId.Marketing, remainingBnb - usedBnbs);
            }

            emit SwapAndLiquify(tokensForBnbExchange, usedBnbs, usedTokens);
        } else {
            // We could have some dust, so we'll just add it to the pending marketing wallet balance
            incPendingBalance(TaxId.Marketing, remainingBnb);

            emit SwapAndLiquify(tokensForBnbExchange, 0, 0);
        }
    }

    function swapTokensForBnb(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = swapRouter.WETH();

        approve(address(this), address(swapRouter), tokenAmount);
        swapRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
        // Approve token transfer to cover all possible scenarios
        approve(address(this), address(swapRouter), tokenAmount);

        // Add the liquidity
        swapRouter.addLiquidityETH{value: bnbAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            lockedLiquidity(),
            block.timestamp
        );
    }

    function tokenTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) private {
        bool takeFee = false;
        bool isBuy = false;
        bool isSenderPool = liquidityPools.contains(sender);
        bool isRecipientPool = liquidityPools.contains(recipient);

        if (isFeeExempt(sender) || isFeeExempt(recipient)) {
            // takeFee is false, so we good
        } else if (isRecipientPool && !isSenderPool) {
            // This is a sell
            takeFee = true;
        } else if (isSenderPool && !isRecipientPool) {
            // If we're here, it must mean that the sender is the uniswap pair
            // This is a buy
            takeFee = true;
            isBuy = true;
            uint256 qualifier = jGuard.getJackpotQualifier(
                swapRouters[sender],
                address(this),
                jackpotMinBuy,
                amount
            );
            if (qualifier >= 1 && jGuard.isJackpotEligibleOnBuy(recipient)) {
                jReferral.awardTickets(recipient, qualifier);
                if (
                    jackpotEnabled &&
                    (!jackpotLimited ||
                        jGuard.usdEquivalent(
                            address(swapRouter),
                            getPendingBalance(TaxId.Jackpot)
                        ) >=
                        jackpotHardLimit / 2)
                ) {
                    _lastBuyTimestamp = block.timestamp;
                    _lastBuyer = payable(recipient);
                }
            }
        } else {
            // Wallet to wallet
            jReferral.refer(sender, recipient, amount);
        }

        transferStandard(sender, recipient, amount, takeFee, isBuy);
    }

    function transferBasic(
        address sender,
        address recipient,
        uint256 amount
    ) private {
        _balances[sender] -= amount;
        _balances[recipient] += amount;

        emit Transfer(sender, recipient, amount);
    }

    function transferStandard(
        address sender,
        address recipient,
        uint256 tAmount,
        bool takeFee,
        bool isBuy
    ) private {
        (uint256 tTransferAmount, uint256 tFees) = processAmount(
            tAmount,
            takeFee,
            isBuy
        );
        if (!liquidityPools.contains(recipient) && recipient != DEAD) {
            require(
                isMaxWalletExempt(recipient) ||
                    (balanceOf(recipient) + tTransferAmount) <= maxWalletSize,
                "Transfer amount will push this wallet beyond the maximum allowed size"
            );
        }

        _balances[sender] -= tAmount;
        _balances[recipient] += tTransferAmount;

        takeTransactionFee(sender, address(this), tFees);

        emit Transfer(sender, recipient, tTransferAmount);
    }

    function processAmount(
        uint256 tAmount,
        bool takeFee,
        bool isBuy
    ) private returns (uint256, uint256) {
        if (!takeFee) {
            return (tAmount, 0);
        }

        uint8 min = uint8(type(TaxId).min);
        uint8 max = uint8(type(TaxId).max);
        uint256 tFees = 0;
        for (uint8 i = min; i <= max; i++) {
            TaxId id = TaxId(i);
            uint256 taxTokens;
            if (isBuy) {
                taxTokens = (tAmount * getBuyFee(id)) / MAX_PCT;
            } else {
                taxTokens = (tAmount * getSellFee(id)) / MAX_PCT;
            }
            tFees += taxTokens;
            incPendingTokens(id, taxTokens);
        }

        return (tAmount - tFees, tFees);
    }

    function takeTransactionFee(
        address from,
        address to,
        uint256 tAmount
    ) private {
        if (tAmount <= 0) {
            return;
        }
        _balances[to] += tAmount;
        emit Transfer(from, to, tAmount);
    }

    function aboutMe() public pure returns (uint256) {
        return 0x6164646f34370a;
    }
}
