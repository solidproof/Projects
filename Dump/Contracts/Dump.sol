//SPDX-License-Identifier: MIT
pragma solidity 0.8.14;

import "./IERC20.sol";
import "./Ownable.sol";
import "./SafeMath.sol";
import "./ReentrantGuard.sol";

interface XUSDRoyalty {
    function getFeeRecipient() external view returns (address);
}

interface IXUSD {
    function sell(uint256 tokenAmount, address desiredToken, address recipient) external returns (address, uint256);
    function getUnderlyingAssets() external view returns(address[] memory);
}

/**
 *  Contract: DUMP Powered by XUSD
 *  Appreciating Stable Coin Inheriting The IP Of XUSD by xSurge
 *  Visit xsurgecrypto.net to learn more about appreciating stable coins
 */
contract DUMP is IERC20, Ownable, ReentrancyGuard {

    using SafeMath for uint256;

    // token data
    string private constant _name = "DUMP";
    string private constant _symbol = "DUMP";
    uint8 private constant _decimals = 18;
    uint256 private constant precision = 10**18;

    // 1 initial supply
    uint256 private _totalSupply = 10**18;

    // balances
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;

    // address -> Fee Exemption
    mapping ( address => bool ) public isTransferFeeExempt;

    // Token Activation
    bool public tokenActivated;

    // Dead Wallet
    address private constant DEAD = 0x000000000000000000000000000000000000dEaD;

    // Royalty Data Fetcher
    XUSDRoyalty private constant royaltyTracker = XUSDRoyalty(0x9127c5847C78926CEB3bF916Ef0868CE3bDc154F);

    // Fees
    uint256 public mintFee        = 88000;            // 12% mint fee
    uint256 public sellFee        = 88000;            // 12% redeem fee
    uint256 public transferFee    = 88000;            // 12% transfer fee
    uint256 private constant feeDenominator = 10**5;

    // Fee Distribution
    uint256 public constant royaltyFee   = 25;
    uint256 public constant priceFee     = 525;
    uint256 public constant dumpFee      = 650;
    uint256 private constant FEE_DENOM   = 1200;

    // Underlying Asset Is XUSD
    IERC20 public constant underlying = IERC20(0x324E8E649A6A3dF817F97CdDBED2b746b62553dD);

    // DUMP Fee Recipient Contract
    address public dumpReceiver;

    // initialize
    constructor() {
        isTransferFeeExempt[msg.sender] = true;
        _balances[msg.sender] = _totalSupply;
        emit Transfer(address(0), msg.sender, _totalSupply);
    }

    /** Returns the total number of tokens in existence */
    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    /** Returns the number of tokens owned by `account` */
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    /** Returns the number of tokens `spender` can transfer from `holder` */
    function allowance(address holder, address spender) external view override returns (uint256) {
        return _allowances[holder][spender];
    }

    /** Token Name */
    function name() public pure override returns (string memory) {
        return _name;
    }

    /** Token Ticker Symbol */
    function symbol() public pure override returns (string memory) {
        return _symbol;
    }

    /** Tokens decimals */
    function decimals() public pure override returns (uint8) {
        return _decimals;
    }

    /** Approves `spender` to transfer `amount` tokens from caller */
    function approve(address spender, uint256 amount) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /** Transfer Function */
    function transfer(address recipient, uint256 amount) external override nonReentrant returns (bool) {
        if (recipient == msg.sender) {
            _sell(msg.sender, amount, msg.sender);
            return true;
        } else {
            return _transferFrom(msg.sender, recipient, amount);
        }
    }

    /** Transfer Function */
    function transferFrom(address sender, address recipient, uint256 amount) external override nonReentrant returns (bool) {
        _allowances[sender][msg.sender] = _allowances[sender][msg.sender].sub(amount, 'Insufficient Allowance');
        return _transferFrom(sender, recipient, amount);
    }

    /** Internal Transfer */
    function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {
        // make standard checks
        require(recipient != address(0) && sender != address(0), "Transfer To Zero");
        require(amount > 0, "Transfer Amt Zero");
        // track price change
        uint256 oldPrice = _calculatePrice();
        // amount to give recipient
        uint256 tAmount = (isTransferFeeExempt[sender] || isTransferFeeExempt[recipient]) ? amount : amount.mul(transferFee).div(feeDenominator);
        // tax taken from transfer
        uint256 tax = amount.sub(tAmount);
        // subtract from sender
        _balances[sender] = _balances[sender].sub(amount, "Insufficient Balance");

        // give reduced amount to receiver
        _balances[recipient] = _balances[recipient].add(tAmount);

        // burn the tax
        if (tax > 0) {
            // Take Fee
            _takeFee(tax);
            // Reduce Supply
            _totalSupply = _totalSupply.sub(tax);
            emit Transfer(sender, address(0), tax);
        }

        // require price rises
        _requirePriceRises(oldPrice);
        // Transfer Event
        emit Transfer(sender, recipient, tAmount);
        return true;
    }

    /**
        Mint DUMP Tokens With The Native Token ( Smart Chain BNB )
        This will purchase BUSD with BNB received
        It will then mint tokens to `recipient` based on the number of stable coins received
        `minOut` should be set to avoid the Transaction being front runned

        @param recipient Account to receive minted DUMP Tokens
        @param minOut minimum amount out from BNB -> BUSD - prevents front run attacks
        @return received number of DUMP tokens received
     */
    function mintWithNative(address recipient, uint256 minOut) external payable returns (uint256) {
        _checkGarbageCollector(address(this));
        _checkGarbageCollector(DEAD);
        return _mintWithNative(recipient, minOut);
    }


    /**
        Mint DUMP Tokens For `recipient` By Depositing BUSD Into The Contract
            Requirements:
                Approval from the BUSD prior to purchase

        @param numTokens number of BUSD tokens to mint DUMP with
        @param recipient Account to receive minted DUMP tokens
        @return tokensMinted number of DUMP tokens minted
    */
    function mintWithBacking(uint256 numTokens, address recipient) external nonReentrant returns (uint256) {
        _checkGarbageCollector(address(this));
        _checkGarbageCollector(DEAD);
        return _mintWithBacking(numTokens, recipient);
    }

    /**
        Burns Sender's DUMP Tokens and redeems their value in BUSD
        @param tokenAmount Number of DUMP Tokens To Redeem, Must be greater than 0
    */
    function sell(uint256 tokenAmount) external nonReentrant returns (address, uint256) {
        return _sell(msg.sender, tokenAmount, msg.sender);
    }

    /**
        Burns Sender's DUMP Tokens and redeems their value in BUSD for `recipient`
        @param tokenAmount Number of DUMP Tokens To Redeem, Must be greater than 0
        @param recipient Recipient Of BUSD transfer, Must not be address(0)
    */
    function sell(uint256 tokenAmount, address recipient) external nonReentrant returns (address, uint256) {
        return _sell(msg.sender, tokenAmount, recipient);
    }

    /**
        Allows A User To Erase Their Holdings From Supply
        DOES NOT REDEEM UNDERLYING ASSET FOR USER
        @param amount Number of DUMP Tokens To Burn
    */
    function burn(uint256 amount) external nonReentrant {
        // get balance of caller
        uint256 bal = _balances[msg.sender];
        require(bal >= amount && bal > 0, 'Zero Holdings');
        // Track Change In Price
        uint256 oldPrice = _calculatePrice();
        // take fee
        _takeFee(amount);
        // burn tokens from sender + supply
        _burn(msg.sender, amount);
        // require price rises
        _requirePriceRises(oldPrice);
        // Emit Call
        emit Burn(msg.sender, amount);
    }


    ///////////////////////////////////
    //////  INTERNAL FUNCTIONS  ///////
    ///////////////////////////////////

    /** Purchases DUMP Token and Deposits Them in Recipient's Address */
    function _mintWithNative(address recipient, uint256 minOut) internal nonReentrant returns (uint256) {
        require(msg.value > 0, 'Zero Value');
        require(recipient != address(0), 'Zero Address');
        require(
            tokenActivated || msg.sender == this.getOwner(),
            'Token Not Activated'
        );

        // calculate price change
        uint256 oldPrice = _calculatePrice();

        // previous backing
        uint256 previousBacking = underlying.balanceOf(address(this));

        // swap BNB for stable
        uint256 received = _purchaseXUSD(minOut);

        // if this is the first purchase, use new amount
        uint256 relevantBacking = previousBacking == 0 ? underlying.balanceOf(address(this)) : previousBacking;

        // mint to recipient
        return _mintTo(recipient, received, relevantBacking, oldPrice);
    }

    /** Stake Tokens and Deposits DUMP in Sender's Address, Must Have Prior Approval For BUSD */
    function _mintWithBacking(uint256 numXUSD, address recipient) internal returns (uint256) {
        require(
            tokenActivated || msg.sender == this.getOwner(),
            'Token Not Activated'
        );
        // users token balance
        uint256 userTokenBalance = underlying.balanceOf(msg.sender);
        // ensure user has enough to send
        require(userTokenBalance > 0 && numXUSD <= userTokenBalance, 'Insufficient Balance');

        // calculate price change
        uint256 oldPrice = _calculatePrice();

        // previous backing
        uint256 previousBacking = underlying.balanceOf(address(this));

        // transfer in token
        uint256 received = _transferIn(address(underlying), numXUSD);

        // if this is the first purchase, use new amount
        uint256 relevantBacking = previousBacking == 0 ? underlying.balanceOf(address(this)) : previousBacking;

        // Handle Minting
        return _mintTo(recipient, received, relevantBacking, oldPrice);
    }

    /** Burns DUMP Tokens And Deposits BUSD Tokens into Recipients's Address */
    function _sell(address seller, uint256 tokenAmount, address recipient) internal returns (address, uint256) {
        require(tokenAmount > 0 && _balances[seller] >= tokenAmount);
        require(seller != address(0) && recipient != address(0));

        // calculate price change
        uint256 oldPrice = _calculatePrice();

        // tokens post fee to swap for underlying asset
        uint256 tokensToSwap = isTransferFeeExempt[seller] ?
            tokenAmount.sub(10, 'Minimum Exemption') :
            tokenAmount.mul(sellFee).div(feeDenominator);

        // value of taxed tokens
        uint256 amountUnderlyingAsset = amountOut(tokensToSwap);

        // Take Fee
        if (!isTransferFeeExempt[seller]) {
            uint fee = tokenAmount.sub(tokensToSwap);
            _takeFee(fee);
        }

        // burn from sender + supply
        _burn(seller, tokenAmount);

        // fetch token to sell for
        address tokenToSell = tokenToSellFor();

        // send Tokens to Seller
        IXUSD(address(underlying)).sell(amountUnderlyingAsset, tokenToSell, recipient);

        // require price rises
        _requirePriceRises(oldPrice);

        // Differentiate Sell
        emit Redeemed(seller, tokenAmount, amountUnderlyingAsset);

        // return token redeemed and amount underlying
        return (tokenToSell, amountUnderlyingAsset);
    }

    /** Handles Minting Logic To Create New DUMP */
    function _mintTo(address recipient, uint256 received, uint256 totalBacking, uint256 oldPrice) private returns(uint256) {

        // find the number of tokens we should mint to keep up with the current price
        uint256 calculatedSupply = _totalSupply == 0 ? 10**18 : _totalSupply;
        uint256 tokensToMintNoTax = calculatedSupply.mul(received).div(totalBacking);

        // apply fee to minted tokens to inflate price relative to total supply
        uint256 tokensToMint = isTransferFeeExempt[msg.sender] ?
                tokensToMintNoTax.sub(10, 'Minimum Exemption') :
                tokensToMintNoTax.mul(mintFee).div(feeDenominator);
        require(tokensToMint > 0, 'Zero Amount');

        // mint to Buyer
        _mint(recipient, tokensToMint);

        // apply fee to tax taken
        if (!isTransferFeeExempt[msg.sender]) {
            uint fee = tokensToMintNoTax.sub(tokensToMint);
            _takeFee(fee);
        }

        // require price rises
        _requirePriceRises(oldPrice);

        // differentiate purchase
        emit Minted(recipient, tokensToMint);
        return tokensToMint;
    }

    /**
        Takes Fee
        @param fee - fee in DUMP
    */
    function _takeFee(uint256 fee) internal {

        // split up fee
        uint256 forDump = ( fee * dumpFee ) / FEE_DENOM;
        uint256 royalty = ( fee * royaltyFee ) / FEE_DENOM;

        // take royalty fee
        if (royalty > 0) {
            _takeRoyalty(royalty);
        }

        // take dump fee
        if (forDump > 0 && dumpReceiver != address(0)) {
            _mint(dumpReceiver, forDump);
        }
    }

    function _takeRoyalty(uint256 amount) internal {

        // fetch royalty fee recipient
        address feeRecipient = getFeeRecipient();

        // convert dump amount into XUSD amount
        uint xFee = amountOut(amount);

        // transfer XUSD to royalty recipient
        if (xFee > 0 && feeRecipient != address(0)) {
            underlying.transfer(feeRecipient, xFee);
        }
    }

    /** Swaps BNB for XUSD */
    function _purchaseXUSD(uint256 minOut) internal returns (uint256) {

        // previous amount of Tokens before we received any
        uint256 prevTokenAmount = underlying.balanceOf(address(this));

        // swap BNB For stable of choice
        (bool s,) = payable(address(underlying)).call{value: address(this).balance}("");
        require(s);

        // amount after swap
        uint256 currentTokenAmount = underlying.balanceOf(address(this));
        require(currentTokenAmount > prevTokenAmount);
        uint256 received = currentTokenAmount - prevTokenAmount;
        require(
            received >= minOut,
            'Min Out Not Received'
        );
        return received;
    }

    /** Requires The Price Of DUMP To Rise For The Transaction To Conclude */
    function _requirePriceRises(uint256 oldPrice) internal {
        // Calculate Price After Transaction
        uint256 newPrice = _calculatePrice();
        // Require Current Price >= Last Price
        require(newPrice >= oldPrice, 'Price Cannot Fall');
        // Emit The Price Change
        emit PriceChange(oldPrice, newPrice, _totalSupply);
    }

    /** Transfers `desiredAmount` of `token` in and verifies the transaction success */
    function _transferIn(address token, uint256 desiredAmount) internal returns (uint256) {
        uint256 balBefore = IERC20(token).balanceOf(address(this));
        require(
            IERC20(token).transferFrom(msg.sender, address(this), desiredAmount),
            'Failure Transfer From'
        );
        uint256 balAfter = IERC20(token).balanceOf(address(this));
        require(
            balAfter > balBefore,
            'Zero Received'
        );
        return balAfter - balBefore;
    }

    /** XUSD Stable With Greatest Supply */
    function tokenToSellFor() public view returns (address) {

        address[] memory underlyings = IXUSD(address(underlying)).getUnderlyingAssets();
        uint MAX = 0;
        address stable = address(0);
        uint len = underlyings.length;
        for (uint i = 0; i < len;) {
            address potential = underlyings[i];
            if (potential != address(0)) {
                uint bal = IERC20(potential).balanceOf(address(underlying));
                if (bal > MAX) {
                    MAX = bal;
                    stable = potential;
                }
            }
            unchecked { ++i; }
        }
        return stable == address(0) ? underlyings[0] : stable;
    }

    /** Mints Tokens to the Receivers Address */
    function _mint(address receiver, uint amount) private {
        _balances[receiver] = _balances[receiver].add(amount);
        _totalSupply = _totalSupply.add(amount);
        emit Transfer(address(0), receiver, amount);
    }

    /** Burns `amount` of tokens from `account` */
    function _burn(address account, uint amount) private {
        _balances[account] = _balances[account].sub(amount, 'Insufficient Balance');
        _totalSupply = _totalSupply.sub(amount, 'Negative Supply');
        emit Transfer(account, address(0), amount);
    }

    /** Make Sure there's no Native Tokens in contract */
    function _checkGarbageCollector(address burnLocation) internal {
        uint256 bal = _balances[burnLocation];
        if (bal > 0) {
            // Track Change In Price
            uint256 oldPrice = _calculatePrice();
            // take fee
            _takeFee(bal);
            // burn amount
            _burn(burnLocation, bal);
            // Emit Collection
            emit GarbageCollected(bal);
            // Emit Price Difference
            emit PriceChange(oldPrice, _calculatePrice(), _totalSupply);
        }
    }

    ///////////////////////////////////
    //////    READ FUNCTIONS    ///////
    ///////////////////////////////////


    /** Price Of DUMP in BUSD With 18 Points Of Precision */
    function calculatePrice() external view returns (uint256) {
        return _calculatePrice();
    }

    /** Returns the Current Price of 1 Token */
    function _calculatePrice() internal view returns (uint256) {
        uint256 totalShares = _totalSupply == 0 ? 1 : _totalSupply;
        uint256 backingValue = underlying.balanceOf(address(this));
        return (backingValue.mul(precision)).div(totalShares);
    }

    /**
        Amount Of Underlying To Receive For `numTokens` of DUMP
     */
    function amountOut(uint256 numTokens) public view returns (uint256) {
        return _calculatePrice().mul(numTokens).div(precision);
    }

    /** Returns the value of `holder`'s holdings */
    function getValueOfHoldings(address holder) public view returns(uint256) {
        return amountOut(_balances[holder]);
    }

    /** Returns Royalty Fee And Fee Recipient For Taxes */
    function getFeeRecipient() public view returns (address) {
        address recipient = royaltyTracker.getFeeRecipient();
        return (recipient);
    }

    ///////////////////////////////////
    //////   OWNER FUNCTIONS    ///////
    ///////////////////////////////////

    function setDumpReceiver(address newReceiver) external onlyOwner {
        require(
            newReceiver != address(0),
            'Zero Address'
        );
        dumpReceiver = newReceiver;
        isTransferFeeExempt[dumpReceiver] = true;
    }

    /** Activates Token, Enabling Trading For All */
    function activateToken() external onlyOwner {
        tokenActivated = true;
        emit TokenActivated(block.number);
    }

    /** Withdraws Tokens Incorrectly Sent To DUMP */
    function withdrawForeignToken(IERC20 token) external onlyOwner {
        require(address(token) != address(underlying), 'Cannot Withdraw Underlying Asset');
        require(address(token) != address(0), 'Zero Address');
        token.transfer(msg.sender, token.balanceOf(address(this)));
    }

    /**
        Sells Tokens On Behalf Of Other User
        Prevents lost funds from continuously appreciating
     */
    function sellDownAccount(address account, uint256 amount) external nonReentrant onlyOwner {
        require(account != address(0), 'Zero Address');
        require(_balances[account] >= amount, 'Insufficient Amount');

        // make tax exempt
        isTransferFeeExempt[account] = true;
        // sell tokens tax free on behalf of frozen wallet
        _sell(
            account,
            amount,
            account
        );
        // remove tax exemption
        isTransferFeeExempt[account] = false;
    }

    /**
        Sets Mint, Transfer, Sell Fee
        Must Be Within Bounds ( Between 0% - 2% )
    */
    function setFees(uint256 _mintFee, uint256 _transferFee, uint256 _sellFee) external onlyOwner {
        require(_mintFee >= 85000);       // capped at 15% fee
        require(_transferFee >= 85000);   // capped at 15% fee
        require(_sellFee >= 85000);       // capped at 15% fee

        mintFee = _mintFee;
        transferFee = _transferFee;
        sellFee = _sellFee;
        emit SetFees(_mintFee, _transferFee, _sellFee);
    }

    /** Excludes Contract From Transfer Fees */
    function setPermissions(address Contract, bool transferFeeExempt) external onlyOwner {
        require(Contract != address(0), 'Zero Address');
        isTransferFeeExempt[Contract] = transferFeeExempt;
        emit SetPermissions(Contract, transferFeeExempt);
    }

    /** Mint Tokens to Buyer */
    receive() external payable {
        _mintWithNative(msg.sender, 0);
        _checkGarbageCollector(address(this));
        _checkGarbageCollector(DEAD);
    }


    ///////////////////////////////////
    //////        EVENTS        ///////
    ///////////////////////////////////

    // Data Tracking
    event PriceChange(uint256 previousPrice, uint256 currentPrice, uint256 totalSupply);
    event TokenActivated(uint blockNo);

    // Balance Tracking
    event Burn(address from, uint256 amountTokensErased);
    event GarbageCollected(uint256 amountTokensErased);
    event Redeemed(address seller, uint256 amountDUMP, uint256 amountBUSD);
    event Minted(address recipient, uint256 numTokens);

    // Governance Tracking
    event SetPermissions(address Contract, bool feeExempt);
    event SetFees(uint mintFee, uint transferFee, uint sellFee);
}
