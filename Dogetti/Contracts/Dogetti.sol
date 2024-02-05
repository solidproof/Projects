// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IPancakeRouter01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB, uint256 liquidity);

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
        returns (uint256 amountToken, uint256 amountETH, uint256 liquidity);

    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETH(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountToken, uint256 amountETH);

    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint256 liquidity,
        uint256 amountAMin,
        uint256 amountBMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountA, uint256 amountB);

    function removeLiquidityETHWithPermit(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountToken, uint256 amountETH);

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactETHForTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function swapTokensForExactETH(
        uint256 amountOut,
        uint256 amountInMax,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapETHForExactTokens(
        uint256 amountOut,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable returns (uint256[] memory amounts);

    function quote(
        uint256 amountA,
        uint256 reserveA,
        uint256 reserveB
    ) external pure returns (uint256 amountB);

    function getAmountOut(
        uint256 amountIn,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountOut);

    function getAmountIn(
        uint256 amountOut,
        uint256 reserveIn,
        uint256 reserveOut
    ) external pure returns (uint256 amountIn);

    function getAmountsOut(
        uint256 amountIn,
        address[] calldata path
    ) external view returns (uint256[] memory amounts);

    function getAmountsIn(
        uint256 amountOut,
        address[] calldata path
    ) external view returns (uint256[] memory amounts);
}

interface IPancakeRouter02 is IPancakeRouter01 {
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    ) external returns (uint256 amountETH);

    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint256 liquidity,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline,
        bool approveMax,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external returns (uint256 amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external payable;

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface IPancakeFactory {
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint256
    );

    function feeTo() external view returns (address);

    function feeToSetter() external view returns (address);

    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);

    function allPairs(uint256) external view returns (address pair);

    function allPairsLength() external view returns (uint256);

    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);

    function setFeeTo(address) external;

    function setFeeToSetter(address) external;

    function INIT_CODE_PAIR_HASH() external view returns (bytes32);
}

interface IPancakeCaller {
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        address router,
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        uint256 deadline
    ) external;
}

