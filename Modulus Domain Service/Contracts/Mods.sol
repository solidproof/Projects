// SPDX-License-Identifier: MIT
pragma solidity =0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./Liquidity.sol";

contract ModulusDomains is ERC20, Ownable {
    uint private _feesOnContract;
    uint private _slippage;

    address public cult;
    uint public cultAllocation;

    address public development;
    uint public developmentAllocation;

    address public marketing;
    uint public marketingAllocation;

    uint public buyTax = 400;
    uint public sellTax = 800;

    uint public perWalletHoldingPercent;

    error InvalidAddress();
    error InvalidAllocation();
    error InvalidPercent();
    error InvalidTax();
    error TransferLimitExceeded();

    event AllocationsUpdated(
        uint cultAllocation,
        uint developmentAllocation,
        uint marketingAllocation
    );
    event BuyTax(uint buyTax);
    event SellTax(uint sellTax);
    event Cult(address cult);
    event Development(address development);
    event Marketing(address marketing);
    event PerWalletHoldingPercent(uint perWalletHoldingPercent);

    constructor(
        string memory _name,
        string memory _symbol,
        uint _supply,
        address _cult,
        uint _cultAllocation,
        address _development,
        uint _developmentAllocation,
        address _marketing,
        uint _marketingAllocation,
        uint _perWalletHoldingPercent
    ) ERC20(_name, _symbol) {
        if (
            _cult == address(0) ||
            _development == address(0) ||
            _marketing == address(0)
        ) revert InvalidAddress();

        if (
            _cultAllocation == 0 ||
            _developmentAllocation == 0 ||
            _marketingAllocation == 0 ||
            _cultAllocation + _developmentAllocation + _marketingAllocation !=
            Liquidity.MAX_PRECENT
        ) revert InvalidAllocation();

        if (
            _perWalletHoldingPercent == 0 ||
            _perWalletHoldingPercent > Liquidity.MAX_PRECENT
        ) {
            revert InvalidPercent();
        }

        _mint(msg.sender, _supply);

        cult = _cult;
        cultAllocation = _cultAllocation;

        marketing = _marketing;
        marketingAllocation = _marketingAllocation;

        development = _development;
        developmentAllocation = _developmentAllocation;

        _slippage = sellTax + Liquidity.MIN_PERCENT;
        perWalletHoldingPercent = _perWalletHoldingPercent;
    }

    function isValidTransfer(uint _amount, address _to)
        private
        view
        returns (bool)
    {
        uint validTokenTransfer = ((totalSupply() * perWalletHoldingPercent) /
            Liquidity.MAX_PRECENT) - balanceOf(_to);

        return _amount <= validTokenTransfer;
    }

    function _transfer(
        address from,
        address to,
        uint amount
    ) internal virtual override {
        address pair = Liquidity.getPair(address(this), Liquidity.WETH);

        if (
            to != pair &&
            to != address(this) &&
            to != owner() &&
            to != development &&
            to != marketing &&
            to != Liquidity.DEAD_ADDRESS
        )
            if (!isValidTransfer(amount, to)) revert TransferLimitExceeded();

        if (
            (pair == to && from != address(this) && from != owner()) ||
            (pair == from && to != address(this) && to != owner())
        ) {
            uint tax = from == pair ? buyTax : sellTax;

            uint feeAmount = (amount * tax) / Liquidity.MAX_PRECENT;
            super._transfer(from, address(this), feeAmount);

            _feesOnContract += feeAmount;

            if (from != pair) {
                uint _totalAllocation = cultAllocation +
                    developmentAllocation +
                    marketingAllocation;

                uint _cultAllocation = (_feesOnContract * cultAllocation) /
                    _totalAllocation;
                uint _developmentAllocation = (_feesOnContract *
                    developmentAllocation) / _totalAllocation;
                uint _marketingAllocation = _feesOnContract -
                    (_cultAllocation + _developmentAllocation);

                _buyBack(cult, Liquidity.DEAD_ADDRESS, _cultAllocation);
                _buyBack(Liquidity.WETH, development, _developmentAllocation);
                _buyBack(Liquidity.WETH, marketing, _marketingAllocation);

                _feesOnContract = 0;
            } else {
                if (!isValidTransfer(amount, to))
                    revert TransferLimitExceeded();
            }

            return super._transfer(from, to, amount - feeAmount);
        } else return super._transfer(from, to, amount);
    }

    function _buyBack(
        address _tokenOut,
        address _to,
        uint _amountIn
    ) private {
        if (_amountIn > 0) {
            Liquidity.swap(address(this), _tokenOut, _amountIn, _slippage, _to);
        }
    }

    function updateBuyTax(uint _tax) external onlyOwner {
        if (_tax == 0 || _tax > Liquidity.MAX_PRECENT) revert InvalidTax();

        buyTax = _tax;

        emit BuyTax(_tax);
    }

    function updateSellTax(uint _tax) external onlyOwner {
        if (_tax == 0 || _tax > Liquidity.MAX_PRECENT) revert InvalidTax();

        sellTax = _tax;
        _slippage = _tax + Liquidity.MIN_PERCENT;

        emit SellTax(_tax);
    }

    function updateCult(address _token) external onlyOwner {
        if (_token == address(0)) revert InvalidAddress();

        cult = _token;

        emit Cult(_token);
    }

    function updateDevelopment(address _account) external onlyOwner {
        if (_account == address(0)) revert InvalidAddress();

        development = _account;

        emit Development(_account);
    }

    function updateMarketing(address _account) external onlyOwner {
        if (_account == address(0)) revert InvalidAddress();

        marketing = _account;

        emit Marketing(_account);
    }

    function updateAllocations(
        uint _cultAllocation,
        uint _developmentAllocation,
        uint _marketingAllocation
    ) external onlyOwner {
        if (
            _cultAllocation == 0 ||
            _developmentAllocation == 0 ||
            _marketingAllocation == 0 ||
            _cultAllocation + _developmentAllocation + _marketingAllocation !=
            Liquidity.MAX_PRECENT
        ) revert InvalidAllocation();

        cultAllocation = _cultAllocation;
        developmentAllocation = _developmentAllocation;
        marketingAllocation = _marketingAllocation;

        emit AllocationsUpdated(
            cultAllocation,
            developmentAllocation,
            marketingAllocation
        );
    }

    function updatePerWalletHoldingPercent(uint _perWalletHoldingPercent)
        external
        onlyOwner
    {
        if (
            _perWalletHoldingPercent == 0 ||
            _perWalletHoldingPercent > Liquidity.MAX_PRECENT
        ) revert InvalidPercent();

        perWalletHoldingPercent = _perWalletHoldingPercent;

        emit PerWalletHoldingPercent(perWalletHoldingPercent);
    }
}
