// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

interface IUniswapV2Router01 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);
}

interface IUniswapV2Router02 is IUniswapV2Router01 {}

interface IUniswapV2Factory {
    event PairCreated(
        address indexed token0,
        address indexed token1,
        address pair,
        uint
    );

    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);

    function createPair(
        address tokenA,
        address tokenB
    ) external returns (address pair);
}

contract MPOD is ERC20, ERC20Burnable {
    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;

    mapping(address => bool) private _isAutomatedMarketMakerPair;
    mapping(address => bool) private _isExcludedFromFees;

    address public immutable feeReceiver1; // Address to receive the fees
    address public immutable feeReceiver2; // Address to receive the fees
    uint16 public immutable SELL_FEE = 300; // Sell fee ratio (Default: 3%)
    uint16 public immutable DIVIDER = 10_000; // Divider

    constructor() ERC20("MPOD", "MPOD") {
        address router = 0x10ED43C718714eb63d5aA57B78B54704E256024E;
        uniswapV2Router = IUniswapV2Router02(router);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
                address(this),
                uniswapV2Router.WETH()
            );

        _isAutomatedMarketMakerPair[address(uniswapV2Pair)] = true;

        feeReceiver1 = 0x1E204452c006d467E99d6422F21c0338fF221C1c;
        feeReceiver2 = 0x44C8F546eEcFEf283ef8aaa7Eee39dB53178e279;

        _isExcludedFromFees[msg.sender] = true;
        _isExcludedFromFees[feeReceiver1] = true;
        _isExcludedFromFees[feeReceiver2] = true;

        _mint(msg.sender, 1_000_000_000 * 10 ** decimals());
    }

    function _update(
        address from,
        address to,
        uint256 amount
    ) internal override {
        uint256 fee = 0;

        if (!_isExcludedFromFees[from]) {
            // If to == marketPairs::true state, then it is a sell transfer
            if (_isAutomatedMarketMakerPair[to]) {
                fee = ((amount * SELL_FEE) / DIVIDER);
            }
        }

        if (fee > 0) {
            _distributeFees(from, fee);
            amount -= fee;
        }

        super._update(from, to, amount);
    }

    /**
     * @dev Distributes fees to the fee receiver wallets.
     * @param from The address from which the fees are collected.
     * @param amount The total fee amount to be distributed.
     */
    function _distributeFees(address from, uint256 amount) internal {
        // Calculate the fee receiver #1 amount (75%)
        uint256 fee1 = (amount * 7_500) / DIVIDER;

        // Calculate the fee receiver #2 amount (25%)
        uint256 fee2 = amount - fee1;

        // Transfer the fee to the fee receiver #1 wallet
        super._transfer(from, feeReceiver1, fee1);

        // Transfer the fee to the fee receiver #2 wallet
        super._transfer(from, feeReceiver2, fee2);
    }
}