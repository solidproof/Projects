//SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

interface IDEXFactory {
    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
}

interface IDEXRouter {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface IERC20 {
    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `to`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address to, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `from` to `to` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}

contract Waygate is
    Initializable,
    ERC20Upgradeable,
    OwnableUpgradeable,
    PausableUpgradeable
{
    uint256 constant NUMERATOR = 1000;
    uint256 public taxRate;
    uint256 public tokensTXLimit;

    IDEXRouter _dexRouter;
    address public dexRouterAddress;
    address public _dexPair;

    mapping(address => uint256) burnWalletPercent;
    mapping(address => uint256) liquidityWalletPercent;
    mapping(address => uint256) developmentWalletPercent;
    mapping(address => uint256) marketingWalletPercent;
    mapping(address => uint256) partnershipWalletPercent;
    mapping(address => bool) public blacklisted;
    mapping(address => bool) public isExemptedFromTax;
    mapping(address => bool) public isDistributorAddress;

    address public BURN_WALLET;
    address public LIQUIDITY_WALLET;
    address public DEVELOPMENT_WALLET;
    address public MARKETING_WALLET;
    address public PARTNERSHIP_WALLET;

    uint256 public MAX_WALLET_SIZE;
    bool public isTradingEnabled;

    event TaxReceiversUpdated(
        address BURN_WALLET,
        uint256 burnWalletPercent,
        address LIQUIDITY_WALLET,
        uint256 liquidityWalletPercent,
        address DEVELOPMENT_WALLET,
        uint256 developmentWalletPercent,
        address MARKETING_WALLET,
        uint256 marketingWalletPercent,
        address PARTNERSHIP_WALLET,
        uint256 partnershipWalletPercent
    );
    event TradingStatusChanged(bool TradeStatus);
    event WalletTokensLimitUpdated(uint256 WalletTokenTxLimit);
    event TokensTXLimit(uint256 TokensLimit);
    event BlacklistStatusUpdated(address Address, bool Status);
    event TaxRateSet(uint256 TaxRate);

    modifier isNotBlacklisted(address _address) {
        require(!blacklisted[_address], "Address has been Blocklisted");
        _;
    }
    modifier onlyDistributor() {
        require(isDistributorAddress[_msgSender()], "Not a Distributor");
        _;
    }

    function initialize(
        string memory _tokenName,
        string memory _tokenSymbol,
        uint256 _totalSupply,
        uint256 _taxRate,
        address admin
    ) external initializer {
        require(_taxRate <= 200, "Taxable: Tax cannot be greater than 20%");

        __ERC20_init(_tokenName, _tokenSymbol);
        __Ownable_init();
        __Pausable_init();
        _mint(admin, _totalSupply);
        taxRate = _taxRate;
        _dexRouter = IDEXRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D); // ETH: Uniswap V2 Router
        dexRouterAddress = address(_dexRouter);

        //create pair
        _dexPair = IDEXFactory(_dexRouter.factory()).createPair(
            address(this),
            _dexRouter.WETH()
        );
        IERC20(_dexPair).approve(address(_dexRouter), type(uint256).max);
    }

    function enableTrading() public onlyOwner {
        isTradingEnabled = true;
        emit TradingStatusChanged(true);
    }

    function disableTrading() public onlyOwner {
        isTradingEnabled = false;
        emit TradingStatusChanged(false);
    }

    function addToBlacklist(address _address) external onlyOwner {
        if (
            (_address != _dexPair) &&
            (_address != address(_dexRouter)) &&
            (_address != address(this))
        ) blacklisted[_address] = true;
        emit BlacklistStatusUpdated(_address, true);
    }

    function removeFromBlacklist(address _address) external onlyOwner {
        blacklisted[_address] = false;
        emit BlacklistStatusUpdated(_address, false);
    }

    function addTaxExemptedAddress(address _exemptedAddress) public onlyOwner {
        isExemptedFromTax[_exemptedAddress] = true;
    }

    function addTaxDistributor(address _distributorAddress) public onlyOwner {
        isDistributorAddress[_distributorAddress] = true;
    }

    function removeTaxDistributor(address _distributorAddress)
        public
        onlyOwner
    {
        isDistributorAddress[_distributorAddress] = false;
    }

