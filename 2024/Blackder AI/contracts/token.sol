import "@openzeppelin/contracts@4.8.2/access/Ownable.sol";
import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "./IUniswapV2Router02.sol";
import "./safeMath.sol";

/*
   Website: https://blackder.ai/
   Twitter(X): https://twitter.com/blackder_ai
   Telegram: https://t.me/blackder_ai
*/

// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.25;

contract BlackderAi is 
    Context,
    IERC20,
    Ownable
{
    using SafeMath for uint256;

    uint256 private _rTotal = (MAX - (MAX % _totalSupply));
    uint256 private constant MAX = ~uint256(0);

    uint256 private _feeOnBuy = 5;
    uint256 private _feeOnSell = 5;

    uint256 private _tempFee = _fee;
    uint256 private _fee = _feeOnSell;

    address payable private _marketingWallet =
        payable(0xe85e3a6EA4432f2CD44d3FCc8C73828d7ab89149); 

    mapping(address => uint256) private _rOwned;

    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private _isExcludedFromFee;

    uint8 private constant _decimals = 9;

    string private constant _name = "Blackder AI"; 
    string private constant _symbol = "BLD"; 

    bool private _maxTxn = false;
    bool private _maxWallet = false;

    IUniswapV2Router02 public uniswapV2Router =
        IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address public uniswapV2Pair;

    bool private autoSwapEnabled = true;
    bool private inSwap = false;
    bool private _tradingOpen;

    uint256 private constant _totalSupply = 100_000_000 * 10**9; 
    uint256 public _maxTxnSize = 1_000_000 * 10**9;
    uint256 public _maxHoldSize = 2_000_000 * 10**9;
    uint256 public _minSwappableAmount = 1000 * 10**9;

    modifier lockTheSwap() {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor() {
        _isExcludedFromFee[address(this)] = true;
        _isExcludedFromFee[owner()] = true;
        _isExcludedFromFee[_marketingWallet] = true;

        _rOwned[_msgSender()] = _rTotal;

        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
            address(this),
            uniswapV2Router.WETH()
        );

        emit Transfer(address(0), _msgSender(), _totalSupply);
    }

    function totalSupply() public pure override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return tokenFromReflection(_rOwned[account]);
    }

    function excludeMultipleAccountsFromFees(
        address[] calldata accounts,
        bool excluded
    ) public onlyOwner {
        for (uint256 i = 0; i < accounts.length; i++) {
            _isExcludedFromFee[accounts[i]] = excluded;
        }
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function _getTValues(uint256 tAmount, uint256 fee)
        private
        pure
        returns (uint256, uint256)
    {
        uint256 tTeam = tAmount.mul(fee).div(100);
        uint256 tTransferAmount = tAmount.sub(tTeam);
        return (tTransferAmount, tTeam);
    }

    function _getCurrentSupply() private view returns (uint256, uint256) {
        return (_rTotal, _totalSupply);
    }

    function toggleautoSwapEnabled(bool _autoSwapEnabled) public onlyOwner {
        autoSwapEnabled = _autoSwapEnabled;
    }

    function allowance(address owner, address spender)
        public
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

    function tokenFromReflection(uint256 rAmount)
        private
        view
        returns (uint256)
    {
        require(
            rAmount <= _rTotal,
            "Amount has to be less than total reflections"
        );
        uint256 currentRate = _getRate();
        return rAmount.div(currentRate);
    }

    function switchTrading(bool __tradingOpen) public onlyOwner {
        _tradingOpen = __tradingOpen;
    }

    function dropFee() private {
        if (_fee == 0) return;

        _tempFee = _fee;

        _fee = 0;
    }

    function restoreFee() private {
        _fee = _tempFee;
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "Can't approve from zero address");
        require(spender != address(0), "Can't approve to zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "Cant transfer from address zero");
        require(to != address(0), "Cant transfer to address zero");
        require(amount > 0, "Amount should be above zero");

        if (from != owner() && to != owner()) {
            //Trade start check
            if (!_tradingOpen) {
                require(
                    from == owner(),
                    "Only owner can trade before trading activation"
                );
            }

            require(amount <= _maxTxnSize, "Exceeded max transaction limit");

            if (to != uniswapV2Pair) {
                require(
                    balanceOf(to) + amount < _maxHoldSize,
                    "Exceeds max hold balance"
                );
            }

            uint256 contractTokenBalance = balanceOf(address(this));
            bool swapAllowed = contractTokenBalance >= _minSwappableAmount;

            if (contractTokenBalance >= _maxTxnSize) {
                contractTokenBalance = _maxTxnSize;
            }

            if (
                swapAllowed &&
                autoSwapEnabled &&
                from != uniswapV2Pair &&
                !_isExcludedFromFee[from] &&
                !inSwap &&
                !_isExcludedFromFee[to]
            ) {
                swap2Eth(contractTokenBalance);
                uint256 contractETHBalance = address(this).balance;
                if (contractETHBalance > 0) {
                    _sendFeesToMarketing(address(this).balance);
                }
            }
        }

        bool takeFee = true;

        if (
            (_isExcludedFromFee[to] || _isExcludedFromFee[from]) ||
            (to != uniswapV2Pair && from != uniswapV2Pair)
        ) {
            takeFee = false;
        } else {
            if (from == uniswapV2Pair && to != address(uniswapV2Router)) {
                _fee = _feeOnBuy;
            }

            if (to == uniswapV2Pair && from != address(uniswapV2Router)) {
                _fee = _feeOnSell;
            }
        }

        _tokenTransfer(from, to, amount, takeFee);
    }

    function swap2Eth(uint256 tokenAmount) private lockTheSwap {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function manualswap() external {
        require(_msgSender() == _marketingWallet);
        uint256 contractBalance = balanceOf(address(this));
        swap2Eth(contractBalance);
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "the transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function setMinSwapTokensThreshold(uint256 minSwappableAmount)
        public
        onlyOwner
    {
        _minSwappableAmount = minSwappableAmount;
    }

    function setFees(uint256 feeOnBuy, uint256 feeOnSell) public onlyOwner {
        require(
            feeOnBuy >= 0 && feeOnBuy <= 95,
            "Buy tax must be between 0% and 95%"
        );
        require(
            feeOnSell >= 0 && feeOnSell <= 95,
            "Sell tax must be between 0% and 95%"
        );

        _feeOnBuy = feeOnBuy;
        _feeOnSell = feeOnSell;
    }

    function _transferApplyingFees(
        address sender,
        address recipient,
        uint256 tAmount
    ) private {
        (
            uint256 rAmount,
            uint256 rTransferAmount,
            uint256 tTransferAmount,
            uint256 tTeam
        ) = _getFeeValues(tAmount);
        _rOwned[sender] = _rOwned[sender].sub(rAmount);
        _rOwned[recipient] = _rOwned[recipient].add(rTransferAmount);
        _transferFeeDev(tTeam);
        emit Transfer(sender, recipient, tTransferAmount);
    }

    function _tokenTransfer(
        address sender,
        address recipient,
        uint256 amount,
        bool takeFee
    ) private {
        if (!takeFee) dropFee();
        _transferApplyingFees(sender, recipient, amount);
        if (!takeFee) restoreFee();
    }

    function _transferFeeDev(uint256 tTeam) private {
        uint256 currentRate = _getRate();
        uint256 rTeam = tTeam.mul(currentRate);
        _rOwned[address(this)] = _rOwned[address(this)].add(rTeam);
    }

    function _getFeeValues(uint256 tAmount)
        private
        view
        returns (
            uint256,
            uint256,
            uint256,
            uint256
        )
    {
        (uint256 tTransferAmount, uint256 tTeam) = _getTValues(tAmount, _fee);
        uint256 currentRate = _getRate();
        (uint256 rAmount, uint256 rTransferAmount) = _getRValues(
            tAmount,
            tTeam,
            currentRate
        );
        return (rAmount, rTransferAmount, tTransferAmount, tTeam);
    }

    function setMaxTxnAmount(uint256 maxTxAmount) public onlyOwner {
        _maxTxnSize = maxTxAmount;
    }

    receive() external payable {}

    function setMaxHoldSize(uint256 maxHoldSize) public onlyOwner {
        _maxHoldSize = maxHoldSize;
    }

    function _getRValues(
        uint256 tAmount,
        uint256 tTeam,
        uint256 currentRate
    ) private pure returns (uint256, uint256) {
        uint256 rAmount = tAmount.mul(currentRate);
        uint256 rTeam = tTeam.mul(currentRate);
        uint256 rTransferAmount = rAmount.sub(rTeam);
        return (rAmount, rTransferAmount);
    }

    function _sendFeesToMarketing(uint256 amount) private {
        _marketingWallet.transfer(amount);
    }

    function manualSwap() external {
        require(_msgSender() == _marketingWallet);
        uint256 contractETHBalance = address(this).balance;
        _sendFeesToMarketing(contractETHBalance);
    }

    function _getRate() private view returns (uint256) {
        (uint256 rSupply, uint256 tSupply) = _getCurrentSupply();
        return rSupply.div(tSupply);
    }
}