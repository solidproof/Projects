// SPDX-License-Identifier: MIT
pragma solidity ^0.8.11;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "./IPancakeRouter02.sol";
import "./IPancakePair.sol";
import "./IPancakeFactory.sol";
interface ITreasury {   
    function depositReward(uint256 amount) external returns (uint256) ;
}
contract Dogeliens is Initializable, IERC20Upgradeable, OwnableUpgradeable {
    uint8 _decimals;
    mapping(address => bool) public bots;
    address public treasuryAddress; // treasury CA
    bool public isTreasuryContract;
    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcluded;
    address[] private _excluded;
    uint256 private constant MAX = ~uint256(0);
    uint256 private _tTotal;
    uint256 private _rTotal;
    uint256 private _tFeeTotal;
    string private _name;
    string private _symbol;

    uint256 private _rewardFee;
    uint256 private _previousRewardFee;

    uint256 private _liquidityFee;
    uint256 private _previousLiquidityFee;

    uint256 private _charityFee;
    uint256 private _previousCharityFee;

    uint256 private _treasuryFee;
    uint256 private _previousTreasuryFee;
    bool inSwapAndLiquify;
    uint16 public sellRewardFee;
    uint16 public buyRewardFee;
    uint16 public sellLiquidityFee;
    uint16 public buyLiquidityFee;

    uint16 public sellCharityFee;
    uint16 public buyCharityFee;

    uint16 public sellTreasuryFee;
    uint16 public buyTreasuryFee;

    address public lpWallet;
    address public charityWallet;
    bool public isCharityFeeNativeToken;

    uint256 public maxTransactionAmount;
    uint256 public maxWalletAmount;
    uint256 public minAmountToTakeFee;

    bool public swapAndLiquifyEnabled;
    bool public transferDelayEnabled;
    bool public gasPriceLimitActivated;
    bool public tradingActive;
    bool public limitsInTrade;
    mapping(address => uint256) private _holderLastTransferTimestamp; // to hold last Transfers temporarily during launch

    uint256 private _gasPriceLimit;
    IPancakeRouter02 public mainRouter;
    address public mainPair;

    mapping(address => bool) public isExcludedFromFee;
    mapping(address => bool) public isExcludedMaxTransactionAmount;
    mapping(address => bool) public automatedMarketMakerPairs;

    uint256 private _liquidityFeeTokens;
    uint256 private _charityFeeTokens;
    uint256 private _treasuryFeeTokens;
    event UpdateTreasuryAddress(address treasuryAddress, bool isTreasuryContract);
    event LogAddBots(address[] indexed bots);
    event LogRemoveBots(address[] indexed notbots);
    event UpdateLiquidityFee(uint16 sellLiquidityFee, uint16 buyLiquidityFee);
    event UpdateCharityFee(uint16 sellCharityFee, uint16 buyCharityFee);
    event UpdateRewardFee(uint16 sellRewardFee, uint16 buyRewardFee);
    event UpdateTreasuryFee(uint16 sellTreasuryFee, uint16 buyTreasuryFee);
    event UpdateLPWallet(address lpWallet);
    event UpdateCharityWallet(
        address charityWallet,
        bool isCharityFeeNativeToken
    );
    event UpdateMaxTransactionAmount(uint256 maxTransactionAmount);
    event UpdateMaxWalletAmount(uint256 maxWalletAmount);
    event UpdateMinAmountToTakeFee(uint256 minAmountToTakeFee);
    event SetAutomatedMarketMakerPair(address pair, bool value);
    event ExcludedMaxTransactionAmount(address updAds, bool isEx);
    event ExcludedFromFee(address account, bool isEx);
    event SwapAndLiquify(uint256 tokensForLiquidity, uint256 bnbForLiquidity);
    event CharityFeeTaken(
        uint256 charityFeeTokens,
        uint256 charityFeeBNBSwapped
    );
    event TreasuryFeeTaken(uint256 treasuryFeeTokens);
    event TradingActivated();
    event Reflect(uint256 amount);

    function initialize(
        string memory __name,
        string memory __symbol,
        uint8 __decimals,
        uint256 _totalSupply,
        address[4] memory _accounts,
        bool _isCharityFeeNativeToken,
        uint16[8] memory _fees,
        uint256[3] memory _amountLimits
    ) public initializer {
        __Ownable_init();
        _decimals = __decimals;
        _name = __name;
        _symbol = __symbol;
        _tTotal = _totalSupply * (10**_decimals);
        _rTotal = (MAX - (MAX % _tTotal));
        _rOwned[_msgSender()] = _rTotal;
        _gasPriceLimit = _amountLimits[2] * 1 gwei;
        require(_accounts[0] != address(0), "charity wallet can not be 0");
        require(_accounts[2] != address(0), "Router address can not be 0");

        require(_amountLimits[0] <= _totalSupply);
        require(_amountLimits[0] > 0);
        require(_amountLimits[1] <= _totalSupply);
        require(_amountLimits[1] > 0);

        charityWallet = _accounts[0];
        lpWallet = _accounts[1];
        mainRouter = IPancakeRouter02(_accounts[2]);
        treasuryAddress = _accounts[3];
        mainPair = IPancakeFactory(mainRouter.factory()).createPair(
            address(this),
            mainRouter.WETH()
        );
        isCharityFeeNativeToken = _isCharityFeeNativeToken;
        sellLiquidityFee = _fees[0];
        buyLiquidityFee = _fees[1];
        sellCharityFee = _fees[2];
        buyCharityFee = _fees[3];
        sellRewardFee = _fees[4];
        buyRewardFee = _fees[5];
        sellTreasuryFee = _fees[6];
        buyTreasuryFee = _fees[7];
        require(
            sellLiquidityFee + sellCharityFee + sellRewardFee + sellTreasuryFee <=
                300
        );
        require(
            buyLiquidityFee + buyCharityFee + buyRewardFee + buyTreasuryFee <= 300
        );
        maxTransactionAmount = _amountLimits[0] * (10**_decimals);
        maxWalletAmount = _amountLimits[1] * (10**_decimals);
        minAmountToTakeFee = (_totalSupply * (10**_decimals)) / 10000;

        excludeFromReward(address(0xdead));
        excludeFromReward(address(this));
        excludeFromReward(treasuryAddress);
        isExcludedFromFee[address(this)] = true;
        isExcludedFromFee[treasuryAddress] = true;
        isExcludedFromFee[charityWallet] = true;
        isExcludedFromFee[_msgSender()] = true;
        isExcludedFromFee[address(0xdead)] = true;
        isExcludedMaxTransactionAmount[_msgSender()] = true;
        isExcludedMaxTransactionAmount[address(this)] = true;
        isExcludedMaxTransactionAmount[address(0xdead)] = true;
        isExcludedMaxTransactionAmount[charityWallet] = true;
        isExcludedMaxTransactionAmount[treasuryAddress] = true;
        _setAutomatedMarketMakerPair(mainPair, true);
        emit Transfer(address(0), msg.sender, _tTotal);
    }

    function updateTreasuryAddress(address _treasuryAddress, bool _isTreasuryContract) external onlyOwner {
        treasuryAddress = _treasuryAddress;
        isExcludedFromFee[_treasuryAddress] = true;
        excludeFromMaxTransaction(_treasuryAddress, true);
        isTreasuryContract=_isTreasuryContract;
        excludeFromReward(treasuryAddress);
        emit UpdateTreasuryAddress(_treasuryAddress, _isTreasuryContract);
    }


    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) private {
        if (_isExcluded[sender] && !_isExcluded[recipient]) {
            _transferFromExcluded(sender, recipient, amount);
        } else if (!_isExcluded[sender] && _isExcluded[recipient]) {
            _transferToExcluded(sender, recipient, amount);
        } else if (_isExcluded[sender] && _isExcluded[recipient]) {
            _transferBothExcluded(sender, recipient, amount);
        } else {
            _transferStandard(sender, recipient, amount);
        }
    }

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
            uint256 tLiquidity,
            uint256 tCharity,
            uint256 tTreasury
        ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _rOwned[recipient] = _rOwned[recipient] + (rTransferAmount);
        if (tLiquidity > 0 || tCharity > 0 || tTreasury > 0) {
            _takeLiquidity(tLiquidity, tCharity, tTreasury);
        }
        if (tFee > 0) {
            _reflectFee(rFee, tFee);
            emit Reflect(tFee);
        }
        emit Transfer(sender, recipient, tTransferAmount);
    }

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
            uint256 tLiquidity,
            uint256 tCharity,
            uint256 tTreasury
        ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _tOwned[recipient] = _tOwned[recipient] + tTransferAmount;
        _rOwned[recipient] = _rOwned[recipient] + (rTransferAmount);
        if (tLiquidity > 0 || tCharity > 0 || tTreasury > 0) {
            _takeLiquidity(tLiquidity, tCharity, tTreasury);
        }
        if (tFee > 0) {
            _reflectFee(rFee, tFee);
            emit Reflect(tFee);
        }
        emit Transfer(sender, recipient, tTransferAmount);
    }

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
            uint256 tLiquidity,
            uint256 tCharity,
            uint256 tTreasury
        ) = _getValues(tAmount);

        _rOwned[sender] = _rOwned[sender] - rAmount;
        _tOwned[sender] = _tOwned[sender] - tAmount;
        _rOwned[recipient] = _rOwned[recipient] + (rTransferAmount);
        if (tLiquidity > 0 || tCharity > 0 || tTreasury > 0) {
            _takeLiquidity(tLiquidity, tCharity, tTreasury);
        }
        if (tFee > 0) {
            _reflectFee(rFee, tFee);
            emit Reflect(tFee);
        }
        emit Transfer(sender, recipient, tTransferAmount);
    }

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
            uint256 tLiquidity,
            uint256 tCharity,
            uint256 tTreasury
        ) = _getValues(tAmount);
        _rOwned[sender] = _rOwned[sender] - rAmount;
        _tOwned[sender] = _tOwned[sender] - tAmount;
        _tOwned[recipient] = _tOwned[recipient] + tTransferAmount;
        _rOwned[recipient] = _rOwned[recipient] + (rTransferAmount);
        if (tLiquidity > 0 || tCharity > 0 || tTreasury > 0) {
            _takeLiquidity(tLiquidity, tCharity, tTreasury);
        }
        if (tFee > 0) {
            _reflectFee(rFee, tFee);
            emit Reflect(tFee);
        }
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal - (rFee);
        _tFeeTotal = _tFeeTotal + (tFee);
    }

    function _getValues(uint256 tAmount)
        private
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        uint256[5] memory tAmounts = _getTValues(tAmount);
        (uint256 rAmount, uint256 rTransferAmount, uint256 rFee) = _getRValues(
            tAmount,
            tAmounts[1],
            tAmounts[2],
            tAmounts[3],
            tAmounts[4]
        );
        return (
            rAmount,
            rTransferAmount,
            rFee,
            tAmounts[0],
            tAmounts[1],
            tAmounts[2],
            tAmounts[3],
            tAmounts[4]
        );
    }

    function _getTValues(uint256 tAmount)
        private
        view
        returns (
            uint256[5] memory tAmounts
        )
    {
        tAmounts[1] = calculateRewardFee(tAmount);
        tAmounts[2] = calculateLiquidityFee(tAmount);
        tAmounts[3] = calculateCharityFee(tAmount);
        tAmounts[4] = calculateTreasuryFee(tAmount);
        tAmounts[0] = tAmount -
            tAmounts[1] -
            tAmounts[2] -
            tAmounts[3] -
            tAmounts[4];
        return tAmounts;
    }

    function _getRValues(
        uint256 tAmount,
        uint256 tFee,
        uint256 tLiquidity,
        uint256 tCharity,
        uint256 tTreasury
    )
        private
        view
        returns (
            uint256,
            uint256,
            uint256
        )
    {
        uint256 currentRate = _getRate();
        uint256 rAmount = tAmount * currentRate;
        uint256 rFee = tFee * currentRate;
        uint256 rLiquidity = tLiquidity * currentRate;
        uint256 rCharity = tCharity * currentRate;
        uint256 rTreasury = tTreasury * currentRate;
        uint256 rTransferAmount = rAmount -
            rFee -
            rLiquidity -
            rCharity -
            rTreasury;
        return (rAmount, rTransferAmount, rFee);
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply / (tSupply);
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (
                _rOwned[_excluded[i]] > rSupply ||
                _tOwned[_excluded[i]] > tSupply
            ) return (_rTotal, _tTotal);
            rSupply = rSupply - (_rOwned[_excluded[i]]);
            tSupply = tSupply - (_tOwned[_excluded[i]]);
        }
        if (rSupply < _rTotal / (_tTotal)) return (_rTotal, _tTotal);
        return (rSupply, tSupply);
    }

    function removeAllFee() private {
        if (_rewardFee == 0 && _liquidityFee == 0 && _charityFee == 0) return;

        _previousRewardFee = _rewardFee;
        _previousLiquidityFee = _liquidityFee;
        _previousCharityFee = _charityFee;
        _previousTreasuryFee = _treasuryFee;

        _treasuryFee = 0;
        _charityFee = 0;
        _rewardFee = 0;
        _liquidityFee = 0;
    }

    function restoreAllFee() private {
        _rewardFee = _previousRewardFee;
        _liquidityFee = _previousLiquidityFee;
        _charityFee = _previousCharityFee;
        _treasuryFee = _previousTreasuryFee;
    }

    function calculateRewardFee(uint256 _amount)
        private
        view
        returns (uint256)
    {
        return (_amount * (_rewardFee)) / (10**3);
    }

    function calculateLiquidityFee(uint256 _amount)
        private
        view
        returns (uint256)
    {
        return (_amount * (_liquidityFee)) / (10**3);
    }

    function calculateCharityFee(uint256 _amount)
        private
        view
        returns (uint256)
    {
        return (_amount * (_charityFee)) / (10**3);
    }

    function calculateTreasuryFee(uint256 _amount) private view returns (uint256) {
        return (_amount * (_treasuryFee)) / (10**3);
    }

    function _takeLiquidity(
        uint256 tLiquidity,
        uint256 tCharity,
        uint256 tTreasury
    ) private {
        uint256 currentRate = _getRate();
        _liquidityFeeTokens = _liquidityFeeTokens + (tLiquidity);
        _charityFeeTokens = _charityFeeTokens + tCharity;
        _treasuryFeeTokens = _treasuryFeeTokens + tTreasury;
        uint256 tTmp = tLiquidity + tCharity + tTreasury;
        uint256 rTmp = tTmp * currentRate;
        _rOwned[address(this)] = _rOwned[address(this)] + rTmp;
        if (_isExcluded[address(this)])
            _tOwned[address(this)] = _tOwned[address(this)] + tTmp;
    }

    /////////////////////////////////////////////////////////////////////////////////
    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function decimals() external view returns (uint8) {
        return _decimals;
    }

    function totalSupply() external view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(address account) public view override returns (uint256) {
        if (_isExcluded[account]) return _tOwned[account];
        return tokenFromReflection(_rOwned[account]);
    }

    function transfer(address recipient, uint256 amount)
        external
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        external
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()] - amount
        );
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        external
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + (addedValue)
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] - (subtractedValue)
        );
        return true;
    }

    function isExcludedFromReward(address account)
        external
        view
        returns (bool)
    {
        return _isExcluded[account];
    }

    function totalFees() external view returns (uint256) {
        return _tFeeTotal;
    }

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
        return rAmount / (currentRate);
    }

    function excludeFromReward(address account) public onlyOwner {
        require(!_isExcluded[account], "Account is already excluded");
        require(
            _excluded.length + 1 <= 50,
            "Cannot exclude more than 50 accounts.  Include a previously excluded address."
        );
        if (_rOwned[account] > 0) {
            _tOwned[account] = tokenFromReflection(_rOwned[account]);
        }
        _isExcluded[account] = true;
        _excluded.push(account);
    }

    function includeInReward(address account) public onlyOwner {
        require(_isExcluded[account], "Account is not excluded");
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account) {
                uint256 prev_reflection = _rOwned[account];
                _rOwned[account] = _tOwned[account] * _getRate();
                _rTotal = _rTotal + _rOwned[account] - prev_reflection;
                _excluded[i] = _excluded[_excluded.length - 1];
                _isExcluded[account] = false;
                _excluded.pop();
                break;
            }
        }
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    modifier lockTheSwap() {
        inSwapAndLiquify = true;
        _;
        inSwapAndLiquify = false;
    }

    function updateLiquidityFee(
        uint16 _sellLiquidityFee,
        uint16 _buyLiquidityFee
    ) external onlyOwner {
        require(
            _sellLiquidityFee +
                sellCharityFee +
                sellRewardFee +
                sellTreasuryFee <=
                300,
            "sell fee <= 30%"
        );
        require(
            _buyLiquidityFee + buyCharityFee + buyRewardFee + buyTreasuryFee <=
                300,
            "buy fee <= 30%"
        );

        sellLiquidityFee = _sellLiquidityFee;
        buyLiquidityFee = _buyLiquidityFee;
        emit UpdateLiquidityFee(sellLiquidityFee, buyLiquidityFee);
    }

    function updateCharityFee(
        uint16 _sellCharityFee,
        uint16 _buyCharityFee
    ) external onlyOwner {
        require(
            _sellCharityFee +
                sellLiquidityFee +
                sellRewardFee +
                sellTreasuryFee <=
                300,
            "sell fee <= 30%"
        );
        require(
            _buyCharityFee + buyLiquidityFee + buyRewardFee + buyTreasuryFee <=
                300,
            "buy fee <= 30%"
        );
        sellCharityFee = _sellCharityFee;
        buyCharityFee = _buyCharityFee;
        emit UpdateCharityFee(sellCharityFee, buyCharityFee);
    }

    function updateRewardFee(uint16 _sellRewardFee, uint16 _buyRewardFee)
        external
        onlyOwner
    {
        require(
            _sellRewardFee +
                sellLiquidityFee +
                sellCharityFee +
                sellTreasuryFee <=
                300,
            "sell fee <= 30%"
        );
        require(
            _buyRewardFee + buyLiquidityFee + buyCharityFee + buyTreasuryFee <=
                300,
            "buy fee <= 30%"
        );
        sellRewardFee = _sellRewardFee;
        buyRewardFee = _buyRewardFee;
        emit UpdateRewardFee(sellRewardFee, buyRewardFee);
    }

    function updateTreasuryFee(uint16 _sellTreasuryFee, uint16 _buyTreasuryFee)
        external
        onlyOwner
    {
        require(
            _sellTreasuryFee +
                sellLiquidityFee +
                sellRewardFee +
                sellCharityFee <=
                300,
            "sell fee <= 30%"
        );
        require(
            _buyTreasuryFee + buyLiquidityFee + buyRewardFee + buyCharityFee <=
                300,
            "buy fee <= 30%"
        );
        sellTreasuryFee = _sellTreasuryFee;
        buyTreasuryFee = _buyTreasuryFee;
        emit UpdateTreasuryFee(sellTreasuryFee, buyTreasuryFee);
    }

    function updateLPWallet(address _lpWallet) external onlyOwner {
        lpWallet = _lpWallet;
        emit UpdateLPWallet(lpWallet);
    }

    function updateCharityWallet(
        address _charityWallet,
        bool _isCharityFeeNativeToken
    ) external onlyOwner {
        require(_charityWallet != address(0), "charity wallet can't be 0");
        charityWallet = _charityWallet;
        isCharityFeeNativeToken = _isCharityFeeNativeToken;
        isExcludedFromFee[_charityWallet] = true;
        isExcludedMaxTransactionAmount[_charityWallet] = true;
        emit UpdateCharityWallet(charityWallet, _isCharityFeeNativeToken);
    }

    function updateMaxTransactionAmount(uint256 _maxTransactionAmount)
        external
        onlyOwner
    {
        require(
            _maxTransactionAmount * (10**_decimals) <= _tTotal,
            "max transaction amount <= total supply"
        );
        maxTransactionAmount = _maxTransactionAmount * (10**_decimals);
        emit UpdateMaxTransactionAmount(maxTransactionAmount);
    }

    function updateMaxWalletAmount(uint256 _maxWalletAmount)
        external
        onlyOwner
    {
        require(
            _maxWalletAmount * (10**_decimals) <= _tTotal,
            "max wallet amount <= total supply"
        );
        maxWalletAmount = _maxWalletAmount * (10**_decimals);
        emit UpdateMaxWalletAmount(maxWalletAmount);
    }

    function updateMinAmountToTakeFee(uint256 _minAmountToTakeFee)
        external
        onlyOwner
    {
        require(_minAmountToTakeFee > 0, ">0");
        minAmountToTakeFee = _minAmountToTakeFee * (10**_decimals);
        emit UpdateMinAmountToTakeFee(minAmountToTakeFee);
    }

    function setAutomatedMarketMakerPair(address pair, bool value)
        public
        onlyOwner
    {
        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        automatedMarketMakerPairs[pair] = value;
        excludeFromMaxTransaction(pair, value);
        if (value) excludeFromReward(pair);
        else includeInReward(pair);
        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function excludeFromMaxTransaction(address updAds, bool isEx)
        public
        onlyOwner
    {
        isExcludedMaxTransactionAmount[updAds] = isEx;
        emit ExcludedMaxTransactionAmount(updAds, isEx);
    }

    function excludeFromFee(address account, bool isEx) external onlyOwner {
        isExcludedFromFee[account] = isEx;
        emit ExcludedFromFee(account, isEx);
    }

    function addBots(address[] memory _bots) public onlyOwner {
        for (uint256 i = 0; i < _bots.length; i++) {
            bots[_bots[i]] = true;
        }
        emit LogAddBots(_bots);
    }

    function removeBots(address[] memory _notbots) public onlyOwner {
        for (uint256 i = 0; i < _notbots.length; i++) {
            bots[_notbots[i]] = false;
        }
        emit LogRemoveBots(_notbots);
    }

    function enableTrading() external onlyOwner {
        require(!tradingActive, "already enabled");
        tradingActive = true;
        swapAndLiquifyEnabled = true;
        transferDelayEnabled = true;
        gasPriceLimitActivated = true;
        limitsInTrade = true;
        emit TradingActivated();
    }

    function setSwapAndLiquifyEnabled(bool _enabled) public onlyOwner {
        swapAndLiquifyEnabled = _enabled;
    }

    function setTransferDelayEnabled(bool _enabled) public onlyOwner {
        transferDelayEnabled = _enabled;
    }

    function setLimitsInTrade(bool _enabled) public onlyOwner {
        limitsInTrade = _enabled;
    }

    function setGasPriceLimitActivated(bool _enabled) public onlyOwner {
        gasPriceLimitActivated = _enabled;
    }

    function updateGasPriceLimit(uint256 gas) external onlyOwner {
        _gasPriceLimit = gas * 1 gwei;
        require(10000000 < _gasPriceLimit, "gasPricelimit > 10000000");
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "ERC20: No amount to transfer");
        require(!bots[from] && !bots[to]);
        if (!tradingActive) {
            require(
                isExcludedFromFee[from] || isExcludedFromFee[to],
                "Trading is not active yet."
            );
        }
        if (to != address(0) && to != address(0xDead) && !inSwapAndLiquify) {
            // only use to prevent sniper buys in the first blocks.
            if (gasPriceLimitActivated && automatedMarketMakerPairs[from]) {
                require(
                    tx.gasprice <= _gasPriceLimit,
                    "Gas price exceeds limit."
                );
            }
            if (transferDelayEnabled) {
                require(
                    _holderLastTransferTimestamp[tx.origin] < block.number,
                    "_transfer:: Transfer Delay enabled.  Only one transfer per block allowed."
                );
                _holderLastTransferTimestamp[tx.origin] = block.number;
            }

            if (limitsInTrade) {
                //when buy
                if (
                    automatedMarketMakerPairs[from] &&
                    !isExcludedMaxTransactionAmount[to]
                ) {
                    require(
                        amount <= maxTransactionAmount,
                        "Buy transfer amount exceeds the maxTransactionAmount."
                    );
                    require(
                        amount + balanceOf(to) <= maxWalletAmount,
                        "Cannot exceed max wallet"
                    );
                }
                //when sell
                else if (
                    automatedMarketMakerPairs[to] &&
                    !isExcludedMaxTransactionAmount[from]
                ) {
                    require(
                        amount <= maxTransactionAmount,
                        "Sell transfer amount exceeds the maxTransactionAmount."
                    );
                }
            }
        }
        uint256 contractTokenBalance = balanceOf(address(this));
        bool overMinimumTokenBalance = contractTokenBalance >=
            minAmountToTakeFee;

        // Take Fee
        if (
            !inSwapAndLiquify &&
            swapAndLiquifyEnabled &&
            overMinimumTokenBalance &&
            balanceOf(mainPair) > 0 &&
            automatedMarketMakerPairs[to]
        ) {
            takeFee();
        }
        removeAllFee();

        // If any account belongs to isExcludedFromFee account then remove the fee
        if (
            !inSwapAndLiquify &&
            !isExcludedFromFee[from] &&
            !isExcludedFromFee[to]
        ) {
            // Buy
            if (automatedMarketMakerPairs[from]) {
                _rewardFee = buyRewardFee;
                _liquidityFee = buyLiquidityFee;
                _charityFee = buyCharityFee;
                _treasuryFee = buyTreasuryFee;
            }
            // Sell
            else if (automatedMarketMakerPairs[to]) {
                _rewardFee = sellRewardFee;
                _liquidityFee = sellLiquidityFee;
                _charityFee = sellCharityFee;
                _treasuryFee = sellTreasuryFee;
            }
        }
        _tokenTransfer(from, to, amount);
        restoreAllFee();
    }

    function takeFee() private lockTheSwap {
        uint256 contractBalance = balanceOf(address(this));
        bool success;
        uint256 totalTokensTaken = _liquidityFeeTokens +
            _charityFeeTokens +
            _treasuryFeeTokens;
        if (totalTokensTaken == 0 || contractBalance < totalTokensTaken) {
            return;
        }

        // Halve the amount of liquidity tokens
        uint256 tokensForLiquidity = _liquidityFeeTokens / 2;
        uint256 initialBNBBalance = address(this).balance;
        uint256 bnbForLiquidity;
        if (isCharityFeeNativeToken) {
            swapTokensForBNB(tokensForLiquidity + _charityFeeTokens);
            uint256 bnbBalance = address(this).balance - (initialBNBBalance);
            uint256 bnbForCharity = (bnbBalance * _charityFeeTokens) /
                (tokensForLiquidity + _charityFeeTokens);
            bnbForLiquidity = bnbBalance - bnbForCharity;
            (success, ) = address(charityWallet).call{value: bnbForCharity}(
                ""
            );
            emit CharityFeeTaken(0, bnbForCharity);
        } else {
            swapTokensForBNB(tokensForLiquidity);
            bnbForLiquidity = address(this).balance - (initialBNBBalance);
            _transfer(address(this), charityWallet, _charityFeeTokens);
            emit CharityFeeTaken(_charityFeeTokens, 0);
        }

        if (tokensForLiquidity > 0 && bnbForLiquidity > 0) {
            addLiquidity(tokensForLiquidity, bnbForLiquidity);
            emit SwapAndLiquify(tokensForLiquidity, bnbForLiquidity);
        }

        if(isTreasuryContract){
            ITreasury treasury=ITreasury(treasuryAddress);
            _approve(address(this), address(treasury), _treasuryFeeTokens);
            treasury.depositReward(_treasuryFeeTokens);
        }else{
            _transfer(
                address(this),
                treasuryAddress,
                _treasuryFeeTokens
            );
        }
        emit TreasuryFeeTaken(_treasuryFeeTokens);    
        _liquidityFeeTokens = 0;
        _charityFeeTokens = 0;
        _treasuryFeeTokens = 0;
    }

    function swapTokensForBNB(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = mainRouter.WETH();
        _approve(address(this), address(mainRouter), tokenAmount);
        mainRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        _approve(address(this), address(mainRouter), tokenAmount);
        mainRouter.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            lpWallet,
            block.timestamp
        );
    }

    receive() external payable {}
}
