// SPDX-License-Identifier: MIT

pragma solidity =0.8.19;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract PodToken is ERC20, Ownable {
    address public constant DEAD_ADDRESS =
        0x000000000000000000000000000000000000dEaD;
    uint256 constant DECIMAL_POINTS = 10000;
    
    uint256 public taxFees = 99;
    uint256 public antiBotBlockLimit;
    address public marketing;
    uint256 public maxPerWallet;
    address public router;
    uint256 public slippage = 200;
    uint256 public swapThreshold = 1;
    uint256 public startBlock;

    uint256 private _feesOnContract;

    error InvalidAddress();
    error InvalidNumber();
    error TransferLimitExceeded();

    event MarketingUpdated(address indexed marketing);
    event SlippageUpdated(uint256 indexed slippage);
    event TaxFeesUpdated(uint256 indexed taxFees);
    event SwapThresholdUpdated(uint256 indexed swapThreshold);
    event MaxPerWalletUpdated(uint256 indexed maxPerWallet);

    constructor(
        address _marketing,
        address _router,
        uint256 _maxPerWallet,
        uint256 _antiBotBlockLimit
    ) ERC20("The Other Party", "POD") {
        if (_marketing == address(0)) revert InvalidAddress();
        if (_antiBotBlockLimit == 0) revert InvalidNumber();
        if (_maxPerWallet == 0) revert InvalidNumber();

        _mint(msg.sender, 3_554_457_000_000 ether);

        router = _router;
        marketing = _marketing;
        maxPerWallet = _maxPerWallet;
        antiBotBlockLimit = _antiBotBlockLimit;
    }

    function _transfer(
        address _from,
        address _to,
        uint256 _amount
    ) internal virtual override {
        address _pair = _getPair(address(this), _getWETH());
        if (_to == _pair && startBlock == uint256(0)){
                startBlock = block.number;
        }

        if (
            (_from != address(this) &&
                _from != DEAD_ADDRESS &&
                _from != owner() &&
                _from != marketing) &&
            (_to != address(this) &&
                _to != DEAD_ADDRESS &&
                _to != owner() &&
                _to != marketing)
        ) {
            if (_to != _pair) {
                _checkValidTransfer(_to, _amount);
            } 

            uint256 _feeAmount = (_amount * taxFees) / DECIMAL_POINTS;

            super._transfer(_from, address(this), _feeAmount);

            _feesOnContract += _feeAmount;

            uint256 _swapThresholdAmount = totalSupply() * swapThreshold/ DECIMAL_POINTS;

            if (_from != _pair && (_feesOnContract >= _swapThresholdAmount)) {
                _swap(
                    _feesOnContract,
                    _getPath(address(this), _getWETH()),
                    marketing
                );

                _feesOnContract = 0;
            }

            return super._transfer(_from, _to, _amount - _feeAmount);
        } else return super._transfer(_from, _to, _amount);
    }

    function _checkValidTransfer(address _to, uint256 _amount) private view {
        uint256 _maxWalletAmount = ((totalSupply() * maxPerWallet) /
            DECIMAL_POINTS);
        uint256 _userBalance = balanceOf(_to);
        uint256 _validTokenTransfer = _maxWalletAmount > _userBalance
            ? _maxWalletAmount - _userBalance
            : 0;

        uint256 _transferPerBlock = totalSupply() / antiBotBlockLimit;
        uint256 _validTokenTransferPerBlock = (block.number - startBlock) *
            _transferPerBlock;

        if ((block.number <= (antiBotBlockLimit + startBlock)) && startBlock != uint256(0)) {
            if (_amount > _validTokenTransferPerBlock)
                revert TransferLimitExceeded();
        }
        if (_amount > _validTokenTransfer) revert TransferLimitExceeded();
    }

    function _getFactory() private view returns (address) {
        return IUniswapV2Router02(router).factory();
    }

    function _getWETH() private view returns (address) {
        return IUniswapV2Router02(router).WETH();
    }

    function _getPair(
        address _tokenA,
        address _tokenB
    ) private view returns (address) {
        return IUniswapV2Factory(_getFactory()).getPair(_tokenA, _tokenB);
    }

    function _getPath(
        address _tokenA,
        address _tokenB
    ) private view returns (address[] memory) {
        address[] memory _path;
        address WETH = _getWETH();

        if (_tokenA == WETH || _tokenB == WETH) {
            _path = new address[](2);
            _path[0] = _tokenA;
            _path[1] = _tokenB;
        } else {
            _path = new address[](3);
            _path[0] = _tokenA;
            _path[1] = WETH;
            _path[2] = _tokenB;
        }

        return _path;
    }

    function _swap(
        uint256 _amountIn,
        address[] memory _path,
        address _to
    ) private {
        if (_amountIn > 0) {
            IERC20(_path[0]).approve(router, _amountIn);

            uint256 _amountOutMin = (IUniswapV2Router02(router).getAmountsOut(
                _amountIn,
                _path
            )[_path.length - 1] * (DECIMAL_POINTS - slippage)) / DECIMAL_POINTS;

            IUniswapV2Router02(router)
                .swapExactTokensForTokensSupportingFeeOnTransferTokens(
                    _amountIn,
                    _amountOutMin,
                    _path,
                    _to,
                    block.timestamp
                );
        }
    }

    function updateSwapThreshold(
        uint256 _swapThreshold
    ) external onlyOwner {
        if (_swapThreshold == 0) revert InvalidNumber();
        swapThreshold = _swapThreshold;

        emit SwapThresholdUpdated(_swapThreshold);
    }

    function updateTaxFees(
        uint256 _taxFees
    ) external onlyOwner {
        if (_taxFees == 0) revert InvalidNumber();
        taxFees = _taxFees;

        emit TaxFeesUpdated(_taxFees);
    }

    function updateMarketing(address _marketing) external onlyOwner {
        if (_marketing == address(0)) revert InvalidAddress();
        marketing = _marketing;

        emit MarketingUpdated(_marketing);
    }

    function updateMaxPerWallet(uint256 _maxPerWallet) external onlyOwner {
        if (_maxPerWallet == 0) revert InvalidNumber();
        maxPerWallet = _maxPerWallet;

        emit MaxPerWalletUpdated(_maxPerWallet);
    }

    function updateSlippage(uint256 _slippage) external onlyOwner {
        slippage = _slippage;

        emit SlippageUpdated(_slippage);
    }
}
