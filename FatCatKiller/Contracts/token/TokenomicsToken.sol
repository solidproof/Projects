// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./ERC20.sol";
import "./ITokenomicsToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";

contract TokenomicsToken is ITokenomicsToken, ERC20, Ownable {
    mapping(address => bool) private _isFeeExempt;
    ITokenomicsStrategy private _strategy;
    address private _dexPair;

    uint8 constant FEE_EXEMPT = 0;
    uint8 constant TRANSFER = 1;
    uint8 constant BUY = 2;
    uint8 constant SELL = 3;

    uint16 private _feeDenominator = 1000;
    uint256 private _minTokenomicsBurnAmount = 9 * (10**12) * (10**decimals()); // 9 000 000 000 000

    uint8 private _maxSellBuyFee = 55; // 5.5%
    uint8 private _sellBuyBurnFee = 35; // 3.5%
    uint8 private _sellBuyCharityFee = 5; // 0.5%
    uint8 private _sellBuyOperatingFee = 30; // 3%
    uint8 private _sellBuyMarketingFee = 20; // 2%

    uint8 private _maxTransferFee = 110; // 11%
    uint8 private _transferBurnFee = 70; // 7%
    uint8 private _transferCharityFee = 10; // 1%
    uint8 private _transferOperatingFee = 60; // 6%
    uint8 private _transferMarketingFee = 40; // 4%

    constructor(string memory name_, string memory symbol_)
        ERC20(name_, symbol_)
    {
        _isFeeExempt[address(this)] = true;
    }

    function feeDenominator() external view override returns (uint16) {
        return _feeDenominator;
    }

    function maxSellBuyFee() external view override returns (uint8) {
        return _maxSellBuyFee;
    }

    function sellBuyBurnFee() external view override returns (uint8) {
        return totalSupply() > _minTokenomicsBurnAmount ? _sellBuyBurnFee : 0;
    }

    function sellBuyCharityFee() external view override returns (uint8) {
        return _sellBuyCharityFee;
    }

    function sellBuyOperatingFee() external view override returns (uint8) {
        return _sellBuyOperatingFee;
    }

    function sellBuyMarketingFee() external view override returns (uint8) {
        return _sellBuyMarketingFee;
    }

    function sellBuyTotalFee() external view override returns (uint8) {
        return
            this.sellBuyBurnFee() +
            _sellBuyCharityFee +
            _sellBuyOperatingFee +
            _sellBuyMarketingFee;
    }

    function setSellBuyFee(
        uint8 sellBuyCharityFee_,
        uint8 sellBuyOperatingFee_,
        uint8 sellBuyMarketingFee_
    ) external override onlyOwner {
        uint8 total = sellBuyCharityFee_ +
            sellBuyOperatingFee_ +
            sellBuyMarketingFee_;
        require(
            total <= _maxSellBuyFee,
            "TokenomicsToken: Total fee should be less or equal max fee"
        );
        _sellBuyCharityFee = sellBuyCharityFee_;
        _sellBuyOperatingFee = sellBuyOperatingFee_;
        _sellBuyMarketingFee = sellBuyMarketingFee_;
    }

    function maxTransferFee() external view override returns (uint8) {
        return _maxTransferFee;
    }

    function transferBurnFee() external view override returns (uint8) {
        return totalSupply() > _minTokenomicsBurnAmount ? _transferBurnFee : 0;
    }

    function transferCharityFee() external view override returns (uint8) {
        return _transferCharityFee;
    }

    function transferOperatingFee() external view override returns (uint8) {
        return _transferOperatingFee;
    }

    function transferMarketingFee() external view override returns (uint8) {
        return _transferMarketingFee;
    }

    function transferTotalFee() external view override returns (uint8) {
        return
            this.transferBurnFee() +
            _transferCharityFee +
            _transferOperatingFee +
            _transferMarketingFee;
    }

    function setTransferFee(
        uint8 transferCharityFee_,
        uint8 transferOperatingFee_,
        uint8 transferMarketingFee_
    ) external override onlyOwner {
        uint8 total = 
            transferCharityFee_ +
            transferOperatingFee_ +
            transferMarketingFee_;
        require(
            total <= _maxTransferFee,
            "TokenomicsToken: Total fee should be less or equal max fee"
        );
        _transferCharityFee = transferCharityFee_;
        _transferOperatingFee = transferOperatingFee_;
        _transferMarketingFee = transferMarketingFee_;
    }

    function process() external override onlyOwner {
        _strategy.process();
    }

    function isFeeExempt(address account)
        external
        view
        override
        returns (bool)
    {
        return _isFeeExempt[account];
    }

    function setFeeExempt(address account, bool exempt) external override {
        _isFeeExempt[account] = exempt;
    }

    function dexPair() external view override returns (address) {
        return _dexPair;
    }

    function setDexPair(address dexPair_) external override onlyOwner {
        _dexPair = dexPair_;
    }

    function strategy()
        external
        view
        override
        returns (ITokenomicsStrategy strategy_)
    {
        return _strategy;
    }

    function setStrategy(ITokenomicsStrategy strategy_)
        external
        override
        onlyOwner
    {
        require(
            address(strategy_) != address(0),
            "TokenomicsToken: Wrong strategy contract address"
        );
        if (address(_strategy) != address(0)) {
            _approve(address(this), address(_strategy), 0);
        }
        _strategy = strategy_;
        _approve(address(this), address(_strategy), type(uint256).max);
    }

    function burn(uint256 amount) external override {
        _burn(msg.sender, amount);
        emit Burnt(msg.sender, amount);
    }

    function burnFrom(address account, uint256 amount) external override {
        uint256 currentAllowance = allowance(account, msg.sender);
        require(
            currentAllowance >= amount,
            "ERC20: burn amount exceeds allowance"
        );
        unchecked {
            _approve(account, msg.sender, currentAllowance - amount);
        }
        _burn(account, amount);
        emit Burnt(account, amount);
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal virtual override {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");

        _beforeTokenTransfer(sender, recipient, amount);

        uint256 senderBalance = _balances[sender];

        uint8 transferType = _transferFeeType(sender, recipient);
        uint256 fee = _calcFee(transferType, amount);
        uint256 totalAmount = amount;
        if (transferType == TRANSFER || transferType == SELL) {
            totalAmount += fee;
            _balances[address(this)] += fee;
            emit FeePayment(sender, fee);
        }

        require(
            senderBalance >= totalAmount,
            "ERC20: transfer amount exceeds balance"
        );
        unchecked {
            _balances[sender] = senderBalance - totalAmount;
        }

        totalAmount = amount;
        if (transferType == BUY) {
            totalAmount -= fee;
            _balances[address(this)] += fee;
            emit FeePayment(sender, fee);
        }

        _balances[recipient] += totalAmount;
        emit Transfer(sender, recipient, amount);

        _burnFee(transferType, amount);

        _afterTokenTransfer(sender, recipient, amount);
    }

    function _transferFeeType(address from, address to)
        internal
        view
        returns (uint8)
    {
        if (_isFeeExempt[from] || _isFeeExempt[to]) return FEE_EXEMPT;
        if (from == _dexPair) return BUY;
        if (to == _dexPair) return SELL;
        return TRANSFER;
    }

    function _calcFee(uint8 transferType, uint256 amount)
        internal
        view
        returns (uint256)
    {
        uint256 fee = 0;
        if (transferType == TRANSFER) {
            fee = Math.ceilDiv(
                amount * this.transferTotalFee(),
                _feeDenominator
            );
        } else if (transferType == BUY || transferType == SELL) {
            fee = Math.ceilDiv(
                amount * this.sellBuyTotalFee(),
                _feeDenominator
            );
        }
        return fee;
    }

    function _burnFee(uint8 transferType, uint256 amount) internal {
        uint256 fee = 0;
        if (transferType == TRANSFER) {
            fee = Math.ceilDiv(
                amount * this.transferBurnFee(),
                _feeDenominator
            );
        } else if (transferType == BUY || transferType == SELL) {
            fee = Math.ceilDiv(amount * this.sellBuyBurnFee(), _feeDenominator);
        }
        if (fee > 0) this.burn(fee);
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._beforeTokenTransfer(from, to, amount);
        require(
            address(_strategy) != address(0),
            "TokenomicsToken: Tokenomics distribution strategy is not set"
        );
    }

    function _afterTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal virtual override {
        super._afterTokenTransfer(from, to, amount);
        _strategy.process();
    }
}
