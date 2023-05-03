//SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./interfaces/IClimb.sol";
import "./interfaces/IUniswapV2Router02.sol";

/**
 * Contract: Climb Token v2 (xUSD fork)
 * By: SemiInvader & Bladepool
 *
 * Token with a built-in Automated Market Maker
 * buy tokens through contract with bUSD and USDT and it will mint CLIMB Tokens
 * Stake stables into contract and it will mint CLIMB Tokens
 * Sell this token to redeem underlying stable Tokens
 * Price is calculated as a ratio between Total Supply and underlying asset quantity in Contract
 */
// TODO implement a swap between STABLE TOKENS
// TODO token receives both USDT and BUSD

contract ClimbTokenV2 is IClimb, ReentrancyGuard, Ownable {
    using Address for address;

    struct Stable {
        uint balance;
        uint8 index;
        uint8 decimals;
        bool accepted;
        bool setup;
    }

    // token data
    string public constant name = "ClimbV2";
    string public constant symbol = "CLIMBv2";
    uint8 public constant decimals = 18;
    // Math constants
    uint256 constant PRECISION = 1 ether;

    // lock to Matrix contract
    mapping(address => bool) public isMatrix;
    // balances
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => Stable) public stables;
    address[] public currentStables;

    // 1 CLIMB Starting Supply
    uint256 public totalSupply = 1 ether;
    // Fees
    uint256 public mintFee = 50; // 5.0% buy fee
    uint256 public sellFee = 50; // 5.0% sell fee
    uint256 public transferFee = 50; // 5.0% transfer fee
    uint256 public constant feeDenominator = 1000;

    uint256 public devShare = 100; // 1%
    uint256 public liquidityShare = 400; // 4%
    uint256 public sharesDenominator = 500; // 5%

    address public dev;

    // fee exemption for utility
    mapping(address => bool) public isFeeExempt;

    // volume for each recipient
    mapping(address => uint256) _volumeFor;

    // token purchase slippage maximum
    uint256 public _tokenSlippage = 995;

    // Activates Token Trading
    bool Token_Activated;

    ///@notice initialize the contract
    /// 1. Set the Dev who receives some of the tx funds
    /// 2. set fee exemptions
    /// 3. mint the initial total supply
    /// 4. add all the stables we'll accept
    /// 5. emit Events
    constructor(address[] memory _stables, address _dev) {
        dev = _dev;
        // fee exempt this + owner + router for LP injection
        isFeeExempt[address(this)] = true;
        isFeeExempt[msg.sender] = true;

        // allocate one token to dead wallet to ensure total supply never reaches 0
        address dead = 0x000000000000000000000000000000000000dEaD;
        _balances[address(this)] = (totalSupply - 1);
        _balances[dead] = 1;

        require(_stables.length > 0, "No stables provided");

        for (uint8 i = 0; i < _stables.length; i++) {
            setStableToken(_stables[i], true);
            if (i == 0) {
                require(_stables[i] != address(0), "Invalid stable");
                stables[_stables[i]].balance = 1 ether;
            }
        }
        // emit allocations
        emit Transfer(address(0), address(this), (totalSupply - 1));
        emit Transfer(address(0), dead, 1);
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function allowance(
        address holder,
        address spender
    ) external view override returns (uint256) {
        return _allowances[holder][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    /** Transfer Function */
    function transfer(
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        return _transferFrom(msg.sender, recipient, amount);
    }

    /** Transfer Function */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        uint currentAllowance = _allowances[sender][msg.sender];
        require(
            currentAllowance >= amount,
            "Transfer amount exceeds allowance"
        );
        _allowances[sender][msg.sender] = currentAllowance - amount;

        return _transferFrom(sender, recipient, amount);
    }

    /** Internal Transfer */
    function _transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        // Zero Address Check
        require(
            sender != address(0) && recipient != address(0),
            "Tx to/from Zero"
        );
        // Amounts Check
        require(
            amount > 0 && _balances[sender] >= amount,
            "Invalid amount or balance"
        );
        // Track old price and sender volume
        uint256 oldPrice = _calculatePrice();
        // Update Sender balance and volume
        _balances[sender] -= amount;
        _volumeFor[sender] += amount;

        // Does Fee apply
        if (!(isFeeExempt[sender] || isFeeExempt[recipient])) {
            // Transfer Fee
            uint fee = (amount * transferFee) / feeDenominator;
            // Update actual transfer amount
            amount -= fee;
            // caculate devFee and liquidityFee
            uint devFee = (fee * devShare) / sharesDenominator;
            fee -= devFee;
            totalSupply -= fee;
            _balances[dev] += devFee;
            emit Transfer(sender, address(0), fee);
            emit Transfer(sender, dev, devFee);

            // Make sure price is updated since totalSupply changed
            // Here were simply reusing the fee variable
            fee = _calculatePrice();
            require(fee >= oldPrice, "Price MUST increase when fees apply");
            emit PriceChange(oldPrice, fee, totalSupply);
        }
        // update recipiente balance and volume
        _balances[recipient] += amount;
        _volumeFor[recipient] += amount;

        emit Transfer(sender, recipient, amount);

        return true;
    }

    /// @notice creates CLIMBv2 from _stable sent.
    /// @param numTokens the amount of tokens of _stable that will be sent to contract
    /// @param _stable the address of the Stable token to receive
    /// @dev MUST HAVE PRIOR APPROVAL
    function buy(
        uint256 numTokens,
        address _stable
    ) external nonReentrant returns (uint) {
        _transferInStable(_stable, numTokens);
        return _buyToken(numTokens, msg.sender, _stable);
    }

    /// @notice creates CLIMBv2 from _stable sent.
    /// @param recipient the user who will receive the tokens
    /// @param numTokens the amount of tokens of _stable that will be sent to contract
    /// @param _stable the address of the Stable token to receive
    /// @dev MUST HAVE PRIOR APPROVAL
    function buy(
        address recipient,
        uint256 numTokens,
        address _stable
    ) external nonReentrant returns (uint) {
        _transferInStable(_stable, numTokens);
        return _buyToken(numTokens, recipient, _stable);
    }

    /// @notice creates CLIMBv2 by sending tokens first to the contract, this is so we can  skim a transfer on a buy.
    /// @param recipient person who gets the swapped token
    /// @param numTokens, the amount of tokens sent in STABLE
    /// @param _stable the address of the STABLE contract addess
    function buyFor(
        address recipient,
        uint256 numTokens,
        address _stable
    ) external nonReentrant returns (uint) {
        require(isMatrix[msg.sender], "Only matrix allowed");
        return _buyToken(numTokens, recipient, _stable);
    }

    /// @notice sells CLIMB in exchange for _stable token
    /// @param tokenAmount amount of CLIMB to sell
    /// @param _stable contract address of the stable we want to receive
    function sell(
        uint256 tokenAmount,
        address _stable
    ) external nonReentrant returns (uint) {
        return _sell(tokenAmount, msg.sender, _stable);
    }

    /// @notice sells CLIMB in exchange for _stable token
    /// @param recipient address to send STABLEs to
    /// @param tokenAmount amount of CLIMB to sell
    /// @param _stable contract address of the stable we want to receive
    function sell(
        address recipient,
        uint256 tokenAmount,
        address _stable
    ) external nonReentrant returns (uint) {
        return _sell(tokenAmount, recipient, _stable);
    }

    /// @notice will attempt to sell all of the holding bag and receive only stable in return
    /// @param _stable the contract address of the stable to receive
    function sellAll(address _stable) external nonReentrant {
        _sell(_balances[msg.sender], msg.sender, _stable);
    }

    /// @notice a simplified version of SELL for contract use directly from explorer
    /// @param amount the amount of CLIMB tokens to sell to the nearest integer number
    /// @param _stable the contract address of the token we would receive
    function sellInWholeTokenAmounts(
        uint256 amount,
        address _stable
    ) external nonReentrant {
        _sell(amount * 10 ** decimals, msg.sender, _stable);
    }

    /** Deletes CLIMB Tokens Sent To Contract */
    function takeOutGarbage() external nonReentrant {
        _checkGarbageCollector();
    }

    /** Allows A User To Erase Their Holdings From Supply */
    function eraseHoldings(uint256 nHoldings) external {
        // get balance of caller
        uint256 bal = _balances[msg.sender];
        require(bal >= nHoldings && bal > 0, "Zero Holdings");
        // if zero erase full balance
        uint256 burnAmount = nHoldings == 0 ? bal : nHoldings;
        // Track Change In Price
        uint256 oldPrice = _calculatePrice();
        // burn tokens from sender + supply
        _burn(msg.sender, burnAmount);
        // Emit Price Difference
        emit PriceChange(oldPrice, _calculatePrice(), totalSupply);
        // Emit Call
        emit ErasedHoldings(msg.sender, burnAmount);
    }

    ///////////////////////////////////
    //////  EXTERNAL FUNCTIONS  ///////
    ///////////////////////////////////

    /** Burns CLIMB Token from msg.sender */
    function burn(uint256 amount) external {
        _burn(msg.sender, amount);
    }

    /** Burns CLIMB Token with Underlying, Must Have Prior Approval */
    function burnWithUnderlying(
        uint256 underlyingAmount,
        address _stable
    ) external {
        require(stables[_stable].accepted, "Stable Not Active");
        IERC20(_stable).transferFrom(
            msg.sender,
            address(this),
            underlyingAmount
        );
        uint256 prevAmount = _balances[address(this)];
        _buyToken(underlyingAmount, address(this), _stable);
        uint256 amount = _balances[address(this)] - prevAmount;
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
        require(
            newPrice >= oldPrice,
            "Price Must Rise For Transaction To Conclude"
        );
        emit PriceChange(oldPrice, newPrice, totalSupply);
    }

    function _transferInStable(address _stable, uint256 amount) internal {
        require(stables[_stable].accepted, "Stable Not Accepted");
        IERC20(_stable).transferFrom(msg.sender, address(this), amount);
    }

    /// @notice - This function is used to "STAKE" the stable token and calls to create CLIMB tokens
    function _buyToken(
        uint256 numTokens,
        address recipient,
        address _stable // Stable token to be used to buy
    ) internal returns (uint) {
        // make sure it's not locked
        require(
            Token_Activated || msg.sender == owner() || isMatrix[msg.sender],
            "Locked Inside the Matrix"
        );
        require(numTokens > 0, "> 0 please");
        Stable storage stable = stables[_stable];
        IERC20 token = IERC20(_stable);
        // calculate price change
        // This uses non synced values so it's fine to call after tokens have been transferred in
        uint256 oldPrice = _calculatePrice();
        // get all stables here
        uint currentBalance = stable.balance;
        uint prevAllStablesBalance = _adjustedAllStables();
        uint256 tokensToBuy = token.balanceOf(address(this));
        // update current stable amount
        stable.balance = tokensToBuy;
        tokensToBuy -= currentBalance;
        require(tokensToBuy >= numTokens, "No new tokens");
        tokensToBuy = _adjustedStableBalance(tokensToBuy, stable.decimals);
        return
            _handleMinting(
                recipient,
                tokensToBuy,
                prevAllStablesBalance,
                oldPrice
            );
    }

    /** Sells CLIMB Tokens And Deposits Underlying Asset Tokens into Recipients's Address */
    function _sell(
        uint256 tokenAmount,
        address recipient,
        address _stable
    ) internal returns (uint) {
        require(
            tokenAmount > 0 && _balances[msg.sender] >= tokenAmount,
            "Not enough balance"
        );
        Stable storage payoutStable = stables[_stable];
        require(payoutStable.accepted, "Stable Not Active");
        // calculate price change
        uint256 oldPrice = _calculatePrice();
        // fee exempt
        bool takeFee = !isFeeExempt[msg.sender];

        uint tokensToSwap;
        // tokens post fee to swap for underlying asset
        _burn(msg.sender, tokenAmount);
        if (!takeFee) {
            require(tokenAmount > 100, "Minimum of 100");
            tokensToSwap = tokenAmount - 100;
        } else {
            uint taxFee = (tokenAmount * sellFee) / feeDenominator;
            tokensToSwap = tokenAmount - taxFee;
            taxFee = (taxFee * devShare) / sharesDenominator;
            _mint(dev, taxFee);
        }

        // value of taxed tokens
        uint256 stableAmount = (tokensToSwap * oldPrice) / PRECISION;
        uint256 totalOfCurrentStable = _adjustedStableBalance(
            payoutStable.balance,
            payoutStable.decimals
        );
        // require above zero value
        require(
            stableAmount > 0 && stableAmount <= totalOfCurrentStable,
            "Not enough of STABLE"
        );
        // Adjust stable back to usable amounts
        stableAmount = _getAmountFromAdjusted(
            stableAmount,
            payoutStable.decimals
        );
        IERC20 stableToken = IERC20(_stable);
        // send Tokens to Seller
        bool successful = stableToken.transfer(recipient, stableAmount);
        // ensure Tokens were delivered
        require(successful, "Failed to send Stable");
        // set the new balance
        payoutStable.balance = stableToken.balanceOf(address(this));
        // Requires The Price of CLIMB to Increase in order to complete the transaction
        _requirePriceRises(oldPrice);
        // Differentiate Sell
        emit TokenSold(tokenAmount, stableAmount, recipient);
        return stableAmount;
    }

    /** Handles Minting Logic To Create New Tokens*/
    function _handleMinting(
        address recipient,
        uint256 received,
        uint256 prevTokenAmount,
        uint256 oldPrice
    ) private returns (uint) {
        // fee exempt
        bool takeFee = !isFeeExempt[msg.sender];
        require(received > 0, "No zero buy");
        // find the number of tokens we should mint to keep up with the current price
        // set initial value before deduction
        uint256 tokensToMint = (totalSupply * received) / prevTokenAmount;
        // apply fee to minted tokens to inflate price relative to total supply
        if (takeFee) {
            uint256 taxTaken = (tokensToMint * mintFee) / feeDenominator;
            tokensToMint -= taxTaken;
            // allocate dev share - we're reusing variables
            taxTaken = (taxTaken * devShare) / sharesDenominator;
            // mint to dev
            _mint(dev, taxTaken);
        } else {
            tokensToMint -= 100;
        }

        // mint to Buyer
        _mint(recipient, tokensToMint);
        // Requires The Price of CLIMB to Increase in order to complete the transaction
        _requirePriceRises(oldPrice);
        return tokensToMint;
    }

    /** Mints Tokens to the Receivers Address */
    function _mint(address receiver, uint256 amount) private {
        _balances[receiver] += amount;
        totalSupply += amount;
        _volumeFor[receiver] += amount;
        emit Transfer(address(0), receiver, amount);
    }

    /** Burns Tokens from the Receivers Address */
    function _burn(address receiver, uint256 amount) private {
        require(_balances[receiver] >= amount, "Insufficient Balance");
        _balances[receiver] -= amount;
        totalSupply -= amount;
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
            emit PriceChange(oldPrice, _calculatePrice(), totalSupply);
        }
    }

    ///////////////////////////////////
    //////    READ FUNCTIONS    ///////
    ///////////////////////////////////

    /** Price Of CLIMB in USD in wei */
    function calculatePrice() external view returns (uint256) {
        return _calculatePrice();
    }

    /** Precision Of $0.001 */
    function price() external view returns (uint256) {
        return (_calculatePrice() * 10 ** 3) / PRECISION;
    }

    /** Returns the Current Price of 1 Token */
    function _calculatePrice() internal view returns (uint256) {
        // get balance of accepted stables
        uint256 tokenBalance = _adjustedAllStables();
        return (tokenBalance * PRECISION) / totalSupply;
    }

    function _adjustedAllStables() private view returns (uint256) {
        uint256 tokenBalance = 0;
        for (uint8 i = 0; i < currentStables.length; i++) {
            Stable storage stable = stables[currentStables[i]];
            tokenBalance += _adjustedStableBalance(
                stable.balance,
                stable.decimals
            ); // adjust so everything is 18 decimals
        }
        return tokenBalance;
    }

    function _adjustedStableBalance(
        uint _stableBalance,
        uint8 _decimals
    ) private pure returns (uint) {
        return (_stableBalance * 1 ether) / (10 ** _decimals);
    }

    function _getAmountFromAdjusted(
        uint _adjustedAmount,
        uint8 _decimals
    ) private pure returns (uint) {
        return (_adjustedAmount * (10 ** _decimals)) / 1 ether;
    }

    /** Returns the value of your holdings before the sell fee */
    function getValueOfHoldings(address holder) public view returns (uint256) {
        return (_balances[holder] * _calculatePrice()) / PRECISION;
    }

    /** Returns the value of your holdings after the sell fee */
    function getValueOfHoldingsAfterTax(
        address holder
    ) external view returns (uint256) {
        uint currentHoldingValue = getValueOfHoldings(holder);
        uint tax = (getValueOfHoldings(holder) * sellFee) / feeDenominator;
        return currentHoldingValue - tax;
    }

    /** Volume in CLIMB For A Particular Wallet */
    function volumeFor(address wallet) external view returns (uint256) {
        return _volumeFor[wallet];
    }

    ///////////////////////////////////
    //////   OWNER FUNCTIONS    ///////
    ///////////////////////////////////

    /** Enables Trading For This Token, This Action Cannot be Undone */
    function ActivateToken() external onlyOwner {
        require(!Token_Activated, "Already Activated Token");
        Token_Activated = true;
        emit TokenActivated(totalSupply, _calculatePrice(), block.timestamp);
    }

    /** Excludes Contract From Fees */
    function setFeeExemption(address Contract, bool exempt) external onlyOwner {
        require(Contract != address(0));
        isFeeExempt[Contract] = exempt;
        emit SetFeeExemption(Contract, exempt);
    }

    /** Set Matrix Contract */
    function setMatrixContract(
        address newMatrix,
        bool exempt
    ) external onlyOwner {
        require(newMatrix != address(0));
        isMatrix[newMatrix] = exempt;
        emit SetMatrixContract(newMatrix, exempt);
    }

    /** Updates The Threshold To Trigger The Garbage Collector */
    function changeTokenSlippage(uint256 newSlippage) external onlyOwner {
        require(newSlippage <= 995, "invalid slippage");
        _tokenSlippage = newSlippage;
        emit UpdateTokenSlippage(newSlippage);
    }

    /** Updates The devShare and liquidityShare */
    function updateShares(
        uint256 newDevShare,
        uint256 newLiquidityShare
    ) external onlyOwner {
        require(newDevShare + newLiquidityShare <= 995, "invalid shares");
        devShare = newDevShare;
        liquidityShare = newLiquidityShare;
        sharesDenominator = devShare + liquidityShare;
        emit UpdateShares(devShare, liquidityShare);
    }

    /** Updates The dev Address */
    function updateDevAddress(address newDev) external onlyOwner {
        require(newDev != address(0));
        dev = newDev;
        emit UpdateDevAddress(newDev);
    }

    /** Updates The Sell, Mint, and Transfer Fees */
    function updateFees(
        uint256 newSellFee,
        uint256 newMintFee,
        uint256 newTransferFee
    ) external onlyOwner {
        require(
            newSellFee + newMintFee <= 250 && newTransferFee <= 250,
            "invalid fees"
        );
        sellFee = newSellFee;
        mintFee = newMintFee;
        transferFee = newTransferFee;
        emit UpdateFees(sellFee, mintFee, transferFee);
    }

    /// @notice Add or remove a Stable token to be used by CLIMBv2
    /// @param _stable The address of the STABLE token to change
    /// @param _accept The status to enable or disable the stable token
    /// @dev if the token is already set a few extra requirements are needed: 1. Not the only accepted token, 2. there are no more tokens held by this contract
    /// if setting up a new token, it would be ideal that some balance is sent before hand.
    function setStableToken(address _stable, bool _accept) public onlyOwner {
        require(_stable != address(0), "Zero");
        Stable storage stable = stables[_stable];
        require(stable.accepted != _accept, "Already set");
        stable.accepted = _accept;
        IERC20Metadata stableToken = IERC20Metadata(_stable);
        if (!_accept && stable.setup) {
            // If deleted && setup
            if (currentStables[0] == _stable) {
                require(currentStables.length > 1, "Not enough stables");
            }
            require(stable.balance == 0, "Balance not zero");
            if (stable.index < currentStables.length - 1) {
                currentStables[stable.index] = currentStables[
                    currentStables.length - 1
                ]; // substitute current index element with last element
            }
            currentStables.pop(); // remove last element
            stables[currentStables[stable.index]].index = stable.index;
            stable.index = 0;
            stable.setup = false;
            stable.accepted = false;
        } else if (_accept && !stable.setup) {
            // If added && not setup
            stable.index = uint8(currentStables.length);
            currentStables.push(_stable);
            stable.setup = true;
            stable.balance = stableToken.balanceOf(address(this));
            stable.decimals = stableToken.decimals();
        }

        emit SetStableToken(_stable, _accept);
    }

    /// @notice Show all accepted stables
    /// @return token address array in memory
    function allStables() external view returns (address[] memory) {
        return currentStables;
    }

    function exchangeTokens(
        address _from,
        address _to,
        address _router
    ) external onlyOwner {
        require(
            stables[_from].accepted && stables[_to].accepted,
            "Invalid stables"
        );

        IERC20 fromToken = IERC20(_from);
        IERC20 toToken = IERC20(_to);
        uint fromBalance = fromToken.balanceOf(address(this));
        uint toBalance = toToken.balanceOf(address(this));
        fromToken.approve(_router, fromBalance);
        address[] memory path = new address[](2);
        path[0] = _from;
        path[1] = _to;
        IUniswapV2Router02(_router).swapExactTokensForTokens(
            fromBalance,
            0,
            path,
            address(this),
            block.timestamp
        );
        uint newToBalance = toToken.balanceOf(address(this));
        require(newToBalance > stables[_to].balance, "No tokens received");
        stables[_to].balance = newToBalance;
        stables[_from].balance = 0;
    }
}