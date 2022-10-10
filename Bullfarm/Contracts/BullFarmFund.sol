// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./interfaces/IUshiToken.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

contract BullFarmFund is Ownable {
    uint public constant INITIAL_ETH_LIQUIDITY = 3 ether;
    uint public constant MAX_INITIAL_BUY = 0.5 ether;
    uint public constant BUY_TIMEOUT = 1 days;

    IUshiToken public token;
    IUniswapV2Router02 public uniswapV2Router;
    bool public initialLiquidityAdded;
    uint public lastBuyTimestamp;
    address public manager;

    constructor(IUniswapV2Router02 _uniswapV2Router) {
        uniswapV2Router = _uniswapV2Router;
    }

    receive() external payable {}

    function initLiquidityPool(IUshiToken _token) external onlyOwner {
        require(!initialLiquidityAdded, "BullFarmFund: liquidity is already added");
        require(address(this).balance >= INITIAL_ETH_LIQUIDITY, "BullFarmFund: not enough ETH liquidity");

        // Save token
        require(address(_token) != address(0), "BullFarmFund: invalid token address");
        token = _token;

        // Approve token transfer
        uint tokenAmount = token.balanceOf(address(this));
        require(tokenAmount > 0, "BullFarmFund: no tokens to liquify");
        token.approve(address(uniswapV2Router), tokenAmount);

        // Add the liquidity
        uniswapV2Router.addLiquidityETH{value: INITIAL_ETH_LIQUIDITY} (
            address(token),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            owner(),
            block.timestamp
        );
        initialLiquidityAdded = true;
        lastBuyTimestamp = block.timestamp;

        // Buy tokens right after token listing
        if (address(this).balance > 0) {
            uint ethAmount = address(this).balance > MAX_INITIAL_BUY ? MAX_INITIAL_BUY : address(this).balance;
            buy(ethAmount);
        }

        // Enable Anti Whale protection
        token.enableAntiWhale();
    }

    function buy(uint ethValue) public {
        require(msg.sender == owner() || block.timestamp - lastBuyTimestamp >= BUY_TIMEOUT, "BullFarmFund: access restricted");
        require(initialLiquidityAdded, "BullFarmFund: liquidity is not added");
        require(ethValue > 0, "BullFarmFund: invalid ETH value");
        require(address(this).balance >= ethValue, "BullFarmFund: not enough ETH");

        // Buy tokens from liquidity pool
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = address(token);

        uniswapV2Router.swapExactETHForTokens{value: ethValue} (
            0,
            path,
            address(this),
            block.timestamp
        );

        lastBuyTimestamp = block.timestamp;
    }

    function sendTokens(address to, uint ethAmount) external {
        require(msg.sender == manager, "BullFarmFund: access restricted");
        address[] memory path = new address[](2);
        path[0] = address(token);
        path[1] = uniswapV2Router.WETH();

        uint[] memory outs = uniswapV2Router.getAmountsIn(ethAmount, path);
        token.transfer(to, outs[0]);
    }

    function setTokenManager(address _manager) external onlyOwner {
        require(manager == address(0), "BullFarmFund: manager is already set");
        manager = _manager;
    }
}