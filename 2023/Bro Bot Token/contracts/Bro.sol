// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.20;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IUniswapV2Factory} from "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import {IUniswapV2Router02} from "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";
import {IBroEvents} from "./IEvent.sol";
import {IBroErrors} from "./IError.sol";

contract BroBot is IERC20, Ownable, IBroEvents, IBroErrors {
    struct FeeStruct {
        uint256 total;
        uint256 liquidityPercentage;
        uint256 marketingPercentage;
        uint256 developmentPercentage;
        uint256 rewardsPercentage;
    }

    string private constant _NAME = "BRO BOT";
    string private constant _SYMBOL = "BRO";
    uint8 private constant _DECIMALS = 18;

    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) private _isExcludedFromHolderThreshold;
    mapping(address => bool) private _isExcludedFromMaxTx;
    mapping(address => bool) private _isExcludedFromFee;
    mapping(address => bool) private _isExcluded;
    address[] private _excluded;

    uint256 private constant _MAX = type(uint256).max;
    uint256 private _tTotal = 1_000_000 * 10 ** _DECIMALS;
    uint256 private _rTotal = (_MAX - (_MAX % _tTotal));
    uint256 private _tFeeTotal;

    uint256 private constant _FEE_DENOMINATOR = 10_000;
    uint256 private constant _MAX_FEE = 10_00;
    uint256 private constant _MIN_HOLDER_THRESHOLD = 10 * 10 ** _DECIMALS;
    uint256 public holderBalanceThreshold = 2_000 * 10 ** _DECIMALS;

    FeeStruct public activeFees;
    FeeStruct private _previousActiveFees;

    FeeStruct public buyFees = FeeStruct({
        total: 4_00,
        liquidityPercentage: 1_00,
        marketingPercentage: 1_00,
        developmentPercentage: 1_00,
        rewardsPercentage: 1_00
    });

    FeeStruct public sellFees = FeeStruct({
        total: 5_00,
        liquidityPercentage: 1_50,
        marketingPercentage: 1_50,
        developmentPercentage: 1_00,
        rewardsPercentage: 1_00
    });

    FeeStruct public transferFees = FeeStruct({
        total: 2_00,
        liquidityPercentage: 0,
        marketingPercentage: 2_00,
        developmentPercentage: 0,
        rewardsPercentage: 0
    });

    address public marketingWallet; // 0x26770A82bD8d76B1763b729E2aCB03bBeb0FFbB3
    address public developmentWallet; // 0xF47dE240CFa6fCa34EF81b5115A8aEEd59f88aEE

    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;

    uint256 private constant _MIN_TX_AMOUNT = 5_00 * 10 ** _DECIMALS;
    uint256 public maxTxAmount = 50_000 * 10 ** _DECIMALS;

    uint256 private constant _MIN_NUM_TOKENS_SELL_TO_ADD_TO_LIQUIDITY_AMOUNT = 5_000 * 10 ** _DECIMALS;
    uint256 private _numTokensSellToAddToLiquidity = 50_000 * 10 ** _DECIMALS;

    bool private _inSwapAndLiquify;
    bool public swapAndLiquifyEnabled = true;
    bool public maxTxEnabled; // Disabled by default. Make sure to enable this
    bool public holderThreshold; // Disabled by default. Make sure to enable this

    modifier lockTheSwap() {
        _inSwapAndLiquify = true;
        _;
        _inSwapAndLiquify = false;
    }

    constructor(
        address routerAddress_,
        address marketingAddress_,
        address developmentAddress_
    ) Ownable(_msgSender()) {
        _rOwned[_msgSender()] = _rTotal;

        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(
            routerAddress_
        );

        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory())
            .createPair(address(this), _uniswapV2Router.WETH());

        uniswapV2Router = _uniswapV2Router;

        setMarketingWallet(marketingAddress_);
        setDevelopmentWallet(developmentAddress_);

        // Exclude owner and this contract from fee
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[marketingAddress_] = true;
        _isExcludedFromFee[developmentAddress_] = true;

        // Exclude from rewards
        excludeFromReward(address(0));
        excludeFromReward(address(0xdead));
        excludeFromReward(address(this));
        excludeFromReward(marketingWallet);
        excludeFromReward(developmentWallet);

        // Exclude from holder threshold
        excludeFromHolderThreshold(owner());
        excludeFromHolderThreshold(address(0));
        excludeFromHolderThreshold(address(0xdead));
        excludeFromHolderThreshold(address(this));
        excludeFromHolderThreshold(uniswapV2Pair);
        excludeFromHolderThreshold(marketingWallet);
        excludeFromHolderThreshold(developmentWallet);

        // Enable max tx check by default
        maxTxEnabled = true;
        holderThreshold = true;

        emit Transfer(address(0), _msgSender(), _tTotal);
    }

    function name() public pure returns (string memory) {
        return _NAME;
    }

    function symbol() public pure returns (string memory) {
        return _SYMBOL;
    }

    function decimals() public pure returns (uint8) {
        return _DECIMALS;
    }

    function totalSupply() public view override returns (uint256) {
        return _tTotal;
    }

    function balanceOf(
        address account_
    ) public view override returns (uint256) {
        if (_isExcluded[account_])
            return _tOwned[account_];

        return tokenFromReflection(_rOwned[account_]);
    }

    function transfer(
        address recipient_,
        uint256 amount_
    ) public override returns (bool) {
        _transfer(_msgSender(), recipient_, amount_);

        return true;
    }

    function allowance(
        address owner_,
        address spender_
    ) public view override returns (uint256) {
        return _allowances[owner_][spender_];
    }

    function approve(
        address spender_,
        uint256 amount_
    ) public override returns (bool) {
        _approve(_msgSender(), spender_, amount_);

        return true;
    }

    function transferFrom(
        address sender_,
        address recipient_,
        uint256 amount_
    ) public override returns (bool) {
        _transfer(sender_, recipient_, amount_);
        _approve(
            sender_,
            _msgSender(),
            _allowances[sender_][_msgSender()] - amount_
        );

        return true;
    }

    function increaseAllowance(
        address spender_,
        uint256 addedValue_
    ) public virtual returns (bool) {
        _approve(
            _msgSender(),
            spender_,
            _allowances[_msgSender()][spender_] + addedValue_
        );

        return true;
    }

    function decreaseAllowance(
        address spender_,
        uint256 subtractedValue_
    ) public virtual returns (bool) {
        _approve(
            _msgSender(),
            spender_,
            _allowances[_msgSender()][spender_] - subtractedValue_
        );

        return true;
    }

    function isExcludedFromReward(address account_) public view returns (bool) {
        return _isExcluded[account_];
    }

    function totalFees() public view returns (uint256) {
        return _tFeeTotal;
    }

    function deliver(uint256 tAmount_) public {
        address sender = _msgSender();

        if(_isExcluded[sender])
            revert ForbiddenFunctionCallForExcludedAddresses();

        (uint256 rAmount, , , , , , ,) = _getValues(tAmount_);
        _rOwned[sender] -= rAmount;
        _rTotal -= rAmount;
        _tFeeTotal += tAmount_;
    }

    function reflectionFromToken(
        uint256 tAmount_,
        bool deductTransferFee_
    ) public view returns (uint256) {
        if(tAmount_ > _tTotal)
            revert AmountMustBeLessThanSupply();

        if (!deductTransferFee_) {
            (uint256 rAmount, , , , , , ,) = _getValues(tAmount_);
            return rAmount;
        } else {
            (, uint256 rTransferAmount, , , , , ,) = _getValues(tAmount_);
            return rTransferAmount;
        }
    }

    function tokenFromReflection(
        uint256 rAmount_
    ) public view returns (uint256) {
        if (rAmount_ > _rTotal)
            revert AmountMustBeLessThanTotalReflection(rAmount_, _rTotal);

        uint256 currentRate = _getRate();
        return rAmount_ / currentRate;
    }

    function excludeFromReward(address account_) public onlyOwner() {
        if (_isExcluded[account_])
            revert AccountIsAlreadyExcludedFromRewards();

        _excludeFromReward(account_);
    }

    function _excludeFromReward(address account_) internal {
        if (_rOwned[account_] > 0)
            _tOwned[account_] = tokenFromReflection(_rOwned[account_]);

        _isExcluded[account_] = true;
        _excluded.push(account_);

        emit UpdateExcludedFromRewards(account_, true);
    }

    function includeInReward(address account_) external onlyOwner() {
        if (!_isExcluded[account_])
            revert AccountIsAlreadyIncludedInRewards();

        _includeInReward(account_);
    }

    function _includeInReward(address account_) internal {
        for (uint256 i = 0; i < _excluded.length; i++) {
            if (_excluded[i] == account_) {
                _excluded[i] = _excluded[_excluded.length - 1];
                _tOwned[account_] = 0;
                _isExcluded[account_] = false;
                _excluded.pop();
                break;
            }
        }

        emit UpdateExcludedFromRewards(account_, false);
    }

    function _transferBothExcluded(
        address sender_,
        address recipient_,
        uint256 tAmount_
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rRewards,
            uint256 tTransferAmount,
            uint256 tLiquidity,
            uint256 tMarketing,
            uint256 tDevelopment,
            uint256 tRewards
        ) = _getValues(tAmount_);

        _tOwned[sender_] -= tAmount_;
        _rOwned[sender_] -= rAmount;
        _tOwned[recipient_] += tTransferAmount;
        _rOwned[recipient_] += rTransferAmount;

        _takeLiquidity(tLiquidity);
        _takeMarketing(tMarketing);
        _takeDevelopment(tDevelopment);
        _reflectFee(rRewards, tRewards);

        emit Transfer(sender_, recipient_, tTransferAmount);
    }

    function excludeFromFee(address account_) public onlyOwner() {
        _isExcludedFromFee[account_] = true;
        emit UpdateExcludedFromFee(account_, true);
    }

    function includeInFee(address account_) public onlyOwner() {
        _isExcludedFromFee[account_] = false;
        emit UpdateExcludedFromFee(account_, false);
    }

    function excludeFromMaxTx(address account_) public onlyOwner() {
        _isExcludedFromMaxTx[account_] = true;
        emit UpdateExcludedFromMaxTx(account_, true);
    }

    function includeInMaxTx(address account_) public onlyOwner() {
        _isExcludedFromMaxTx[account_] = false;
        emit UpdateExcludedFromMaxTx(account_, false);
    }

    function setMarketingWallet(address marketingWallet_) public onlyOwner() {
        if(marketingWallet_ == address(0)) revert CannotBeZeroAddress();
        if(marketingWallet_ == address(0xdead)) revert CannotBeDeadAddress();

        _setMarketingWallet(marketingWallet_);
    }

    function _setMarketingWallet(address marketingWallet_) internal {
        address oldAddress = marketingWallet;
        marketingWallet = marketingWallet_;

        emit MarketingWalletUpdated(oldAddress, marketingWallet_);
    }

    function setDevelopmentWallet(address developmentWallet_) public onlyOwner() {
        if(developmentWallet_ == address(0)) revert CannotBeZeroAddress();
        if(developmentWallet_ == address(0xdead)) revert CannotBeDeadAddress();

        _setDevelopmentWallet(developmentWallet_);
    }

    function _setDevelopmentWallet(address developmentWallet_) internal {
        address oldAddress = developmentWallet;
        developmentWallet = developmentWallet_;

        emit DevelopmentWalletUpdated(oldAddress, developmentWallet_);
    }

    function setBuyFee(
        uint256 buyFeeTotal_,
        uint256 buyFeeLiquidity_,
        uint256 buyFeeMarketing_,
        uint256 buyFeeDevelopment_,
        uint256 buyFeeRewards_
    ) external onlyOwner() {
        if (buyFeeTotal_ > _MAX_FEE)
            revert AmountIsGreaterThanMaxFee("Buy fee", buyFeeTotal_);

        if (
            buyFeeLiquidity_ +
            buyFeeMarketing_ +
            buyFeeDevelopment_ +
            buyFeeRewards_ != buyFeeTotal_
        )
            revert PercentagesDoNotCorrespondToSetFee();

        FeeStruct memory oldFees = buyFees;

        buyFees = FeeStruct({
            total: buyFeeTotal_,
            liquidityPercentage: buyFeeLiquidity_,
            marketingPercentage: buyFeeMarketing_,
            developmentPercentage: buyFeeDevelopment_,
            rewardsPercentage: buyFeeRewards_
        });

        emit UpdatedFee("Buy fee", oldFees.total, buyFeeTotal_);
    }

    function setTransferFee(
        uint256 transferFeeTotal_,
        uint256 transferFeeLiquidity_,
        uint256 transferFeeMarketing_,
        uint256 transferFeeDevelopment_,
        uint256 transferFeeRewards_
    ) external onlyOwner() {
        if (transferFeeTotal_ > _MAX_FEE)
            revert AmountIsGreaterThanMaxFee("Transfer fee", transferFeeTotal_);

        if (
            transferFeeLiquidity_ +
            transferFeeMarketing_ +
            transferFeeDevelopment_ +
            transferFeeRewards_ != transferFeeTotal_
        )
            revert PercentagesDoNotCorrespondToSetFee();

        FeeStruct memory oldFees = transferFees;

        transferFees = FeeStruct({
            total: transferFeeTotal_,
            liquidityPercentage: transferFeeLiquidity_,
            marketingPercentage: transferFeeMarketing_,
            developmentPercentage: transferFeeDevelopment_,
            rewardsPercentage: transferFeeRewards_
        });

        emit UpdatedFee("Transfer fee", oldFees.total, transferFeeTotal_);
    }

    function setSellFee(
        uint256 sellFeeTotal_,
        uint256 sellFeeLiquidity_,
        uint256 sellFeeMarketing_,
        uint256 sellFeeDevelopment_,
        uint256 sellFeeRewards_
    ) external onlyOwner() {
        if (sellFeeTotal_ > _MAX_FEE)
            revert AmountIsGreaterThanMaxFee("Sell fee", sellFeeTotal_);

        if (
            sellFeeLiquidity_ +
            sellFeeMarketing_ +
            sellFeeDevelopment_ +
            sellFeeRewards_ != sellFeeTotal_
        )
            revert PercentagesDoNotCorrespondToSetFee();

        FeeStruct memory oldFees = sellFees;

        sellFees = FeeStruct({
            total: sellFeeTotal_,
            liquidityPercentage: sellFeeLiquidity_,
            marketingPercentage: sellFeeMarketing_,
            developmentPercentage: sellFeeDevelopment_,
            rewardsPercentage: sellFeeRewards_
        });

        emit UpdatedFee("Sell fee", oldFees.total, sellFeeTotal_);
    }

    function setMaxTxPercent(uint256 maxTxPercent_) external onlyOwner() {
        uint256 oldValue = maxTxAmount;
        uint256 newValue = (_tTotal * maxTxPercent_) / _FEE_DENOMINATOR;

        if(maxTxPercent_ > _FEE_DENOMINATOR) revert PercentageCannotBeHigherThan100Percent(maxTxPercent_, _FEE_DENOMINATOR);
        if(newValue < _MIN_TX_AMOUNT) revert AmountCannotBeLessThanMinMaxTxAmount(newValue, _MIN_TX_AMOUNT);
        if(newValue < _numTokensSellToAddToLiquidity) revert AmountCannotBeLessThanNumTokensSellToAddLiquidity(newValue, _numTokensSellToAddToLiquidity);

        maxTxAmount = newValue;

        emit UpdatedMaxTxAmount(oldValue, newValue);
    }

    function setMaxTxAmount(uint256 amount_) external onlyOwner() {
        if(amount_ > _tTotal) revert AmountCannotBeHigherThanTotal(amount_, _tTotal);
        if(amount_ < _MIN_TX_AMOUNT) revert AmountCannotBeLessThanMinMaxTxAmount(amount_, _MIN_TX_AMOUNT);
        if(amount_ < _numTokensSellToAddToLiquidity) revert AmountCannotBeLessThanNumTokensSellToAddLiquidity(amount_, _numTokensSellToAddToLiquidity);

        uint256 oldValue = maxTxAmount;
        maxTxAmount = amount_;

        emit UpdatedMaxTxAmount(oldValue, amount_);
    }

    function toggleEnableMaxTx() external onlyOwner() {
        maxTxEnabled = !maxTxEnabled;
        emit UpdatedEnabledMaxTx(maxTxEnabled);
    }

    function isExcludedFromHolderThreshold(address addr_) public view returns(bool) {
        return _isExcludedFromHolderThreshold[addr_];
    }

    function excludeFromHolderThreshold(address account_) public onlyOwner() {
        _isExcludedFromHolderThreshold[account_] = true;
        emit UpdateExcludedFromHolderThreshold(account_, true);
    }

    function includeInHolderThreshold(address account_) external onlyOwner() {
        _isExcludedFromHolderThreshold[account_] = false;
        emit UpdateExcludedFromHolderThreshold(account_, false);
    }

    function setHolderBalanceThreshold(uint256 threshold_) external onlyOwner() {
        if(threshold_ < _MIN_HOLDER_THRESHOLD) revert AmountCannotBeLessThanMinHolderThreshold(threshold_, _MIN_HOLDER_THRESHOLD);

        uint256 old = holderBalanceThreshold;
        holderBalanceThreshold = threshold_;
        emit UpdatedHolderThreshold(old, threshold_);
    }

    function _checkHolderThresholdBalance(address addr_) internal {
        // Check for user balance and include/exclude depending on balance
        if(balanceOf(addr_) < holderBalanceThreshold) {
            if(!_isExcluded[addr_])
                _excludeFromReward(addr_);
        } else if(balanceOf(addr_) > holderBalanceThreshold) {
            if(_isExcluded[addr_])
                _includeInReward(addr_);
        }
    }
    function _checkThresholdBalanceOfBothUsers(address from_, address to_) internal {
        if(!isExcludedFromHolderThreshold(from_))
            _checkHolderThresholdBalance(from_);

        if(!isExcludedFromHolderThreshold(to_))
            _checkHolderThresholdBalance(to_);
    }

    function toggleEnableThreshold() external onlyOwner() {
        holderThreshold = !holderThreshold;
        emit UpdatedThresholdEnabled(holderThreshold);
    }

    function setNumTokensSellToAddToLiquidity(uint256 amount_) external onlyOwner() {
        if(amount_ < _MIN_NUM_TOKENS_SELL_TO_ADD_TO_LIQUIDITY_AMOUNT) revert AmountCannotBeLessThanMinNumTokensSellToAddLiquidity(amount_, _MIN_NUM_TOKENS_SELL_TO_ADD_TO_LIQUIDITY_AMOUNT);
        if(amount_ > maxTxAmount) revert AmountCannotBeHigherThanMaxTxAmount(amount_, maxTxAmount);

        uint256 oldValue = _numTokensSellToAddToLiquidity;
        _numTokensSellToAddToLiquidity = amount_;

        emit UpdatedNumTokensSellToAddToLiquidity(oldValue, amount_);
    }

    function setSwapAndLiquifyEnabled(bool enabled_) public onlyOwner() {
        swapAndLiquifyEnabled = enabled_;

        emit SwapAndLiquifyEnabledUpdated(enabled_);
    }

    // to receive ETH from uniswapV2Router when swapping
    receive() external payable {}

    function _reflectFee(uint256 rFee_, uint256 tFee_) private {
        _rTotal -= rFee_;
        _tFeeTotal += tFee_;
    }

    function _takeLiquidity(uint256 tLiquidity_) private {
        uint256 currentRate = _getRate();
        uint256 rLiquidity = tLiquidity_ * currentRate;
        address thisContract = address(this);

        _rOwned[thisContract] += rLiquidity;

        if (_isExcluded[thisContract])
            _tOwned[thisContract] += tLiquidity_;
    }

    function _takeMarketing(uint256 tMarketing_) private {
        uint256 currentRate = _getRate();
        uint256 rMarketing = tMarketing_ * currentRate;
        address marketingAddress = marketingWallet;

        _rOwned[marketingAddress] += rMarketing;

        if (_isExcluded[marketingAddress])
            _tOwned[marketingAddress] += tMarketing_;
    }

    function _takeDevelopment(uint256 tDevelopment_) private {
        uint256 currentRate = _getRate();
        uint256 rDevelopment = tDevelopment_ * currentRate;
        address developmentAddress = developmentWallet;

        _rOwned[developmentAddress] += rDevelopment;

        if (_isExcluded[developmentAddress])
            _tOwned[developmentAddress] += tDevelopment_;
    }
    function _getValues(
        uint256 tAmount_
    )
        private
        view
        returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256, uint256)
    {
        (
            uint256 tTransferAmount,
            uint256 tLiquidity,
            uint256 tMarketing,
            uint256 tDevelopment,
            uint256 tRewards
        ) = _getTValues(tAmount_);
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rRewards
        ) = _getRValues(
            tAmount_,
            tLiquidity,
            tMarketing,
            tDevelopment,
            tRewards,
            _getRate()
        );

        return (
            rAmount,
            rTransferAmount,
            rRewards,
            tTransferAmount,
            tLiquidity,
            tMarketing,
            tDevelopment,
            tRewards
        );
    }

    function _getTValues(
        uint256 tAmount_
    ) private view returns (uint256, uint256, uint256, uint256, uint256) {
        // Get active fees
        FeeStruct memory currentFees = activeFees;

        uint256 tLiquidity = _calculateFee(tAmount_, currentFees.liquidityPercentage);
        uint256 tMarketing = _calculateFee(tAmount_, currentFees.marketingPercentage);
        uint256 tDevelopment = _calculateFee(tAmount_, currentFees.developmentPercentage);
        uint256 tRewards = _calculateFee(tAmount_, currentFees.rewardsPercentage);

        uint256 tTransferAmount = tAmount_ - tLiquidity - tMarketing - tDevelopment - tRewards;

        return (
            tTransferAmount,
            tLiquidity,
            tMarketing,
            tDevelopment,
            tRewards
        );
    }

    function _getRValues(
        uint256 tAmount_,
        uint256 tLiquidity_,
        uint256 tMarketing_,
        uint256 tDevelopment_,
        uint256 tRewards_,
        uint256 currentRate_
    ) private pure returns (uint256, uint256, uint256) {
        uint256 rAmount = tAmount_ * currentRate_;

        uint256 rLiquidity = tLiquidity_ * currentRate_;
        uint256 rMarketing = tMarketing_ * currentRate_;
        uint256 rDevelopment = tDevelopment_ * currentRate_;
        uint256 rRewards = tRewards_ * currentRate_;

        uint256 rTransferAmount = rAmount - rLiquidity - rMarketing - rDevelopment - rRewards;

        return (rAmount, rTransferAmount, rRewards);
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();

        return rSupply / tSupply;
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        uint256 rSupply = _rTotal;
        uint256 tSupply = _tTotal;

        for (uint256 i = 0; i < _excluded.length; i++) {
            if (
                _rOwned[_excluded[i]] > rSupply ||
                _tOwned[_excluded[i]] > tSupply
            ) return (_rTotal, _tTotal);

            rSupply -= _rOwned[_excluded[i]];
            tSupply -= _tOwned[_excluded[i]];
        }

        if (rSupply < _rTotal / _tTotal)
            return (_rTotal, _tTotal);

        return (rSupply, tSupply);
    }

    function _removeAllFee() private {
        FeeStruct memory currentFees = activeFees;

        // Don't have to check every value because the values must be correspond to the total
        if(currentFees.total == 0)
            return;

        _previousActiveFees = currentFees;
        activeFees = FeeStruct({
            total: 0,
            liquidityPercentage: 0,
            marketingPercentage: 0,
            developmentPercentage: 0,
            rewardsPercentage: 0
        });
    }

    function _restoreAllFee() private {
        activeFees = _previousActiveFees;
    }

    function isExcludedFromFee(address account_) public view returns (bool) {
        return _isExcludedFromFee[account_];
    }

    function isExcludedFromMaxTx(address account_) public view returns (bool) {
        return _isExcludedFromMaxTx[account_];
    }

    function numTokensSellToAddToLiquidity() external view returns(uint256) {
        return _numTokensSellToAddToLiquidity;
    }

    function _approve(
        address owner_,
        address spender_,
        uint256 amount_
    ) private {
        if (owner_ == address(0)) revert ERC20InvalidApprover(address(0));
        if (spender_ == address(0)) revert ERC20InvalidSpender(address(0));

        _allowances[owner_][spender_] = amount_;
        emit Approval(owner_, spender_, amount_);
    }

    function _transfer(address from_, address to_, uint256 amount) private {
        if(from_ == address(0)) revert ERC20InvalidSender(address(0));
        if(to_ == address(0)) revert ERC20InvalidReceiver(address(0));
        if(amount == 0) revert AmountMustBeGreaterThanZero();

        if(maxTxEnabled && !_isExcludedFromMaxTx[from_]) {
            if (from_ != owner() && to_ != owner())
                if(amount > maxTxAmount)
                    revert AboveMaxTxAmount(amount, maxTxAmount);
        }

        uint256 contractTokenBalance = balanceOf(address(this));
        if (contractTokenBalance >= maxTxAmount)
            contractTokenBalance = maxTxAmount;

        bool overMinTokenBalance = contractTokenBalance >= _numTokensSellToAddToLiquidity;
        if (
            overMinTokenBalance &&
            !_inSwapAndLiquify &&
            from_ != uniswapV2Pair &&
            swapAndLiquifyEnabled
        ) {
            contractTokenBalance = _numTokensSellToAddToLiquidity;
            _swapAndLiquify(contractTokenBalance);
        }

        activeFees = from_ == uniswapV2Pair ? buyFees :
            to_ == uniswapV2Pair ?
                sellFees :
                transferFees;

        bool takeFee = true;
        if (_isExcludedFromFee[from_] || _isExcludedFromFee[to_])
            takeFee = false;

        _tokenTransfer(from_, to_, amount, takeFee);

        // Check holder threshold is enabled
        if(holderThreshold)
            if (from_ != owner() && to_ != owner())
                _checkThresholdBalanceOfBothUsers(from_, to_);
    }

    function _swapAndLiquify(
        uint256 contractTokenBalance_
    ) private lockTheSwap {
        uint256 half = contractTokenBalance_ / 2;
        uint256 otherHalf = contractTokenBalance_ - half;

        uint256 initialBalance = address(this).balance;

        // swap tokens for ETH
        _swapTokensForEth(half); // <- this breaks the ETH -> HATE swap when swap+liquify is triggered

        // how much ETH did we just swap into?
        uint256 newBalance = address(this).balance - initialBalance;

        // add liquidity to uniswap
        _addLiquidity(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function _swapTokensForEth(uint256 tokenAmount_) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), tokenAmount_);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount_,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function _addLiquidity(uint256 tokenAmount_, uint256 ethAmount_) private {
        _approve(address(this), address(uniswapV2Router), tokenAmount_);

        // add the liquidity
        uniswapV2Router.addLiquidityETH{value: ethAmount_}(
            address(this),
            tokenAmount_,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(0),
            block.timestamp
        );
    }

    //this method is responsible for taking all fee, if takeFee is true
    function _tokenTransfer(
        address sender_,
        address recipient_,
        uint256 amount_,
        bool takeFee_
    ) private {
        if (!takeFee_) _removeAllFee();

        if (_isExcluded[sender_] && !_isExcluded[recipient_]) {
            _transferFromExcluded(sender_, recipient_, amount_);
        } else if (!_isExcluded[sender_] && _isExcluded[recipient_]) {
            _transferToExcluded(sender_, recipient_, amount_);
        } else if (!_isExcluded[sender_] && !_isExcluded[recipient_]) {
            _transferStandard(sender_, recipient_, amount_);
        } else if (_isExcluded[sender_] && _isExcluded[recipient_]) {
            _transferBothExcluded(sender_, recipient_, amount_);
        } else {
            _transferStandard(sender_, recipient_, amount_);
        }

        if (!takeFee_) _restoreAllFee();
    }

    function _transferStandard(
        address sender_,
        address recipient_,
        uint256 tAmount_
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rRewards,
            uint256 tTransferAmount,
            uint256 tLiquidity,
            uint256 tMarketing,
            uint256 tDevelopment,
            uint256 tRewards
        ) = _getValues(tAmount_);

        _rOwned[sender_] -= rAmount;
        _rOwned[recipient_] += rTransferAmount;

        _takeFeesAndReflect(tLiquidity, tMarketing, tDevelopment, rRewards, tRewards);


        emit Transfer(sender_, recipient_, tTransferAmount);
    }

    function _transferToExcluded(
        address sender_,
        address recipient_,
        uint256 tAmount_
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rRewards,
            uint256 tTransferAmount,
            uint256 tLiquidity,
            uint256 tMarketing,
            uint256 tDevelopment,
            uint256 tRewards
        ) = _getValues(tAmount_);

        _rOwned[sender_] -= rAmount;
        _tOwned[recipient_] += tTransferAmount;
        _rOwned[recipient_] += rTransferAmount;

        _takeFeesAndReflect(tLiquidity, tMarketing, tDevelopment, rRewards, tRewards);


        emit Transfer(sender_, recipient_, tTransferAmount);
    }

    function _transferFromExcluded(
        address sender_,
        address recipient_,
        uint256 tAmount_
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rRewards,
            uint256 tTransferAmount,
            uint256 tLiquidity,
            uint256 tMarketing,
            uint256 tDevelopment,
            uint256 tRewards
        ) = _getValues(tAmount_);

        _tOwned[sender_] -= tAmount_;
        _rOwned[sender_] -= rAmount;
        _rOwned[recipient_] += rTransferAmount;

        _takeFeesAndReflect(tLiquidity, tMarketing, tDevelopment, rRewards, tRewards);

        emit Transfer(sender_, recipient_, tTransferAmount);
    }

    function _takeFeesAndReflect(
        uint256 tLiquidity_,
        uint256 tMarketing_,
        uint256 tDevelopment_,
        uint256 rRewards_,
        uint256 tRewards_
    ) internal {
        _takeLiquidity(tLiquidity_);
        _takeMarketing(tMarketing_);
        _takeDevelopment(tDevelopment_);

        _reflectFee(rRewards_, tRewards_);
    }

    function _calculateFee(uint256 amount_, uint256 feePercentage_) internal pure returns(uint256){
        return (amount_ * feePercentage_) / _FEE_DENOMINATOR;
    }

    function manualSwap(uint256 amount_) external onlyOwner() {
        uint256 contractTokenBalance = balanceOf(address(this));
        if(amount_ == 0 || amount_ > contractTokenBalance)
            amount_ = contractTokenBalance;

        _swapAndLiquify(amount_);

        emit ManualSwapExecuted(block.timestamp);
    }

    function withdrawStuckTokens(address tokenAddress_) external onlyOwner() {
        if(tokenAddress_ == address(0)) revert CannotBeZeroAddress();
        if(tokenAddress_ == address(0xdead)) revert CannotBeDeadAddress();
        if(tokenAddress_ == address(this)) revert CannotWithdrawFromOwnContractAddress();

        IERC20 token = IERC20(tokenAddress_);
        uint256 tokenBalance = token.balanceOf(address(this));
        token.transfer(owner(), tokenBalance);
    }

}