contract Dogetti is IERC20, Ownable {
    using SafeERC20 for IERC20;
    IPancakeCaller public immutable pancakeCaller;
    address public baseTokenForPair;
    uint8 private immutable _decimals;
    mapping(address => uint256) private _rOwned;
    mapping(address => uint256) private _tOwned;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcluded;
    address[] private _excluded;
    uint256 private constant MAX = ~uint256(0);
    uint256 private immutable _tTotal;
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
    uint256 private _burnFee;
    uint256 private _previousBurnFee;
    bool private inSwapAndLiquify;
    uint16 public sellRewardFee;
    uint16 public buyRewardFee;
    uint16 public sellLiquidityFee;
    uint16 public buyLiquidityFee;

    uint16 public sellCharityFee;
    uint16 public buyCharityFee;

    uint16 public sellBurnFee;
    uint16 public buyBurnFee;

    address public charityWallet;
    bool public isCharityFeeBaseToken;

    uint256 public minAmountToTakeFee;

    IPancakeRouter02 public mainRouter;
    address public mainPair;

    mapping(address => bool) public isExcludedFromFee;
    mapping(address => bool) public automatedMarketMakerPairs;

    uint256 private _liquidityFeeTokens;
    uint256 private _charityFeeTokens;

    event UpdateLiquidityFee(
        uint16 newSellLiquidityFee,
        uint16 newBuyLiquidityFee,
        uint16 oldSellLiquidityFee,
        uint16 oldBuyLiquidityFee
    );
    event UpdateCharityFee(
        uint16 newSellCharityFee,
        uint16 newBuyCharityFee,
        uint16 oldSellCharityFee,
        uint16 oldBuyCharityFee
    );
    event UpdateBurnFee(
        uint16 newSellBurnFee,
        uint16 newBuyBurnFee,
        uint16 oldSellBurnFee,
        uint16 oldBuyBurnFee
    );
    event UpdateRewardFee(
        uint16 newSellRewardFee,
        uint16 newBuyRewardFee,
        uint16 oldSellRewardFee,
        uint16 oldBuyRewardFee
    );
    event UpdateCharityWallet(
        address indexed newCharityWallet,
        bool newIsCharityFeeBaseToken,
        address indexed oldCharityWallet,
        bool oldIsCharityFeeBaseToken
    );

    event UpdateMinAmountToTakeFee(
        uint256 newMinAmountToTakeFee,
        uint256 oldMinAmountToTakeFee
    );
    event SetAutomatedMarketMakerPair(address indexed pair, bool value);
    event ExcludedFromFee(address indexed account, bool isEx);
    event SwapAndLiquify(
        uint256 tokensForLiquidity,
        uint256 baseTokenForLiquidity
    );
    event CharityFeeTaken(
        uint256 charityFeeTokens,
        uint256 charityFeeBaseTokenSwapped
    );
    event UpdatePancakeRouter(
        address indexed newAddress,
        address indexed oldRouter
    );

    constructor(
        string memory __name,
        string memory __symbol,
        uint8 __decimals,
        uint256 _totalSupply,
        address[4] memory _accounts,
        bool _isCharityFeeBaseToken,
        uint16[8] memory _fees
    ) {
        pancakeCaller=IPancakeCaller(_accounts[3]);
        baseTokenForPair = _accounts[2];
        _decimals = __decimals;
        _name = __name;
        _symbol = __symbol;
        _tTotal = _totalSupply;
        _rTotal = (MAX - (MAX % _tTotal));
        _rOwned[_msgSender()] = _rTotal;
        require(_accounts[0] != address(0), "charity wallet can not be 0");
        require(_accounts[1] != address(0), "Router address can not be 0");
        require(
            _fees[0] + _fees[2] + _fees[4] + _fees[6] <= 200,
            "sell fee <= 20%"
        );
        require(
            _fees[1] + _fees[3] + _fees[5] + _fees[7] <= 200,
            "buy fee <= 20%"
        );

        charityWallet = _accounts[0];
        isCharityFeeBaseToken = _isCharityFeeBaseToken;
        emit UpdateCharityWallet(
            charityWallet,
            isCharityFeeBaseToken,
            address(0),
            false
        );
        mainRouter = IPancakeRouter02(_accounts[1]);
        emit UpdatePancakeRouter(address(mainRouter), address(0));
        mainPair = IPancakeFactory(mainRouter.factory()).createPair(
            address(this),
            baseTokenForPair
        );

        sellLiquidityFee = _fees[0];
        buyLiquidityFee = _fees[1];
        emit UpdateLiquidityFee(sellLiquidityFee, buyLiquidityFee, 0, 0);
        sellCharityFee = _fees[2];
        buyCharityFee = _fees[3];
        emit UpdateCharityFee(sellCharityFee, buyCharityFee, 0, 0);
        sellRewardFee = _fees[4];
        buyRewardFee = _fees[5];
        emit UpdateRewardFee(sellRewardFee, buyRewardFee, 0, 0);
        sellBurnFee = _fees[6];
        buyBurnFee = _fees[7];
        emit UpdateBurnFee(sellBurnFee, buyBurnFee, 0, 0);
        minAmountToTakeFee = _totalSupply / (10000);
        emit UpdateMinAmountToTakeFee(minAmountToTakeFee, 0);
        _isExcluded[address(0xdead)] = true;
        _excluded.push(address(0xdead));

        isExcludedFromFee[address(this)] = true;
        isExcludedFromFee[charityWallet] = true;
        isExcludedFromFee[_msgSender()] = true;
        isExcludedFromFee[address(0xdead)] = true;
        _setAutomatedMarketMakerPair(mainPair, true);
        emit Transfer(address(0), _msgSender(), _totalSupply);
    }

    function updatePancakePair(address _baseTokenForPair) external onlyOwner {
        require(
            _baseTokenForPair != baseTokenForPair,
            "The baseTokenForPair already has that address"
        );
        baseTokenForPair = _baseTokenForPair;
        mainPair = IPancakeFactory(mainRouter.factory()).createPair(
            address(this),
            baseTokenForPair
        );
        _setAutomatedMarketMakerPair(mainPair, true);
    }

    function updatePancakeRouter(address newAddress) public onlyOwner {
        require(
            newAddress != address(mainRouter),
            "The router already has that address"
        );
        emit UpdatePancakeRouter(newAddress, address(mainRouter));
        mainRouter = IPancakeRouter02(newAddress);
        address _mainPair = IPancakeFactory(mainRouter.factory()).createPair(
            address(this),
            baseTokenForPair
        );
        mainPair = _mainPair;
        _setAutomatedMarketMakerPair(mainPair, true);
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
        uint256 currentRate = _getRate();
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity,
            uint256 tCharity,
            uint256 tBurn
        ) = _getValues(tAmount, currentRate);
        _rOwned[sender] = _rOwned[sender] - (rAmount);
        _rOwned[recipient] = _rOwned[recipient] + (rTransferAmount);
        _takeLiquidity(tLiquidity, tCharity, tBurn, currentRate);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
        emit Transfer(sender, address(this), tCharity + tLiquidity);
        emit Transfer(sender, address(0xdead), tBurn);
    }

    function _transferToExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        uint256 currentRate = _getRate();
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity,
            uint256 tCharity,
            uint256 tBurn
        ) = _getValues(tAmount, currentRate);
        _rOwned[sender] = _rOwned[sender] - (rAmount);
        _tOwned[recipient] = _tOwned[recipient] + (tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient] + (rTransferAmount);
        _takeLiquidity(tLiquidity, tCharity, tBurn, currentRate);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
        emit Transfer(sender, address(this), tCharity + tLiquidity);
        emit Transfer(sender, address(0xdead), tBurn);
    }

    function _transferFromExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        uint256 currentRate = _getRate();
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity,
            uint256 tCharity,
            uint256 tBurn
        ) = _getValues(tAmount, currentRate);
        _tOwned[sender] = _tOwned[sender] - (tAmount);
        _rOwned[sender] = _rOwned[sender] - (rAmount);
        _rOwned[recipient] = _rOwned[recipient] + (rTransferAmount);
        _takeLiquidity(tLiquidity, tCharity, tBurn, currentRate);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
        emit Transfer(sender, address(this), tCharity + tLiquidity);
        emit Transfer(sender, address(0xdead), tBurn);
    }

    function _transferBothExcluded(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        uint256 currentRate = _getRate();
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee,
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity,
            uint256 tCharity,
            uint256 tBurn
        ) = _getValues(tAmount, currentRate);
        _tOwned[sender] = _tOwned[sender] - (tAmount);
        _rOwned[sender] = _rOwned[sender] - (rAmount);
        _tOwned[recipient] = _tOwned[recipient] + (tTransferAmount);
        _rOwned[recipient] = _rOwned[recipient] + (rTransferAmount);
        _takeLiquidity(tLiquidity, tCharity, tBurn, currentRate);
        _reflectFee(rFee, tFee);
        emit Transfer(sender, recipient, tTransferAmount);
        emit Transfer(sender, address(this), tCharity + tLiquidity);
        emit Transfer(sender, address(0xdead), tBurn);
    }

    function _reflectFee(uint256 rFee, uint256 tFee) private {
        _rTotal = _rTotal - (rFee);
        _tFeeTotal = _tFeeTotal + (tFee);
    }

    function _getValues(
        uint256 tAmount,
        uint256 currentRate
    )
        private
        view
        returns (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 rFee, 
            uint256 tTransferAmount,
            uint256 tFee,
            uint256 tLiquidity,
            uint256 tCharity,
            uint256 tBurn
        )
    {     

        (
            tTransferAmount,
            tFee,
            tLiquidity,
            tCharity,
            tBurn
        ) = _getTValues(tAmount);
        rAmount = tAmount * currentRate;
        rFee = tFee * currentRate;
        rTransferAmount = tTransferAmount * currentRate;
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
        uint256 tFee = (tAmount * _rewardFee) / (10 ** 3);
        uint256 tLiquidity = (tAmount * _rewardFee) / (10 ** 3);
        uint256 tCharity = (tAmount * _charityFee) / (10 ** 3);
        uint256 tBurn = (tAmount * _burnFee) / (10 ** 3);
        uint256 tTransferAmount = tAmount -
            tFee -
            tLiquidity -
            tCharity -
            tBurn;
        return (tTransferAmount, tFee, tLiquidity, tCharity, tBurn);
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
        if (
            _rewardFee == 0 &&
            _liquidityFee == 0 &&
            _charityFee == 0 &&
            _burnFee == 0
        ) return;

        _previousRewardFee = _rewardFee;
        _previousLiquidityFee = _liquidityFee;
        _previousCharityFee = _charityFee;
        _previousBurnFee = _burnFee;

        _charityFee = 0;
        _rewardFee = 0;
        _liquidityFee = 0;
        _burnFee = 0;
    }

    function restoreAllFee() private {
        _rewardFee = _previousRewardFee;
        _liquidityFee = _previousLiquidityFee;
        _charityFee = _previousCharityFee;
        _burnFee = _previousBurnFee;
    }

    function _takeLiquidity(
        uint256 tLiquidity,
        uint256 tCharity,
        uint256 tBurn,
        uint256 currentRate
    ) private {
        _liquidityFeeTokens = _liquidityFeeTokens + tLiquidity;
        _charityFeeTokens = _charityFeeTokens + tCharity;
        uint256 rLiquidity = tLiquidity * currentRate;
        uint256 rCharity = tCharity * currentRate;
        uint256 rBurn = tBurn * currentRate;
        _rOwned[address(this)] = _rOwned[address(this)] + rLiquidity + rCharity;
        if (_isExcluded[address(this)])
            _tOwned[address(this)] =
                _tOwned[address(this)] +
                tLiquidity +
                tCharity;
        _rOwned[address(0xdead)] = _rOwned[address(0xdead)] + rBurn;
        _tOwned[address(0xdead)] = _tOwned[address(0xdead)] + tBurn;
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

    function transfer(
        address recipient,
        uint256 amount
    ) external override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(
        address owner_,
        address spender
    ) external view override returns (uint256) {
        return _allowances[owner_][spender];
    }

    function approve(
        address spender,
        uint256 amount
    ) public override returns (bool) {
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

    function increaseAllowance(
        address spender,
        uint256 addedValue
    ) external virtual returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + (addedValue)
        );
        return true;
    }

    function decreaseAllowance(
        address spender,
        uint256 subtractedValue
    ) external virtual returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] - (subtractedValue)
        );
        return true;
    }

    function isExcludedFromReward(
        address account
    ) external view returns (bool) {
        return _isExcluded[account];
    }

    function totalFees() external view returns (uint256) {
        return _tFeeTotal;
    }

    function reflectionFromToken(
        uint256 tAmount,
        bool deductTransferFee
    ) external view returns (uint256) {
        require(tAmount <= _tTotal, "Amount must be less than supply");
        if (!deductTransferFee) {
            (uint256 rAmount, , , , , , , ) = _getValues(tAmount, _getRate());
            return rAmount;
        } else {
            (, uint256 rTransferAmount, , , , , , ) = _getValues(
                tAmount,
                _getRate()
            );
            return rTransferAmount;
        }
    }

    function tokenFromReflection(
        uint256 rAmount
    ) public view returns (uint256) {
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
                uint256 prev_rOwned = _rOwned[account];
                _rOwned[account] = _tOwned[account] * _getRate();
                _rTotal = _rTotal + _rOwned[account] - prev_rOwned;
                _isExcluded[account] = false;
                _excluded[i] = _excluded[_excluded.length - 1];
                _excluded.pop();
                break;
            }
        }
    }

    function _approve(address owner_, address spender, uint256 amount) private {
        require(owner_ != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner_][spender] = amount;
        emit Approval(owner_, spender, amount);
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
            _sellLiquidityFee + (sellCharityFee) + (sellRewardFee) <= 200,
            "sell fee <= 20%"
        );
        require(
            _buyLiquidityFee + (buyCharityFee) + (buyRewardFee) <= 200,
            "buy fee <= 20%"
        );
        emit UpdateLiquidityFee(
            _sellLiquidityFee,
            _buyLiquidityFee,
            sellLiquidityFee,
            buyLiquidityFee
        );
        sellLiquidityFee = _sellLiquidityFee;
        buyLiquidityFee = _buyLiquidityFee;
    }

    function updateCharityFee(
        uint16 _sellCharityFee,
        uint16 _buyCharityFee
    ) external onlyOwner {
        require(
            _sellCharityFee + (sellLiquidityFee) + (sellRewardFee) <= 200,
            "sell fee <= 20%"
        );
        require(
            _buyCharityFee + (buyLiquidityFee) + (buyRewardFee) <= 200,
            "buy fee <= 20%"
        );
        emit UpdateCharityFee(
            _sellCharityFee,
            _buyCharityFee,
            sellCharityFee,
            buyCharityFee
        );
        sellCharityFee = _sellCharityFee;
        buyCharityFee = _buyCharityFee;
    }

    function updateRewardFee(
        uint16 _sellRewardFee,
        uint16 _buyRewardFee
    ) external onlyOwner {
        require(
            _sellRewardFee + (sellLiquidityFee) + (sellCharityFee) <= 200,
            "sell fee <= 20%"
        );
        require(
            _buyRewardFee + (buyLiquidityFee) + (buyCharityFee) <= 200,
            "buy fee <= 20%"
        );
        emit UpdateRewardFee(
            _sellRewardFee,
            _buyRewardFee,
            sellRewardFee,
            buyRewardFee
        );
        sellRewardFee = _sellRewardFee;
        buyRewardFee = _buyRewardFee;
    }

    function updateCharityWallet(
        address _charityWallet,
        bool _isCharityFeeBaseToken
    ) external onlyOwner {
        require(_charityWallet != address(0), "charity wallet can't be 0");
        emit UpdateCharityWallet(
            _charityWallet,
            _isCharityFeeBaseToken,
            charityWallet,
            isCharityFeeBaseToken
        );
        charityWallet = _charityWallet;
        isCharityFeeBaseToken = _isCharityFeeBaseToken;
        isExcludedFromFee[_charityWallet] = true;
    }

    function updateMinAmountToTakeFee(
        uint256 _minAmountToTakeFee
    ) external onlyOwner {
        require(_minAmountToTakeFee > 0, "minAmountToTakeFee > 0");
        emit UpdateMinAmountToTakeFee(_minAmountToTakeFee, minAmountToTakeFee);
        minAmountToTakeFee = _minAmountToTakeFee;
    }

    function setAutomatedMarketMakerPair(
        address pair,
        bool value
    ) public onlyOwner {
        _setAutomatedMarketMakerPair(pair, value);
    }

    function _setAutomatedMarketMakerPair(address pair, bool value) private {
        require(
            automatedMarketMakerPairs[pair] != value,
            "Automated market maker pair is already set to that value"
        );
        automatedMarketMakerPairs[pair] = value;
        if (value) excludeFromReward(pair);
        else includeInReward(pair);
        emit SetAutomatedMarketMakerPair(pair, value);
    }

    function excludeFromFee(address account, bool isEx) external onlyOwner {
        require(isExcludedFromFee[account] != isEx, "already");
        isExcludedFromFee[account] = isEx;
        emit ExcludedFromFee(account, isEx);
    }

    function _transfer(address from, address to, uint256 amount) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        uint256 contractTokenBalance = balanceOf(address(this));
        bool overMinimumTokenBalance = contractTokenBalance >=
            minAmountToTakeFee;

        // Take Fee
        if (
            !inSwapAndLiquify &&
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
                _burnFee = buyBurnFee;
            }
            // Sell
            else if (automatedMarketMakerPairs[to]) {
                _rewardFee = sellRewardFee;
                _liquidityFee = sellLiquidityFee;
                _charityFee = sellCharityFee;
                _burnFee = sellBurnFee;
            }
        }
        _tokenTransfer(from, to, amount);
        restoreAllFee();
    }

    function takeFee() private lockTheSwap {
        uint256 contractBalance = balanceOf(address(this));
        uint256 totalTokensTaken = _liquidityFeeTokens + (_charityFeeTokens);
        if (totalTokensTaken == 0 || contractBalance < totalTokensTaken) {
            return;
        }

        // Halve the amount of liquidity tokens
        uint256 tokensForLiquidity = _liquidityFeeTokens / 2;
        uint256 initialBaseTokenBalance = baseTokenForPair == mainRouter.WETH()
            ? address(this).balance
            : IERC20(baseTokenForPair).balanceOf(address(this));
        uint256 baseTokenForLiquidity;
        if (isCharityFeeBaseToken) {
            uint256 tokensForSwap = tokensForLiquidity + _charityFeeTokens;
            if (tokensForSwap > 0) swapTokensForBaseToken(tokensForSwap);
            uint256 baseTokenBalance = baseTokenForPair == mainRouter.WETH()
                ? address(this).balance - initialBaseTokenBalance
                : IERC20(baseTokenForPair).balanceOf(address(this)) -
                    initialBaseTokenBalance;
            uint256 baseTokenForCharity = (baseTokenBalance *
                (_charityFeeTokens)) / tokensForSwap;
            baseTokenForLiquidity = baseTokenBalance - baseTokenForCharity;
            if (baseTokenForCharity > 0) {
                if (baseTokenForPair == mainRouter.WETH()) {
                    (bool success, ) = address(charityWallet).call{
                        value: baseTokenForCharity
                    }("");
                    if (success) {
                        _charityFeeTokens = 0;
                        emit CharityFeeTaken(0, baseTokenForCharity);
                    }
                } else {
                    IERC20(baseTokenForPair).safeTransfer(
                        charityWallet,
                        baseTokenForCharity
                    );
                    _charityFeeTokens = 0;
                    emit CharityFeeTaken(0, baseTokenForCharity);
                }
            }
        } else {
            if (tokensForLiquidity > 0)
                swapTokensForBaseToken(tokensForLiquidity);
            baseTokenForLiquidity = baseTokenForPair == mainRouter.WETH()
                ? address(this).balance - initialBaseTokenBalance
                : IERC20(baseTokenForPair).balanceOf(address(this)) -
                    initialBaseTokenBalance;
            if (_charityFeeTokens > 0) {
                _transfer(address(this), charityWallet, _charityFeeTokens);
                emit CharityFeeTaken(_charityFeeTokens, 0);
                _charityFeeTokens = 0;
            }
        }

        if (tokensForLiquidity > 0 && baseTokenForLiquidity > 0) {
            addLiquidity(tokensForLiquidity, baseTokenForLiquidity);
            emit SwapAndLiquify(tokensForLiquidity, baseTokenForLiquidity);
        }

        _liquidityFeeTokens = 0;
    }

    function swapTokensForBaseToken(uint256 tokenAmount) private {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = baseTokenForPair;
        if (path[1] == mainRouter.WETH()) {
            _approve(address(this), address(mainRouter), tokenAmount);
            mainRouter.swapExactTokensForETHSupportingFeeOnTransferTokens(
                tokenAmount,
                0, // accept any amount of BaseToken
                path,
                address(this),
                block.timestamp
            );
        } else {
            _approve(address(this), address(pancakeCaller), tokenAmount);
            pancakeCaller.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    address(mainRouter),
                    tokenAmount,
                    0, // accept any amount of BaseToken
                    path,
                    block.timestamp
                );
        }
    }

    function addLiquidity(
        uint256 tokenAmount,
        uint256 baseTokenAmount
    ) private {
        _approve(address(this), address(mainRouter), tokenAmount);
        IERC20(baseTokenForPair).approve(address(mainRouter), baseTokenAmount);
        if (baseTokenForPair == mainRouter.WETH())
            mainRouter.addLiquidityETH{value: baseTokenAmount}(
                address(this),
                tokenAmount,
                0, // slippage is unavoidable
                0, // slippage is unavoidable
                address(0xdead),
                block.timestamp
            );
        else
            mainRouter.addLiquidity(
                address(this),
                baseTokenForPair,
                tokenAmount,
                baseTokenAmount,
                0,
                0,
                address(0xdead),
                block.timestamp
            );
    }

    receive() external payable {}
}
