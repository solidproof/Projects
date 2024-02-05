
// SPDX-License-Identifier: Unlicensed
pragma solidity 0.8.19;
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

// file: pinkBotInterface.sol
interface IPinkAntiBot {
    function setTokenOwner(address owner) external;

    function onPreTransferCheck(
        address from,
        address to,
        uint256 amount
    ) external;
}

// file: RDB.sol
/**
 * @title RDB Token
 * @dev Implementation of the RDB Token
 */
contract RDB is Context, IERC20, Ownable {
    using SafeMath for uint256;
    using Address for address;

    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;


    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) private _isExcluded;
    bool public isTradingEnabled;
    bool public isPinkBotEnabled;

    address[] private _excluded;

    uint256 private constant MAX = ~uint256(0);
    uint256 private constant _tTotal = 100000000 * 1e9; // 100 million supply
    uint256 private _rTotal = (MAX - (MAX % _tTotal));
    uint256 private _tFeeTotal;
    uint256 public maxWallet = 1000000 * 1e9; // 1 million (1% of the supply)



    string private constant _name = "RDB Token";
    string private constant _symbol = "RDB";
    uint8 private constant _decimals = 9;

    struct BuyFee {
        uint16 marketingFee;
        uint16 reflectionFee;
        uint16 developmentFee;
        uint16 founderFee;
    }

    struct SellFee {
        uint16 marketingFee;
        uint16 reflectionFee;
        uint16 developmentFee;
        uint16 founderFee;
    }

    BuyFee public buyFee;
    SellFee public sellFee;

    uint16 private _reflectionFee;
    uint16 private _marketingFee;
    uint16 private _developmentFee;
    uint16 private _founderFee;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;
    address public founderWallet;
    address public developmentWallet;
    address public marketingWallet;
    address public presaleAddress;

    IPinkAntiBot public pinkAntiBot;


    bool internal inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;

    uint256 private swapThreshold = 1000 * 1e9;


    event MinTokensBeforeSwapUpdated(uint256 minTokensBeforeSwap);
    event SwapAndLiquifyEnabledUpdated(bool enabled);
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 ethReceived
    );
    event MaxWalletUpdated(uint256 amount);
    event BuyFeesUpdated (uint256 marketingFee, uint256 ReflectionFee, uint256 developmentFee, uint256 FounderFee);
    event SellFeesUpdated (uint256 marketingFee, uint256 ReflectionFee, uint256 developmentFee, uint256 FounderFee);
    event TokensClaimed (address indexed token, uint256 amount);
    event BNBClaimed (uint256 amount);

    event RouterUpdated(address indexed oldRouter, address indexed newRouter);

    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    /**
     * @dev Contract constructor function. Initializes contract state variables and sets the owner of the contract.
     * The constructor sets the initial supply, fee rates, and creates a Uniswap pair for the token.
     * It also sets the addresses for the marketing, development, and founder wallets.
     * Finally, it excludes the owner and the contract itself from fees, and emits a `Transfer` event.
     */
    constructor() {
        _rOwned[_msgSender()] = _rTotal;

        // Set fee rates
        buyFee.reflectionFee = 1;
        buyFee.marketingFee = 1;
        buyFee.developmentFee =1;
        buyFee.founderFee = 1;

        sellFee.reflectionFee = 2;
        sellFee.marketingFee = 2;
        sellFee.developmentFee = 2;
        sellFee.founderFee = 2;

        // Creating an instance of the PinkAntiBot variable from the given address
        //https://github.com/pinkmoonfinance/pink-antibot-guide
        pinkAntiBot = IPinkAntiBot(0x8EFDb3b642eb2a20607ffe0A56CFefF6a95Df002);
        pinkAntiBot.setTokenOwner(msg.sender);

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            0x10ED43C718714eb63d5aA57B78B54704E256024E // pancakeswap Router
        );
        // Create a uniswap pair for this new token
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        // set the rest of the contract variables
        uniswapV2Router = _uniswapV2Router;

        // set your wallets below

        founderWallet = address(0xc7f72fEf9B09503cEf0c26188D714403dce71E7E);
        developmentWallet = address(0x269F5B5A349DDD46126a6AFfD1936b776F55162F);
        marketingWallet = address(0xE0747a60E81B616990cEbF791602e41571755D6c);
        //exclude owner and this contract from fee
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;


        emit Transfer(address(0), _msgSender(), _tTotal );

    }

    /**
     * @dev Returns the token name.
     */
    function name() public pure returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the token symbol.
     */
    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the token decimals.
     */
    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    /**
     * @dev Returns the total token supply.
     */
    function totalSupply() public pure override returns (uint256) {
        return _tTotal;
    }

    /**
     * @dev Returns the token balance of the given `account`.
     */
    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    /**
     * @dev Returns the token balance of the given `account`.
     */
    function transfer(address recipient, uint256 amount)
    public
    override
    returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev Returns the token allowance for the given `owner` and `spender`.
     */
    function allowance(address tokenOwner, address spender)
    public
    view
    override
    returns (uint256)
    {
        return _allowances[tokenOwner][spender];
    }

    /**
     * @dev Sets the allowance to `amount` for the `spender` address.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount)
    public
    override
    returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * This function emits a {Transfer} event and an {Approval} event indicating
     * the updated allowance.
     *
     * Requirements:
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for `sender`'s tokens of at least `amount`.
     *
     * @param sender the address of the sender.
     * @param recipient the address of the recipient.
     * @param amount the amount of tokens to be transferred.
     * @return a boolean value indicating whether the operation succeeded.
     */
    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {}
    function transferFrom(address sender, address recipient, uint256 amount)
    public
    override
    returns (bool)
    {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue)
    public
    virtual
    returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].add(addedValue)
        );
        return true;
    }

    /**
    * @dev Decreases the allowance granted by the caller to `spender`.
    * This is an alternative to {approve} that can be used as a mitigation for
    * problems described in {IERC20-approve}.
    * Emits an {Approval} event indicating the updated allowance.
    * Requirements:
    * - `spender` cannot be the zero address.
    * - `spender` must have allowance for the caller of at least
    * `subtractedValue`.
    * @param spender The address which will spend the funds.
    * @param subtractedValue The amount of allowance to decrease.
    * @return A boolean value indicating whether the operation succeeded.
    */
    function decreaseAllowance(address spender, uint256 subtractedValue)
    public
    virtual
    returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(
                subtractedValue,
                "ERC20: decreased allowance below zero"
            )
        );
        return true;
    }

    /**
     * @dev Transfer tokens to the contract itself, which will effectively remove the tokens from circulation.
     * This will increase the rate at which all holders will earn rewards.
     * @param tAmount The amount of tokens to be delivered (removed from circulation).
     */
    function deliver(uint256 tAmount) public {
        address sender = _msgSender();
        require(
            !_isExcluded[sender],
            "Excluded addresses cannot call this function"
        );
        (uint256 rAmount, , , , , ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rTotal = _rTotal.sub(rAmount);
        _tFeeTotal = _tFeeTotal.add(tAmount);
    }

    /**
     * @dev Returns the reflection amount of given token amount
     *
     * This function is used to get the reflection amount from a given token amount with the option to deduct the transfer fee.
     * It's a view function meaning it will not modify the state of the blockchain. It will only read the values.
     *
     * @param tAmount - the token amount to get the reflection from
     * @param deductTransferFee - a boolean value indicating whether the transfer fee should be deducted
     *
     * @return - the calculated reflection amount
     */
    function reflectionFromToken(uint256 tAmount, bool deductTransferFee)
    public
    view
    returns (uint256)
    {
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
    * @dev Converts reflection amount to token amount
    * @param rAmount amount of reflection
    * @return amount of tokens
    */
    function tokenFromReflection(uint256 rAmount)
    public
    view
    returns (uint256)
    {
        require(
            rAmount <= _rTotal,
            "Amount must be less than total reflections"
        );
        uint256 currentRate = _getRate();
        return rAmount.div(currentRate);
    }

    ///@dev update the router
    ///@param newAddress: owner can update the router address
    function updateRouter(address newAddress) external onlyOwner {
        require(newAddress != address(uniswapV2Router), "The router already has that address");
        require(newAddress != address(0), "zero address not allowed");
        address oldRouter = address(uniswapV2Router);
        uniswapV2Router = IUniswapV2Router02(newAddress);
        address get_pair =
                                IUniswapV2Factory(uniswapV2Router.factory()).getPair(address(this),
                uniswapV2Router.WETH());
        if (get_pair == address(0)) {
            uniswapV2Pair =
                                    IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this),
                    uniswapV2Router.WETH());
        } else {
            uniswapV2Pair = get_pair;
        }

        emit RouterUpdated(oldRouter, newAddress);
    }

    ///@dev enable or disbale pinkbot
    ///@param value: boolean value, true means enabled, false means disabled
    function managePinkBot (bool value) external onlyOwner {
        isPinkBotEnabled = value;
    }

    ///@dev set presale address (useful incase using pinksale or similiar platform for presale)
    ///@param _presaleAddress: presale address
    function setPresaleAddress(address _presaleAddress) external onlyOwner {
        require (_presaleAddress != address(0), "zero address not allowed");
        presaleAddress = _presaleAddress;
        _isExcludedFromFee[_presaleAddress] = true;
    }

    ///@dev update max wallet amount
    ///@param amount: new maxWallet amount, must be greator than equal to 1 percent of the supply
    function updateMaxWalletAmount (uint256 amount) external onlyOwner {
        require (amount >= totalSupply() /100,"amount must be 1% or more of the total supply");
        maxWallet = amount;
        emit MaxWalletUpdated (amount);
    }

    ///@notice Returns if an address is excluded or not from reflection
    function isExcludedFromReward(address account) public view returns (bool) {
        return _isExcluded[account];
    }

    ///@notice Returns total reflection distributed so far
    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    ///@dev exclude a particular address from reward
    ///@param account: address to be excluded from reward
    function excludeFromReward(address account) public onlyOwner {
        require(!_isExcluded[account], "Account is already excluded");
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    ///@dev include a address in reward
    ///@param account: address to be added in reward mapping again
    function includeInReward (address account) external onlyOwner {
        require(_isExcluded [account], "Account is already excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {

            if (_excluded[i] == account){
                //updating _rOwned to make sure the balances stay the same
                if (_tOwned [account] > 0) {
                    uint256 newrOwned = _tOwned [account].mul(_getRate());
                    _rTotal = _rTotal.sub(_rOwned [account]-newrOwned);
                    _rOwned[account] = newrOwned;
                }
                else{
                    _rOwned [account] = 0;
                }
                _tOwned[account]= 0;
                _excluded [i] = _excluded [_excluded.length-1];
                _isExcluded [account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    ///@dev manage exclude and include fee
    ///@param account: account to be excluded or included
    ///@param excluded: boolean value, true means excluded, false means included
    function excludeFromFee(address account, bool excluded) external onlyOwner {
        require(account != presaleAddress, "Presale address cannot be included in fees again");
        if (excluded) {
            require(!_isExcludedFromFee[account], "already excluded");
        }
        _isExcludedFromFee[account] = excluded;
    }


    ///@dev set buy fees
    ///@param market: new marketing fee on buy
    ///@param reflection: new reflection fee on buy
    ///@param development: new development fee on buy
    ///@param founder: new founder fee on buy
    function setBuyFee(
        uint16 market,
        uint16 reflection,
        uint16 development,
        uint16 founder
    ) external onlyOwner {
        buyFee.marketingFee = market;
        buyFee.reflectionFee = reflection;
        buyFee.developmentFee = development;
        buyFee.founderFee = founder;
        uint256 totalBuyFee = market  + reflection + development + founder;
        require(totalBuyFee <= 10, "max buy fee limit is 10%");

        emit BuyFeesUpdated (market, reflection, development, founder);
    }

    ///@dev set sell fees
    ///@param market: new marketing fee on sell
    ///@param reflection: new reflection fee on sell
    ///@param development: new development fee on sell
    ///@param founder: new founder fee on sell
    function setSellFee(
        uint16 market,
        uint16 reflection,
        uint16 development,
        uint16 founder
    ) external onlyOwner {
        sellFee.marketingFee = market;
        sellFee.reflectionFee = reflection;
        sellFee.developmentFee = development;
        sellFee.founderFee = founder;
        uint256 totalSellFee = market  + reflection + development + founder;
        require(totalSellFee <= 10, "max sell fee limit is 10%");
        emit SellFeesUpdated (market, reflection, development, founder);
    }

    ///@dev set swap amount after which collected tax should be swappped for ether
    ///@param numTokens: new token amount
    function setSwapTokensAtAmount(uint256 numTokens)  external onlyOwner {
        swapThreshold = numTokens * 1e9;
        emit MinTokensBeforeSwapUpdated(numTokens);
    }


    ///@dev claim stucked tokens from contract
    ///@param _token: token address to be rescued
    function claimStuckTokens(address _token) external onlyOwner {
        require(_token != address(0), "Invalid token address");
        require(_token != address(this), "Can't claim native token");
        IERC20 erc20token = IERC20(_token);
        uint256 balance = erc20token.balanceOf(address(this));
        erc20token.transfer(owner(), balance);
        emit TokensClaimed(_token, balance);
    }

    ///@dev owner can claim any stucked BNB from contract
    function claimBNB() external onlyOwner {
        (bool sent,) = owner().call{value: address(this).balance}("");
        require (sent, "bnb transfer failed");
        emit BNBClaimed (address(this).balance);
    }

    //to recieve ETH from uniswapV2Router when swaping
    receive() external payable {
        this;
    }

    /**
     * @dev Internal function that handles how the fees are stored and reflected.
     * This method is called after fees are calculated and is used to reduce the total reflected amount and fee total.
     *
     * @param rFee The reflection fee amount in RType.
     * @param tFee The fee amount in TokenType.
     */
    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal.sub(rFee);
        _tFeeTotal = _tFeeTotal.add(tFee);
    }

    /**
     * @dev Internal function to calculate reflection values.
     * @param tAmount The total amount of tokens.
     * @param tFee The total fee.
     * @param tMarketing The marketing fee.
     * @param tDevelopment The development fee.
     * @param tFounder The founder fee.
     * @param currentRate The current rate of token.
     * @return rAmount The calculated reflection amount.
     * @return rTransferAmount The calculated transfer reflection amount.
     * @return rFee The calculated reflection fee.
     */
    function _getValues(uint256 tAmount)
    private
    view
    returns (
        uint256,
        uint256,
        uint256,
        uint256,
        uint256,
        uint256
    )
    {
        (
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tMarketing,
            uint256 tDevelopment,
            uint256 tFounder
        ) = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(
            tAmount,
            tFee,
            tMarketing,
            tDevelopment,
            tFounder,
            _getRate()
        );
        return (
            rAmount,
            rTransferAmount,
            rFee,
            tTransferAmount,
            tFee,
            tMarketing
        );
    }

    function _getTValues(uint256 tAmount)
    private
    view
    returns (
        uint256,
        uint256,
        uint256,
        uint256,
        uint256
    )
    {
        uint256 tFee = calculateReflectionFee(tAmount);
        uint256 tMarketing = calculateMarketingFee(tAmount);
        uint256 tDevelopment = calculateDevelopmentFee(tAmount);
        uint256 tFounder = calculateFounderFee(tAmount);
        uint256 tTransferAmount = tAmount.sub(tFee).sub(tMarketing);
        tTransferAmount = tTransferAmount.sub(tDevelopment).sub(tFounder);
        return (tTransferAmount, tFee, tMarketing, tDevelopment, tFounder);
    }

    function _getRValues(
        uint256 tAmount,
        uint256 tFee,
        uint256 tMarketing,
        uint256 tDevelopment,
        uint256 tFounder,
        uint256 currentRate
    )
    private
    pure
    returns (
        uint256,
        uint256,
        uint256
    )
    {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rFee = tFee.mul(currentRate);
        uint256 rMarketing = tMarketing.mul(currentRate);
        uint256 rDevelopment = tDevelopment.mul(currentRate);
        uint256 rFounder = tFounder.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rFee).sub(rMarketing).sub(
            rDevelopment).sub(rFounder);
        return (rAmount, rTransferAmount, rFee);
    }

    /**
     * @dev Internal function that handles the transfer of fees to the contract address.
     * This method is called before fees are distributed and is used to store the fees in this contract.
     *
     * @param tMarketing The marketing fee amount in TokenType.
     * @param tDevelopment The development fee amount in TokenType.
     * @param tFounder The founder fee amount in TokenType.
     */
    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }

    /**
     * @dev Internal function that handles the transfer of fees to the contract address.
     * This method is called before fees are distributed and is used to store the fees in this contract.
     *
     * @param tMarketing The marketing fee amount in TokenType.
     * @param tDevelopment The development fee amount in TokenType.
     * @param tFounder The founder fee amount in TokenType.
     */
    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (
                _rOwned[_excluded[i]] > rSupply ||
                _tOwned[_excluded[i]] > tSupply
            ) return (_rTotal, _tTotal);
            rSupply = rSupply.sub(_rOwned[_excluded[i]]);
            tSupply = tSupply.sub(_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal.div(_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    /**
     * @dev Internal function that handles how the marketing fee is taken from the transaction.
     * This is necessary to ensure the marketing wallet receives the correct number of tokens.
     * @param tMarketing The number of tokens to be taken as marketing fee from the transaction.
     */
    function _takeMarketing(uint256 tMarketing) private {
        uint256 currentRate = _getRate();
        uint256 rMarketing = tMarketing.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rMarketing);
        if (_isExcluded[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)].add(tMarketing);

    }

    /**
     * @dev Internal function to handle the collection of development fees during transactions.
     * The collected development fees are added to the contract's balance.
     * @param tDevelopment The amount of tokens to be collected as development fees.
     */
    function _takeDevelopment(uint256 tDevelopment) private {
        uint256 currentRate = _getRate();
        uint256 rDevelopment = tDevelopment.mul(currentRate);

        _rOwned[address(this)] = _rOwned[address(this)].add(rDevelopment);
        if (_isExcluded[address(this)]) {
            _tOwned[address(this)] = _tOwned[address(this)].add(tDevelopment);
        }
    }

    function _takeFounder(uint256 tFounder) private {
        uint256 currentRate = _getRate();
        uint256 rFounder = tFounder.mul(currentRate);

        _rOwned[address(this)] = _rOwned[address(this)].add(rFounder);
        if (_isExcluded[address(this)]) {
            _tOwned[address(this)] = _tOwned[address(this)].add(tFounder);
        }
    }

    ///@notice enabled trading globally,
    ///can be called once and can never be turned off.
    function enableTrading () external onlyOwner {
        require (!isTradingEnabled, "trading is already live");
        isTradingEnabled = true;

    }

    ///@dev Calculates the reflection fee for a given amount.
    /// @param _amount The amount to calculate the reflection fee for.
    /// @return The calculated reflection fee.
    function calculateReflectionFee(uint256 _amount) private view returns (uint256) {
        return _amount.mul(_reflectionFee).div(10**2);
    }

    ///@dev Calculates the Marketing fee for a given amount.
    /// @param _amount The amount to calculate the marketing fee for.
    /// @return The calculated marketing fee.
    function calculateMarketingFee(uint256 _amount)
    private
    view
    returns (uint256)
    {
        return _amount.mul(_marketingFee).div(10**2);
    }

    ///@dev Calculates the Development fee for a given amount.
    /// @param _amount The amount to calculate the development fee for.
    /// @return The calculated development fee.
    function calculateDevelopmentFee(uint256 _amount)
    private
    view
    returns (uint256)
    {
        return _amount.mul(_developmentFee).div(10**2);
    }


    ///@dev Calculates the founder fee for a given amount.
    /// @param _amount The amount to calculate the founder fee for.
    /// @return The calculated founder fee.
    function calculateFounderFee(uint256 _amount) private view returns (uint256){
        return _amount.mul(_founderFee).div(10**2);
    }

    /**
     * @dev Internal function to reflect the transaction fee. This is done by reducing the total reflected supply (_rTotal) and increasing
     * the total fee (_tFeeTotal) by the amount of the reflected fee.
     * @param rFee The amount of the reflected fee.
     * @param tFee The amount of the fee.
     */
    function removeAllFee() private {
        _reflectionFee = 0;
        _marketingFee = 0;
        _developmentFee = 0;
        _founderFee = 0;
    }

    /**
     * @dev Sets the fees for buy transactions.
     * The fees are set according to the `buyFee` struct values.
     * This function is called in the `_tokenTransfer()` function when a buy transaction is detected.
     */
    function setBuy() private {
        _reflectionFee = buyFee.reflectionFee;
        _marketingFee = buyFee.marketingFee;
        _developmentFee = buyFee.developmentFee;
        _founderFee = buyFee.founderFee;
    }

    /**
     * @dev This function sets the fees for selling transactions.
     * It is called whenever a sell is happening. The fees are set according to the sellFee structure.
     * The fees include reflectionFee, marketingFee, developmentFee and founderFee.
     * These fees are used to distribute rewards, cover operational costs, etc.
     */
    function setSell() private {
        _reflectionFee = sellFee.reflectionFee;
        _marketingFee = sellFee.marketingFee;
        _developmentFee = sellFee.developmentFee;
        _founderFee = sellFee.founderFee;
    }

    /**
     * @dev Function to check if an address is excluded from fee
     * @param account Address of the account to check
     * @return bool indicating whether the account is excluded from fee
     */
    function isExcludedFromFee(address account) public view returns (bool) {
        return _isExcludedFromFee[account];
    }

    /**
     * @dev Toggles the state of the swap and liquify feature of the contract.
     * When `swapAndLiquifyEnabled` is true, the contract will automatically swap and liquify tokens.
     * This is beneficial as it automatically adds liquidity and stabilizes the token price.
     * When `swapAndLiquifyEnabled` is false, the contract will not swap and liquify tokens.
     * This function can only be called by the owner of the contract.
     */
    function toggleSwapAndLiquify() external onlyOwner {
        swapAndLiquifyEnabled = !swapAndLiquifyEnabled;
    }

    /**
     * @dev Internal function that sets the approval amount for a given spender. `approve` and `increaseAllowance`
     * call this function to update the spender's allowance. It emits an `Approval` event.
     * @param tokenOwner The address of the token owner.
     * @param spender The address of the spender.
     * @param amount The amount of allowance.
     */
    function _approve(
        address tokenOwner,
        address spender,
        uint256 amount
    ) private {
        require(tokenOwner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[tokenOwner][spender] = amount;
        emit Approval(tokenOwner, spender, amount);
    }

    /**
     * @dev A private function to handle token transfers. It contains conditions to check whether the transfer is to or from an excluded account,
     * whether it's a buy or sell operation and whether the max wallet limit has been exceeded.
     * @param from The account to transfer tokens from.
     * @param to The account to transfer tokens to.
     * @param amount The amount of tokens to transfer.
     */
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");

        if(from != owner() && to != owner()){
            require(isTradingEnabled, "Trading is not enabled yet");
        }

        if(from != owner() || from != presaleAddress){
            require (isTradingEnabled, "trading is not live");
        }

        // is the token balance of this contract address over the min number of
        // tokens that we need to initiate a swap + liquidity lock?
        // also, don't get caught in a circular liquidity event.
        // also, don't swap & liquify if sender is uniswap pair.
        uint256 contractTokenBalance = balanceOf(address(this));

        bool overMinTokenBalance = contractTokenBalance >=
                    swapThreshold;
        if (
            overMinTokenBalance &&
            !inSwapAndLiquify &&
            from != uniswapV2Pair &&
            swapAndLiquifyEnabled
        ) {

            swapAndLiquify(contractTokenBalance);
        }

        //indicates if fee should be deducted from transfer
        bool takeFee = true;

        //if any account belongs to _isExcludedFromFee account then remove the fee
        if (_isExcludedFromFee[from] || _isExcludedFromFee[to]) {
            takeFee = false;
        }

        //transfer amount, it will take reflection, liquidity fee
        _tokenTransfer(from, to, amount, takeFee);
    }

    /**
     * @dev Swaps and liquifies tokens whenever it reaches the threshold.
     * This function is used to automatically add liquidity and balance the price impact of large sales.
     * It swaps half of the tokens for BNB, then pairs it with the remaining half to add as a liquidity pair on PancakeSwap.
     * @param tokens The number of tokens to be swapped and liquified.
     */
    function swapAndLiquify(uint256 tokens) private lockTheSwap {
        uint256 oldBalance = address(this).balance;
        // swap tokens for ETH
        swapTokensForEth(tokens);
        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance.sub(oldBalance);
        uint256 divisor = buyFee.marketingFee + buyFee.developmentFee + buyFee.founderFee
            + sellFee.marketingFee + sellFee.developmentFee + sellFee.founderFee;

        uint256 marketingShare = newBalance.mul(buyFee.marketingFee + sellFee.marketingFee).div(divisor);
        uint256 developmentShare = newBalance.mul(buyFee.developmentFee + sellFee.developmentFee).div(divisor);
        (bool sent,) = marketingWallet.call{value: marketingShare}("");
        require(sent,"bnb transfer to marketing wallet failed");
        (bool sent1,) = developmentWallet.call{value: developmentShare}("");
        require(sent1,"bnb transfer to development wallet failed");
        (bool sent2,) = founderWallet.call{value: address(this).balance}("");
        require(sent2,"bnb transfer to founder wallet failed");

        emit SwapAndLiquify(tokens, newBalance);
    }

    /**
     * @dev Swaps tokens for BNB. This function is used for the swapAndLiquify function.
     * @param tokenAmount The number of tokens to be swapped.
     */
    function swapTokensForEth(uint256 tokenAmount) private {
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of BNB
            path,
            address(this),
            block.timestamp
        );
    }

    /**
     * @dev Swaps BNB for tokens which are then sent to a burn address to reduce supply.
     * This function is only callable by the contract owner.
     * @param bnbAmount The amount of BNB to swap for tokens.
     */
    function swapBNBforTokens (uint256 bnbAmount) private {
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = address(this);

        // make the swap
        uniswapV2Router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: bnbAmount}(
            0, // accept any amount of tokens
            path,
            address(0xdead),
            block.timestamp
        );
    }

    /**
     * @dev Updates the addresses of the fee wallets
     * @param marketing The new address for the marketing wallet
     * @param founder The new address for the founder wallet
     * @param development The new address for the development wallet
     *
     * Emits a `Transfer` event.
     *
     * Requirements:
     * - `marketing` must not be the zero address.
     * - `founder` must not be the zero address.
     * - `development` must not be the zero address.
     */
    function updateWallets (address marketing, address founder, address development) external onlyOwner {
        //zero address is not allowed
        require (marketing != address(0) && founder != address(0) && development != address(0), "error zero address");
        marketingWallet = marketing;
        founderWallet = founder;
        developmentWallet = development;

    }

    /**
     * @dev Allows the owner to buy tokens using BNB and send them to the 0xdead address (burn address).
     * This function is used to decrease the supply of tokens in circulation, effectively increasing the value of remaining tokens.
     * The amount of BNB used for the buyback is the amount of BNB sent to the contract by the owner.
     */
    function buybackAndBurn () public payable onlyOwner {
        swapBNBforTokens(msg.value);
    }

    /**
     * @dev Internal function that transfers the token from a sender to a recipient.
     * It can also conditionally apply fees to the transfer.
     * @param sender address: the sender address.
     * @param recipient address: the recipient address.
     * @param amount uint256: the amount of tokens to transfer.
     * @param takeFee bool: whether to apply fees to this transfer.
     */
    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        removeAllFee();

        if (takeFee) {
            if(isPinkBotEnabled){
                pinkAntiBot.onPreTransferCheck(sender, recipient, amount);
            }

            if (sender == uniswapV2Pair) {
                setBuy();

            }
            if (recipient == uniswapV2Pair) {
                setSell();
            }

            if( recipient != uniswapV2Pair){
                require (balanceOf(recipient) + amount <= maxWallet, "max wallet limit exceed");

            }
        }

        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferStandard(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }
    }

    /**
     * @dev Standard transfer function called during a transaction.
     * Takes care of calculating values, updating balances and reflecting fees.
     *
     * @param sender - address initiating the transaction
     * @param recipient - address receiving the tokens
     * @param tAmount - amount of tokens being transferred
     */
    function _transferStandard(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tMarketing
        ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeMarketing(tMarketing);
        _takeDevelopment(calculateDevelopmentFee(tAmount));
        _takeFounder(calculateFounderFee(tAmount));
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    /**
     * @dev Transfer tokens from a non-excluded account to an excluded account, taking into account the reflection mechanism.
     * The sender's balance is reduced by the reflection amount of the tokens being sent.
     * The recipient's excluded balance is increased by the actual token amount.
     * The recipient's reflected balance is increased by the reflection amount of the tokens being sent.
     * Marketing, development and founder fees are taken from the transaction.
     * The total fees and reflection fees are reflected.
     * A Transfer event is emitted with the details of the transfer.
     *
     * @param sender The address of the account sending the tokens.
     * @param recipient The address of the account receiving the tokens.
     * @param tAmount The amount of tokens being sent.
     */
    function _transferToExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tMarketing
        ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeMarketing(tMarketing);
        _takeDevelopment(calculateDevelopmentFee(tAmount));
        _takeFounder(calculateFounderFee(tAmount));

        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    /**
     * @dev Transfers tokens from an excluded address to another address.
     * The function calculates the necessary values using the _getValues function,
     * reduces the sender's balance, updates the recipient's balance, takes the necessary fees,
     * reflects the fee, and emits a Transfer event.
     *
     * Requirements:
     * - `sender` must be an excluded address.
     * - `recipient` must not be the zero address.
     * - `tAmount` must be less than or equal to the `sender`'s token balance.
     *
     * @param sender the address to transfer from.
     * @param recipient the address to transfer to.
     * @param tAmount the amount of tokens to be transferred.
     */
    function _transferFromExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tMarketing
        ) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeMarketing(tMarketing);
        _takeDevelopment(calculateDevelopmentFee(tAmount));
        _takeFounder(calculateFounderFee(tAmount));

        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    /**
     * @notice This function handles transfers between two addresses that are both excluded from fees.
     * @param sender The address initiating the transfer.
     * @param recipient The address receiving the transfer.
     * @param tAmount The amount of tokens to be transferred.
     */
    function _transferBothExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tMarketing
        ) = _getValues(tAmount);
        _tOwned[sender] = _tOwned[sender].sub(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _tOwned[recipient] = _tOwned[recipient].add(tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _takeMarketing(tMarketing);
        _takeDevelopment(calculateDevelopmentFee(tAmount));
        _takeFounder(calculateFounderFee(tAmount));

        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
    }
}
