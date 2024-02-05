//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/utils/math/SafeMath.sol";
import "@openzeppelin/utils/Address.sol";
import "@openzeppelin/token/ERC20/IERC20.sol";
import "./ReentrantGuard.sol";
import "./IClimb.sol";
import "./IUniswapV2Router02.sol";

/**
 * Contract: Climb Token (xUSD fork)
 * By: SA69
 *
 * Token with a built-in Automated Market Maker
 * Send BNB to contract and it will mint CLIMB Tokens
 * Stake BUSD into contract and it will mint CLIMB Tokens
 * Sell this token to redeem underlying BUSD Tokens
 * Price is calculated as a ratio between Total Supply and underlying asset quantity in Contract
 */

abstract contract ClimbToken is IERC20, IClimb, ReentrancyGuard {

    using SafeMath for uint256;
    using Address for address;

    // token data
    string constant _name = "Climb";
    string constant _symbol = "CLIMB";
    uint8 constant _decimals = 18;
    uint256 constant precision = 10**18;

    // lock to Matrix contract
    bool isLocked = true;
    mapping (address => bool) public isMatrix;
    
    // 1 CLIMB Starting Supply
    uint256 _totalSupply = 1 * 10**_decimals;
    
    // balances
    mapping (address => uint256) _balances;
    mapping (address => mapping (address => uint256)) _allowances;

    // Fees
    uint256 public mintFee        = 950;   // 5.0% buy fee
    uint256 public sellFee        = 950;   // 5.0% sell fee 
    uint256 public transferFee    = 950;   // 5.0% transfer fee
    uint256 public constant feeDenominator = 10**3;

    uint256 public devShare = 100; // 1% dev fee
    uint256 public liquidityShare = 400; // 4% funding fee

    address public dev = 0x3bFb99f6eD9DAe9D09b65eF0Bb0ffF4473ea653b;

    // Underlying Asset
    address public constant _underlying = 0x55d398326f99059fF775485246999027B3197955; // USDT
    
    // fee exemption for utility
    mapping ( address => bool ) public isFeeExempt;
    
    // volume for each recipient
    mapping ( address => uint256 ) _volumeFor;
    
    // PCS Router
    IUniswapV2Router02 _router; 
    
    // BNB -> Token
    address[] path;
    
    // token purchase slippage maximum 
    uint256 public _tokenSlippage = 995;
    
    // owner
    address _owner;
    
    // Activates Token Trading
    bool Token_Activated;
    
    modifier onlyOwner() {
        require(msg.sender == _owner, 'Only Owner Function');
        _;
    }

    // initialize some stuff
    constructor () {
        
        // router
        _router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        path = new address[](2);
        path[0] = _router.WETH();
        path[1] = _underlying;
        
        // fee exempt this + owner + router for LP injection
        isFeeExempt[address(this)] = true;
        isFeeExempt[msg.sender] = true;
        isFeeExempt[0x10ED43C718714eb63d5aA57B78B54704E256024E] = true;
        
        // allocate one token to dead wallet to ensure total supply never reaches 0
        address dead = 0x000000000000000000000000000000000000dEaD;
        _balances[address(this)] = (_totalSupply - 1);
        _balances[dead] = 1;
        
        // ownership
        _owner = msg.sender;
        
        // emit allocations
        emit Transfer(address(0), address(this), (_totalSupply - 1));
        emit Transfer(address(0), dead, 1);
    }

    function totalSupply() external view override returns (uint256) { return _totalSupply; }
    function balanceOf(address account) public view override returns (uint256) { return _balances[account]; }
    function allowance(address holder, address spender) external view override returns (uint256) { return _allowances[holder][spender]; }
    
    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
  
    /** Transfer Function */
    function transfer(address recipient, uint256 amount) external override returns (bool) {
        return _transferFrom(msg.sender, recipient, amount);
    }

    /** Transfer Function */
    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        _allowances[sender][msg.sender] = _allowances[sender][msg.sender].sub(amount, 'Insufficient Allowance');
        return _transferFrom(sender, recipient, amount);
    }
    
    /** Internal Transfer */
    function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {
        // make standard checks
        require(recipient != address(0) && sender != address(0), "Transfer To Zero Address");
        require(amount > 0, "Transfer amount must be greater than zero");
        // track price change
        uint256 oldPrice = _calculatePrice();
        
        // fee exempt
        bool takeFee = !( isFeeExempt[sender] || isFeeExempt[recipient] );
        
        // amount to give recipient
        uint256 tAmount = takeFee ? amount.mul(transferFee).div(feeDenominator) : amount;
        
        // tax taken from transfer
        uint256 tax = amount.sub(tAmount);
        
        // subtract from sender
        _balances[sender] = _balances[sender].sub(amount, "Insufficient Balance");
        
        if (takeFee) {
            // allocate dev share
            uint256 allocation = tax.mul(devShare).div(devShare.add(liquidityShare));
            // mint to dev
            _mint(dev, allocation);
        }

        
        // give reduced amount to receiver
        _balances[recipient] = _balances[recipient].add(tAmount);
        
        // burn the tax
        if (tax > 0) {
            _totalSupply = _totalSupply.sub(tax);
            emit Transfer(sender, address(0), tax);
        }
        
        // volume for
        _volumeFor[sender] += amount;
        _volumeFor[recipient] += tAmount;
        
        // Price difference
        uint256 currentPrice = _calculatePrice();
        // Require Current Price >= Last Price
        require(currentPrice >= oldPrice, 'Price Must Rise For Transaction To Conclude');
        // Transfer Event
        emit Transfer(sender, recipient, tAmount);
        // Emit The Price Change
        emit PriceChange(oldPrice, currentPrice, _totalSupply);
        return true;
    }
    
    /** Receives Underlying Tokens and Deposits CLIMB in Sender's Address, Must Have Prior Approval */
    function buy(uint256 numTokens) external override nonReentrant returns (bool) {
        return _stakeUnderlyingAsset(numTokens, msg.sender);
    }
    
    /** Receives Underlying Tokens and Deposits CLIMB in Recipient's Address, Must Have Prior Approval */
    function buy(address recipient, uint256 numTokens) external override nonReentrant returns (bool) {
        return _stakeUnderlyingAsset(numTokens, recipient);
    }
    
    /** Sells CLIMB Tokens And Deposits Underlying Asset Tokens into Seller's Address */
    function sell(uint256 tokenAmount) external override nonReentrant {
        _sell(tokenAmount, msg.sender);
    }
    
    /** Sells CLIMB Tokens And Deposits Underlying Asset Tokens into Recipients's Address */
    function sell(address recipient, uint256 tokenAmount) external nonReentrant {
        _sell(tokenAmount, recipient);
    }
    
    /** Sells All CLIMB Tokens And Deposits Underlying Asset Tokens into Seller's Address */
    function sellAll() external nonReentrant {
        _sell(_balances[msg.sender], msg.sender);
    }
    
    /** Sells Without Including Decimals */
    function sellInWholeTokenAmounts(uint256 amount) external nonReentrant {
        _sell(amount.mul(10**_decimals), msg.sender);
    }
    
    /** Deletes CLIMB Tokens Sent To Contract */
    function takeOutGarbage() external nonReentrant {
        _checkGarbageCollector();
    }
    
    /** Allows A User To Erase Their Holdings From Supply */
    function eraseHoldings(uint256 nHoldings) external override {
        // get balance of caller
        uint256 bal = _balances[msg.sender];
        require(bal >= nHoldings && bal > 0, 'Zero Holdings');
        // if zero erase full balance
        uint256 burnAmount = nHoldings == 0 ? bal : nHoldings;
        // Track Change In Price
        uint256 oldPrice = _calculatePrice();
        // burn tokens from sender + supply
        _burn(msg.sender, burnAmount);
        // Emit Price Difference
        emit PriceChange(oldPrice, _calculatePrice(), _totalSupply);
        // Emit Call
        emit ErasedHoldings(msg.sender, burnAmount);
    }
    ///////////////////////////////////
    //////  EXTERNAL FUNCTIONS  ///////
    ///////////////////////////////////

    /** Burns CLIMB Token with BNB */
    function burn() payable external {
        uint256 prevAmount = _balances[address(this)];
        _purchase(address(this));
        uint256 amount = _balances[address(this)].sub(prevAmount);
        _burn(address(this), amount);
    }

    /** Burns CLIMB Token from msg.sender */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /** Burns CLIMB Token with Underlying, Must Have Prior Approval */
    function burnWithUnderlying(uint256 underlyingAmount) external {
        IERC20(_underlying).transferFrom(msg.sender, address(this), underlyingAmount);
        uint256 prevAmount = _balances[address(this)];
        _stakeUnderlyingAsset(underlyingAmount, address(this));
        uint256 amount = _balances[address(this)].sub(prevAmount);
        _burn(address(this), amount);
    }
    
    ///////////////////////////////////
    //////  INTERNAL FUNCTIONS  ///////
    ///////////////////////////////////

    /** Requires Price of CLIMB Token to Rise for The Transaction to Conclude */
    function _requirePriceRises(uint256 oldPrice) internal {
        // price after transaction
        uint256 newPrice = _calculatePrice();
        // require price to rise
        require(newPrice >= oldPrice, 'Price Must Rise For Transaction To Conclude');
        emit PriceChange(oldPrice, newPrice, _totalSupply);
    }
    
    /** Purchases CLIMB Token and Deposits Them in Recipient's Address */
    function _purchase(address recipient) private nonReentrant returns (bool) {
        // make sure emergency mode is disabled
        require(Token_Activated || _owner == msg.sender, 'Token Not Activated');
        // calculate price change
        uint256 oldPrice = _calculatePrice();
        // previous amount of underlying asset before we received any
        uint256 prevTokenAmount = IERC20(_underlying).balanceOf(address(this));
        // minimum output amount
        uint256 minOut = _router.getAmountsOut(msg.value, path)[1].mul(_tokenSlippage).div(1000);
        // buy Token with the BNB received
        _router.swapExactETHForTokens{value: msg.value}(
            minOut,
            path,
            address(this),
            block.timestamp.add(30)
        );
        // balance of underlying asset after swap
        uint256 currentTokenAmount = IERC20(_underlying).balanceOf(address(this));
        // number of Tokens we have purchased
        uint256 difference = currentTokenAmount.sub(prevTokenAmount);
        // if this is the first purchase, use new amount
        prevTokenAmount = prevTokenAmount == 0 ? currentTokenAmount : prevTokenAmount;
        // differentiate purchase
        emit TokenPurchased(difference, recipient);
        // mint to recipient
        return _handleMinting(recipient, difference, prevTokenAmount, oldPrice);
    }
    
    /** Stake Underlying Tokens and Deposits CLIMB in Sender's Address, Must Have Prior Approval */
    function _stakeUnderlyingAsset(uint256 numTokens, address recipient) internal returns (bool) {
        // make sure emergency mode is disabled
        require(Token_Activated || _owner == msg.sender, 'Token Not Activated');
        // user's underlying balance
        uint256 userTokenBalance = IERC20(_underlying).balanceOf(msg.sender);
        // ensure user has enough to send
        require(userTokenBalance > 0 && numTokens <= userTokenBalance, 'Insufficient Balance');
        // calculate price change
        uint256 oldPrice = _calculatePrice();
        // previous amount of underlying asset before any are received
        uint256 prevTokenAmount = IERC20(_underlying).balanceOf(address(this));
        // move asset into this contract
        bool success = IERC20(_underlying).transferFrom(msg.sender, address(this), numTokens);
        // balance of underlying asset after transfer
        uint256 currentTokenAmount = IERC20(_underlying).balanceOf(address(this));
        // number of Tokens we have purchased
        uint256 difference = currentTokenAmount.sub(prevTokenAmount);
        // ensure nothing unexpected happened
        require(difference <= numTokens && difference > 0, 'Failure on Token Evaluation');
        // ensure a successful transfer
        require(success, 'Failure On Token TransferFrom');
        // if this is the first purchase, use new amount
        prevTokenAmount = prevTokenAmount == 0 ? currentTokenAmount : prevTokenAmount;
        // Emit Staked
        emit TokenStaked(difference, recipient);
        // Handle Minting
        return _handleMinting(recipient, difference, prevTokenAmount, oldPrice);
    }
    
    /** Sells CLIMB Tokens And Deposits Underlying Asset Tokens into Recipients's Address */
    function _sell(uint256 tokenAmount, address recipient) internal {
        require(tokenAmount > 0 && _balances[msg.sender] >= tokenAmount);
        // calculate price change
        uint256 oldPrice = _calculatePrice();
        // fee exempt
        bool takeFee = !isFeeExempt[msg.sender];
        
        // tokens post fee to swap for underlying asset
        uint256 tokensToSwap = takeFee ? tokenAmount.mul(sellFee).div(feeDenominator) : tokenAmount.sub(100, '100 Asset Minimum For Fee Exemption');

        // value of taxed tokens
        uint256 amountUnderlyingAsset = (tokensToSwap.mul(oldPrice)).div(precision);
        // require above zero value
        require(amountUnderlyingAsset > 0, 'Zero Assets To Redeem For Given Value');
        
        // burn from sender + supply 
        _burn(msg.sender, tokenAmount);
        
        if (takeFee) {
            // difference
            uint256 taxTaken = tokenAmount.sub(tokensToSwap);
            // allocate dev share
            uint256 allocation = taxTaken.mul(devShare).div(devShare.add(liquidityShare));
            // mint to dev
            _mint(dev, allocation);
        }

        // send Tokens to Seller
        bool successful = IERC20(_underlying).transfer(recipient, amountUnderlyingAsset);
        // ensure Tokens were delivered
        require(successful, 'Underlying Asset Transfer Failure');
        // Requires The Price of CLIMB to Increase in order to complete the transaction
        _requirePriceRises(oldPrice);
        // Differentiate Sell
        emit TokenSold(tokenAmount, amountUnderlyingAsset, recipient);
    }
    
    /** Handles Minting Logic To Create New Tokens*/
    function _handleMinting(address recipient, uint256 received, uint256 prevTokenAmount, uint256 oldPrice) private returns(bool) {
        // check if isLocked or from Matrix
        require(!isLocked || isMatrix[msg.sender], 'CLIMB is Currently Locked Inside the Matrix');

        // fee exempt
        bool takeFee = !isFeeExempt[msg.sender];
        
        // find the number of tokens we should mint to keep up with the current price
        uint256 tokensToMintNoTax = _totalSupply.mul(received).div(prevTokenAmount);
        
        // apply fee to minted tokens to inflate price relative to total supply
        uint256 tokensToMint = takeFee ? tokensToMintNoTax.mul(mintFee).div(feeDenominator) : tokensToMintNoTax.sub(100, '100 Asset Minimum For Fee Exemption');

        // revert if under 1
        require(tokensToMint > 0, 'Must Purchase At Least One Climb Token');
        
        if (takeFee) {
            // difference
            uint256 taxTaken = tokensToMintNoTax.sub(tokensToMint);
            // allocate dev share
            uint256 allocation = taxTaken.mul(devShare).div(devShare.add(liquidityShare));
            // mint to dev
            _mint(dev, allocation);
        }
        
        // mint to Buyer
        _mint(recipient, tokensToMint);
        // Requires The Price of CLIMB to Increase in order to complete the transaction
        _requirePriceRises(oldPrice);
        return true;
    }
    
    /** Mints Tokens to the Receivers Address */
    function _mint(address receiver, uint amount) private {
        _balances[receiver] = _balances[receiver].add(amount);
        _totalSupply = _totalSupply.add(amount);
        _volumeFor[receiver] += amount;
        emit Transfer(address(0), receiver, amount);
    }
    
    /** Burns Tokens from the Receivers Address */
    function _burn(address receiver, uint amount) private {
        _balances[receiver] = _balances[receiver].sub(amount, 'Insufficient Balance');
        _totalSupply = _totalSupply.sub(amount, 'Negative Supply');
        _volumeFor[receiver] += amount;
        emit Transfer(receiver, address(0), amount);
    }

    /** Make Sure there's no Native Tokens in contract */
    function _checkGarbageCollector() internal {
        uint256 bal = _balances[address(this)];
        if (bal > 10) {
            // Track Change In Price
            uint256 oldPrice = _calculatePrice();
            // burn amount
            _burn(address(this), bal);
            // Emit Collection
            emit GarbageCollected(bal);
            // Emit Price Difference
            emit PriceChange(oldPrice, _calculatePrice(), _totalSupply);
        }
    }
    
    
    ///////////////////////////////////
    //////    READ FUNCTIONS    ///////
    ///////////////////////////////////
    
    /** Returns the Owner of the Contract */
    function owner() external view returns (address) {
        return _owner;
    }
    
    /** Price Of CLIMB in BUSD With 18 Points Of Precision */
    function calculatePrice() external view returns (uint256) {
        return _calculatePrice();
    }
    
    /** Precision Of $0.001 */
    function price() external view returns (uint256) {
        return _calculatePrice().mul(10**3).div(precision);
    }
    
    /** Returns the Current Price of 1 Token */
    function _calculatePrice() internal view returns (uint256) {
        uint256 tokenBalance = IERC20(_underlying).balanceOf(address(this));
        return (tokenBalance.mul(precision)).div(_totalSupply);
    }

    /** Returns the value of your holdings before the sell fee */
    function getValueOfHoldings(address holder) public view returns(uint256) {
        return _balances[holder].mul(_calculatePrice()).div(precision);
    }

    /** Returns the value of your holdings after the sell fee */
    function getValueOfHoldingsAfterTax(address holder) external view returns(uint256) {
        return getValueOfHoldings(holder).mul(sellFee).div(feeDenominator);
    }

    /** Returns The Address of the Underlying Asset */
    function getUnderlyingAsset() external override pure returns(address) {
        return _underlying;
    }
    
    /** Volume in CLIMB For A Particular Wallet */
    function volumeFor(address wallet) external override view returns (uint256) {
        return _volumeFor[wallet];
    }
    
    ///////////////////////////////////
    //////   OWNER FUNCTIONS    ///////
    ///////////////////////////////////
    
    
    /** Enables Trading For This Token, This Action Cannot be Undone */
    function ActivateToken() external onlyOwner {
        require(!Token_Activated, 'Already Activated Token');
        Token_Activated = true;
        emit TokenActivated(_totalSupply, _calculatePrice(), block.timestamp);
    }
    
    /** Excludes Contract From Fees */
    function setFeeExemption(address Contract, bool exempt) external onlyOwner {
        require(Contract != address(0));
        isFeeExempt[Contract] = exempt;
        emit SetFeeExemption(Contract, exempt);
    }

    /** Set Matrix Contract */
    function setMatrixContract(address newMatrix, bool exempt) external onlyOwner {
        require(newMatrix != address(0));
        isMatrix[newMatrix] = exempt;
        emit SetMatrixContract(newMatrix, exempt);
    }
    
    /** Updates The Threshold To Trigger The Garbage Collector */
    function changeTokenSlippage(uint256 newSlippage) external onlyOwner {
        require(newSlippage <= 995, 'invalid slippage');
        _tokenSlippage = newSlippage;
        emit UpdateTokenSlippage(newSlippage);
    }
    
    /** Updates The devShare and liquidityShare */
    function updateShares(uint256 newDevShare, uint256 newLiquidityShare) external onlyOwner {
        require(newDevShare.add(newLiquidityShare) <= 995, 'invalid shares');
        devShare = newDevShare;
        liquidityShare = newLiquidityShare;
        emit UpdateShares(devShare, liquidityShare);
    }

    /** Updates The dev Address */
    function updateDevAddress(address newDev) external onlyOwner {
        require(newDev != address(0));
        dev = newDev;
        emit UpdateDevAddress(newDev);
    }

    /** Updates The Sell, Mint, and Transfer Fees */
    function updateFees(uint256 newSellFee, uint256 newMintFee, uint256 newTransferFee) external onlyOwner {
        require(newSellFee <= 995 && newMintFee <= 995 && newTransferFee <= 995, 'invalid fees');
        sellFee = newSellFee;
        mintFee = newMintFee;
        transferFee = newTransferFee;
        emit UpdateFees(sellFee, mintFee, transferFee);
    }

    /** Unlocks The Contract For Outside of The Matrix */
    function unlockContract() external onlyOwner {
        require(!isLocked, 'Contract Already Unlocked');
        isLocked = false;
        emit ContractUnlocked(_calculatePrice(), block.timestamp);
    }

    /** Transfers Ownership To Another User */
    function transferOwnership(address newOwner) external override onlyOwner {
        _owner = newOwner;
        emit TransferOwnership(newOwner);
    }
    
    /** Transfers Ownership To Zero Address */
    function renounceOwnership() external onlyOwner {
        _owner = address(0);
        emit TransferOwnership(address(0));
    }
    
    /** Mint Tokens to Buyer */
    receive() external payable {
        _checkGarbageCollector();
        _purchase(msg.sender);
    }
    
    
    ///////////////////////////////////
    //////        EVENTS        ///////
    ///////////////////////////////////
    
    event UpdateShares(uint256 updatedDevShare, uint256 updatedLiquidityShare);
    event UpdateFees(uint256 updatedSellFee, uint256 updatedMintFee, uint256 updatedTransferFee);
    event UpdateDevAddress(address updatedDev);
    event SetMatrixContract(address newMatrix, bool exempt); 
    event ContractUnlocked(uint256 currentPrice, uint256 timestamp);
    event PriceChange(uint256 previousPrice, uint256 currentPrice, uint256 totalSupply);
    event ErasedHoldings(address who, uint256 amountTokensErased);
    event GarbageCollected(uint256 amountTokensErased);
    event UpdateTokenSlippage(uint256 newSlippage);
    event TransferOwnership(address newOwner);
    event TokenStaked(uint256 assetsReceived, address recipient);
    event SetFeeExemption(address Contract, bool exempt);
    event TokenActivated(uint256 totalSupply, uint256 price, uint256 timestamp);
    event TokenSold(uint256 amountCLIMB, uint256 assetsRedeemed, address recipient);
    event TokenPurchased(uint256 assetsReceived, address recipient);
    
}
