// SPDX-License-Identifier: MIT
pragma solidity 0.8.15;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol";
import "@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol";

import "./IEcosystem.sol";

contract Sinja is Context, ERC20, AccessControl, ReentrancyGuard {
    using SafeERC20 for IERC20;
    using Address for address;

    IUniswapV2Router02 public uniswapV2Router;

    bytes32 public constant ECO_PROJECT_MANAGER = keccak256("ECO_PROJECT_MANAGER");

    uint256 private maxWallet;
    uint256 private maxWalletTimer;
    uint256 private maxSupply;
    uint256 private started;
    uint256 private ecoCounter;

    uint256 public totalBuyFee;
    uint256 public totalSellFee;
    uint256 private sellDevFee;
    uint256 private sellMarketingFee;
    uint256 private buyDevFee;
    uint256 private buyMarketingFee;

    address payable devWallet1;
    address payable devWallet2;
    address payable devWallet3;
    address payable marketingWallet;
    address[] public ecoProjects;

    bool private swapping;

    mapping (address => bool) private isBlacklisted;
    mapping (address => bool) private isExcluded;
    mapping(address => bool) public pair;

    event blacklistedAddress(address Blacklisted);

    constructor(address _devWallet1, address _devWallet2, address _devWallet3 , address payable _marketingWallet) ERC20 ("Sinja Stealth Network", "SINJA") payable {
        uniswapV2Router = IUniswapV2Router02(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
        address _uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());
        pair[_uniswapV2Pair] = true;

        maxSupply = 1 * 10 ** 12 * 10 ** decimals();

        maxWallet = (maxSupply * 69 )/ 10000;
        maxWalletTimer = block.timestamp + 1 weeks;
        _setupRole(ECO_PROJECT_MANAGER, msg.sender);

        buyDevFee = 2;
        buyMarketingFee = 1;
        sellDevFee = 3;
        sellMarketingFee = 2;
        totalBuyFee = buyDevFee + buyMarketingFee;
        totalSellFee = sellDevFee + sellMarketingFee;

        devWallet1 = payable(_devWallet1);
        devWallet2 = payable(_devWallet2);
        devWallet3 = payable(_devWallet3);
        marketingWallet = payable(_marketingWallet);

        isExcluded[marketingWallet] = true;
        isExcluded[msg.sender] = true;
        isExcluded[address(this)] = true;

        _mint(msg.sender, maxSupply);
    }

    receive() external payable {
    }

    function ecoSwapPercentsView() public view returns (address[] memory projects, uint256[] memory percentages) {
        uint256 projectCount = ecoProjects.length;
        if (projectCount > ecoCounter + 100) {
            projectCount = ecoCounter + 100;
        }

        projects = new address[](projectCount - ecoCounter);
        percentages = new uint256[](projectCount - ecoCounter);

        for (uint256 i = ecoCounter; i < projectCount; i++) {
            IEcosystem ecosystem = IEcosystem(payable(address(ecoProjects[i])));
            projects[i - ecoCounter] = ecoProjects[i];
            percentages[i - ecoCounter] = ecosystem.getSwapPercent();
        }

        return (projects, percentages);
    }

    function addEcoProject(address payable _project) external onlyRole(ECO_PROJECT_MANAGER) {
        ecoProjects.push(_project);
    }

    function addPair(address _pair) external onlyRole(ECO_PROJECT_MANAGER) {
        require(!pair[_pair], "This pair already exists");

        pair[_pair] = true;
    }

    function blacklistBot(address[] memory _address) public onlyRole(ECO_PROJECT_MANAGER) {
        require(block.timestamp <= maxWalletTimer, "Blacklisting Address has been Disabled");
        
        for(uint256 i = 0; i < _address.length; i++) {
            isBlacklisted[_address[i]] = true;

            emit blacklistedAddress(_address[i]);
        }
    }

    function burn(uint256 amount) public {
        _burn(msg.sender, amount);
    }

    function checkSwapAmount() public view returns(uint256 swapAmount) {
        swapAmount = ((totalSupply() * 25) / 10000);
    }

    // Override _transfer function to implement custom logic
    function _transfer(
        address from,
        address to,
        uint256 amount
    ) internal override {
        // Ensure non-zero addresses
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        // Ensure addresses are not blacklisted
        require(!isBlacklisted[from] && !isBlacklisted[to], "Address is blacklisted");

        // Enforce max wallet amount, except for certain addresses
        if((block.timestamp < maxWalletTimer) && !pair[to] && !isExcluded[from] && !isExcluded[to]) {
            uint256 balance = balanceOf(to);
            require(balance + amount <= maxWallet, "Transfer amount exceeds the maxWallet");
        }

        uint256 contractTokenBalance = balanceOf(address(this));
        uint256 swapAmount = checkSwapAmount();
        bool canSwap = contractTokenBalance >= swapAmount;

        // Swap tokens for ETH when threshold is reached and not in the middle of a swap
        if(canSwap && !swapping && pair[to] && from != address(uniswapV2Router) && !isExcluded[to] && !isExcluded[from]) {

            swapping = true;
            bool success;

            swapTokensForEth(swapAmount);

            uint256 contractETHBalance = address(this).balance;
            uint256 devAmount = (contractETHBalance * sellDevFee) / totalSellFee;
            devAmount /= 3;

            
            (success, ) = address(devWallet1).call{value: devAmount}("");
            require(success, "Failed to send taxes to marketing wallet");

            (success, ) = address(devWallet2).call{value: devAmount}("");
            require(success, "Failed to send taxes to marketing wallet");

            (success, ) = address(devWallet3).call{value: devAmount}("");
            require(success, "Failed to send taxes to marketing wallet");

            (success, ) = address(marketingWallet).call{value: address(this).balance}("");
            require(success, "Failed to send taxes to marketing wallet");

            swapping = false;
        }

        bool takeFee = !swapping;

        if(isExcluded[from] || isExcluded[to]) {
            takeFee = false;
            super._transfer(from, to, amount);
        }

        else if(!pair[to] && !pair[from]) {
            takeFee = false;
            super._transfer(from, to, amount);
        }

        if(takeFee) {

            uint256 BuyFees = ((amount * totalBuyFee) / 100);
            uint256 SellFees = ((amount * totalSellFee) / 100);

            // if sell
            if(!pair[to] && totalSellFee > 0) {
                amount -= SellFees;
                super._transfer(from, address(this), SellFees);
                super._transfer(from, to, amount);
            }
            // if buy transfer
            else if(!pair[from] && totalBuyFee > 0) {
                amount -= BuyFees;
                super._transfer(from, address(this), BuyFees);
                super._transfer(from, to, amount);
            }
            else {
                super._transfer(from, to, amount);
            }
        }
    }

    function swapTokensForEth(uint256 swapAmount) private {

        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        _approve(address(this), address(uniswapV2Router), swapAmount);

        // make the swap
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            swapAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

}