    function removeTaxExemptedAddress(address _exemptedAddress)
        public
        onlyOwner
    {
        isExemptedFromTax[_exemptedAddress] = false;
    }

    function setMaxWalletSize(uint256 _maxWalletSize) external onlyOwner {
        MAX_WALLET_SIZE = _maxWalletSize;
        emit WalletTokensLimitUpdated(MAX_WALLET_SIZE);
    }

    function setTaxRate(uint256 _taxRate) public onlyOwner whenNotPaused {
        require(_taxRate < NUMERATOR, "Taxable: Tax rate too high");
        require(_taxRate <= 200, "Taxable: Tax cannot be greater than 20%");
        taxRate = _taxRate;
        emit TaxRateSet(taxRate);
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function setDexRouterAddress(address _dexRouterAddress) external onlyOwner {
        require(
            _dexRouterAddress != address(0),
            "Invalid Uniswap router address"
        );
        _dexRouter = IDEXRouter(_dexRouterAddress);
        dexRouterAddress = _dexRouterAddress;
    }

    function setDexPairAddress(address _dexPairAddress) external onlyOwner {
        require(
            _dexPairAddress != address(0),
            "Invalid Pair address"
        );
        _dexPair = _dexPairAddress;
    }

    function setTransactionLimit(uint256 _tokensTXLimit)
        public
        onlyOwner
        whenNotPaused
    {
        tokensTXLimit = _tokensTXLimit;
        emit TokensTXLimit(tokensTXLimit);
    }

    function getTransactionLimit() public view returns (uint256) {
        return tokensTXLimit;
    }

    function getTaxRate() public view returns (uint256) {
        return taxRate;
    }

    function setTaxReceivers(
        address _burnWallet,
        uint256 _burnWalletPercent,
        address _liquidityWallet,
        uint256 _liquidityWalletPercent,
        address _developmentWallet,
        uint256 _developmentWalletPercent,
        address _marketingWallet,
        uint256 _marketingWalletPercent,
        address _partnershipWallet,
        uint256 _partnershipWalletPercent
    ) external onlyOwner whenNotPaused {
        require(
            _burnWallet != address(0) &&
                _liquidityWallet != address(0) &&
                _developmentWallet != address(0) &&
                _marketingWallet != address(0) &&
                _partnershipWallet != address(0),
            "Taxable: Tax reciever cannot be zero address"
        );
        require(
            _burnWalletPercent +
                _liquidityWalletPercent +
                _developmentWalletPercent +
                _marketingWalletPercent +
                _partnershipWalletPercent ==
                taxRate,
            "Tax Rate: Percentages Sum must be equal to Tax Rate"
        );
        BURN_WALLET = _burnWallet;
        burnWalletPercent[_burnWallet] = _burnWalletPercent;

        LIQUIDITY_WALLET = _liquidityWallet;
        liquidityWalletPercent[_liquidityWallet] = _liquidityWalletPercent;

        DEVELOPMENT_WALLET = _developmentWallet;
        developmentWalletPercent[
            _developmentWallet
        ] = _developmentWalletPercent;

        MARKETING_WALLET = _marketingWallet;
        marketingWalletPercent[_marketingWallet] = _marketingWalletPercent;

        PARTNERSHIP_WALLET = _partnershipWallet;
        partnershipWalletPercent[
            _partnershipWallet
        ] = _partnershipWalletPercent;
        addTaxExemptedAddress(BURN_WALLET);
        addTaxExemptedAddress(LIQUIDITY_WALLET);
        addTaxExemptedAddress(DEVELOPMENT_WALLET);
        addTaxExemptedAddress(MARKETING_WALLET);
        addTaxExemptedAddress(PARTNERSHIP_WALLET);
        emit TaxReceiversUpdated(
            BURN_WALLET,
            burnWalletPercent[BURN_WALLET],
            LIQUIDITY_WALLET,
            liquidityWalletPercent[LIQUIDITY_WALLET],
            DEVELOPMENT_WALLET,
            developmentWalletPercent[DEVELOPMENT_WALLET],
            MARKETING_WALLET,
            marketingWalletPercent[MARKETING_WALLET],
            PARTNERSHIP_WALLET,
            partnershipWalletPercent[PARTNERSHIP_WALLET]
        );
    }

    function getTaxRecievers()
        public
        view
        returns (
            address _BURN_WALLET,
            uint256 _BURN_WALLET_PERCENTAGE,
            address _LIQUIDITY_WALLET,
            uint256 _LIQUIDITY_WALLET_PERCENTAGE,
            address _DEVELOPMENT_WALLET,
            uint256 _DEVELOPMENT_WALLET_PERCENTAGE,
            address _MARKETING_WALLET,
            uint256 _MARKETING_WALLET_PERCENTAGE,
            address _PARTNERSHIP_WALLET,
            uint256 _PARTNERSHIP_WALLET_PERCENTAGE
        )
    {
        return (
            BURN_WALLET,
            burnWalletPercent[BURN_WALLET],
            LIQUIDITY_WALLET,
            liquidityWalletPercent[LIQUIDITY_WALLET],
            DEVELOPMENT_WALLET,
            developmentWalletPercent[DEVELOPMENT_WALLET],
            MARKETING_WALLET,
            marketingWalletPercent[MARKETING_WALLET],
            PARTNERSHIP_WALLET,
            partnershipWalletPercent[PARTNERSHIP_WALLET]
        );
    }

    function getContractETHBalance() public view returns (uint256) {
        return address(this).balance;
    }

    fallback() external payable {}

    receive() external payable {}

    function distributeTax() public onlyDistributor {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = _dexRouter.WETH();

        uint256 contractWayBalance = balanceOf(address(this)); //WAY Balance
        uint256 initialBalance = address(this).balance; //eth balance
        this.approve(address(_dexRouter), contractWayBalance);
        _dexRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            contractWayBalance,
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 ethAmount = address(this).balance - initialBalance;
        uint256 totalTaxRate = (ethAmount * 10) / taxRate;

        uint256 burnFee = (totalTaxRate * burnWalletPercent[BURN_WALLET]) / 10;
        uint256 liquidityFee = (totalTaxRate *
            liquidityWalletPercent[LIQUIDITY_WALLET]) / 10;
        uint256 developmentFee = (totalTaxRate *
            developmentWalletPercent[DEVELOPMENT_WALLET]) / 10;
        uint256 marketingFee = (totalTaxRate *
            marketingWalletPercent[MARKETING_WALLET]) / 10;
        uint256 partnershipFee = (totalTaxRate *
            partnershipWalletPercent[PARTNERSHIP_WALLET]) / 10;

        // Transfer fees to respective wallets
        payable(BURN_WALLET).transfer(burnFee);
        payable(LIQUIDITY_WALLET).transfer(liquidityFee);
        payable(DEVELOPMENT_WALLET).transfer(developmentFee);
        payable(MARKETING_WALLET).transfer(marketingFee);
        payable(PARTNERSHIP_WALLET).transfer(partnershipFee);
    }

    function transfer(address to, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(_msgSender(), to, amount);
        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) public override returns (bool) {
        _transfer(from, to, amount);
        _approve(from, _msgSender(), allowance(from, _msgSender()) - amount);
        return true;
    }

    bool public _transferFlag;

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override isNotBlacklisted(from) isNotBlacklisted(to) {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");

        require(
            amount <= tokensTXLimit,
            "TX Limit: Cannot transfer more than tokensTXLimit"
        );
        //While Trading
        // user wantes: eth => token --> BUY
        if (
            from == _dexPair &&
            !isExemptedFromTax[to] &&
            to != address(_dexRouter)
        ) {
            require(isTradingEnabled, "Trading is not enabled");
            uint256 amountOfTax = (amount * taxRate) / NUMERATOR;
            super._transfer(from, address(this), amountOfTax);
            super._transfer(from, to, amount - amountOfTax);
        }
        // users wants token => eth or adding Liquidity --> SELL
        else if (
            to == _dexPair &&
            !isExemptedFromTax[from] &&
            from != address(_dexRouter)
        ) {
            uint256 amountOfTax = (amount * taxRate) / NUMERATOR;

            super._transfer(from, address(this), amountOfTax);
            super._transfer(from, to, amount - amountOfTax);
        } else {
            super._transfer(from, to, amount);
        }
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    )
        internal
        view
        override
        whenNotPaused
        isNotBlacklisted(from)
        isNotBlacklisted(to)
    {}

    function burn(uint256 amount) public onlyOwner {
        _burn(msg.sender, amount);
    }
}
