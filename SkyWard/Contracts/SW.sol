// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

/* ------------------------------------------ Imports ------------------------------------------ */

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

/* -------------------------------------- Dex Interfaces --------------------------------------- */

interface IDexFactory {
    function createPair(address tokenA, address tokenB) external returns (address pair);
}

interface IDexRouter {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;

    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
}

/* --------------------------------------- Main Contract --------------------------------------- */

contract SW is ERC20, Ownable {

    /* ----------------------------------- State Variables ------------------------------------ */

    IDexRouter private immutable uniswapV2Router;
    address private immutable uniswapV2Pair;
    address[] private wethContractPath;
    mapping (address => bool) private excludedFromFees;
    mapping (address => uint256) public owedRewards;

    address public skyRewards;
    address public skyTreasury;

    uint256 public maxWallet;
    uint256 public baseFees;
    uint256 public liquidityFee;
    uint256 public treasuryFee;
    uint256 private swapTokensAtAmount;
    uint256 private tokensForLiquidity;
    uint256 private tokensForTreasury;

    uint256 public bonusRewards;
    uint256 public bonusRewardsMultiplier;
    uint256 public rewardsFee;
    uint256 public rewardsFeeMultiplier;

    uint256 public currentAth;
    uint256 public currentPrice;
    uint256 public resetAthTime;
    uint256 public supportThreshold;

    event AthReset(uint256 newAth);
    event UpdatedBaseFees(uint256 newAmount);
    event UpdatedMaxWallet(uint256 newAmount);
    event UpdatedMultipliers(uint256 newBonus, uint256 newRewards);
    event UpdatedSkyRewardsAddress(address indexed newWallet);
    event UpdatedSkyTreasuryAddress(address indexed newWallet);
    event UpdatedSupportThreshold(uint256 newThreshold);

    /* --------------------------------- Contract Constructor --------------------------------- */

    constructor(address dexRouter) ERC20("SW", "SW") {
        uniswapV2Router = IDexRouter(dexRouter);
        uniswapV2Pair = IDexFactory(uniswapV2Router.factory()).createPair(address(this), uniswapV2Router.WETH());

        uint256 totalSupply = 100000000 * 10**18;
        swapTokensAtAmount = totalSupply * 1 / 4000;
        maxWallet = totalSupply * 2 / 100;
        treasuryFee = 9;
        liquidityFee = 1;
        baseFees = treasuryFee + liquidityFee;
        supportThreshold = 10;
        bonusRewardsMultiplier = 2;
        rewardsFeeMultiplier = 2;

        excludeFromFees(msg.sender, true);
        excludeFromFees(address(this), true);
        excludeFromFees(address(0), true);

        wethContractPath = [uniswapV2Router.WETH(), address(this)];
        
        _mint(msg.sender, totalSupply);
        transferOwnership(msg.sender);
    }

    receive() external payable {}

    /* ------------------------------- Main Contract Functions -------------------------------- */

    // Transfer tokens
    function _transfer(address from, address to, uint256 amount) internal override {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Amount must be greater than 0");
        
        if (!excludedFromFees[from] && !excludedFromFees[to]) {
            if (to != uniswapV2Pair) {
                require(amount + balanceOf(to) <= maxWallet, "Exceeds max wallet");
            }

            checkPrice();

            if (from == uniswapV2Pair) {
                uint256 bonus = 0;
                bonus = amount * bonusRewards / 100 + owedRewards[to];
                if (bonus > 0) {
                    if (bonus <= balanceOf(skyRewards)) {
                        super._transfer(skyRewards, to, bonus);
                        delete owedRewards[to];
                    } else {
                        owedRewards[to] += bonus;
                    }
                }
            } else if (to == uniswapV2Pair && baseFees > 0) {
                if (balanceOf(address(this)) >= swapTokensAtAmount) {
                    swapBack();
                }

                uint256 fees = 0;
                uint256 penaltyFees = 0;
                fees = amount * baseFees / 100;
                penaltyFees = amount * rewardsFee / 100;
                tokensForTreasury += fees * treasuryFee / baseFees;
                tokensForLiquidity += fees * liquidityFee / baseFees;
                if (fees > 0) {
                    super._transfer(from, address(this), fees);
                }

                if (penaltyFees > 0) {
                    super._transfer(from, skyRewards, penaltyFees);
                }

                if (owedRewards[from] > 0 && owedRewards[from] <= balanceOf(skyRewards)) {
                    super._transfer(skyRewards, from, owedRewards[from]);
                    delete owedRewards[from];
                }
                amount -= fees + penaltyFees;
            }
        }
        super._transfer(from, to, amount);
    }

    // Claim owed rewards (manual implementation)
    function claimOwed() external {
        require(owedRewards[msg.sender] > 0, "You have no owed rewards");
        require(owedRewards[msg.sender] <= balanceOf(skyRewards), "Insufficient rewards in rewards pool");
        super._transfer(skyRewards, msg.sender, owedRewards[msg.sender]);
        delete owedRewards[msg.sender];
    }

    /* ----------------------------------- Owner Functions ------------------------------------ */

    // Withdraw stuck ETH
    function clearStuckBalance() external onlyOwner {
        bool success;
        (success,) = address(msg.sender).call{value: address(this).balance}("");
    }

    // Exclude an address from transaction fees
    function excludeFromFees(address account, bool excluded) public onlyOwner {
        excludedFromFees[account] = excluded;
    }

    // Set the current ATH to current price (manual implementation)
    function resetAthManual() external onlyOwner {
        currentPrice = getCurrentPrice();
        require(currentPrice != 0, "Not a valid price");
        resetAth(currentPrice);
        emit AthReset(currentPrice);
    }

    // Designate rewards address
    function setSkyRewardsAddress(address _skyRewards) external onlyOwner {
        require(_skyRewards != address(0), "_skyRewards address cannot be the zero address");
        skyRewards = _skyRewards;
        emit UpdatedSkyRewardsAddress(skyRewards);
    }
    
    // Designate treasury address
    function setSkyTreasuryAddress(address _skyTreasury) external onlyOwner {
        require(_skyTreasury != address(0), "_skyTreasury address cannot be the zero address");
        skyTreasury = payable(_skyTreasury);
        emit UpdatedSkyTreasuryAddress(skyTreasury);
    }

    // Withdraw non-native tokens
    function transferForeignToken(address _token, address _to) external onlyOwner returns (bool _sent) {
        require(_token != address(0), "_token address cannot be the zero address");
        require(_token != address(this), "Can't withdraw native tokens");
        uint256 _contractBalance = IERC20(_token).balanceOf(address(this));
        _sent = IERC20(_token).transfer(_to, _contractBalance);
    }

    // Update fees
    function updateFees(uint256 _treasuryFee, uint256 _liquidityFee) external onlyOwner {
        require(_treasuryFee + _liquidityFee <= 10, "Must keep fees at 10% or less");
        treasuryFee = _treasuryFee;
        liquidityFee = _liquidityFee;
        baseFees = treasuryFee + liquidityFee;
        emit UpdatedBaseFees(baseFees);
    }

    // Update max wallet
    function updateMaxWallet(uint256 _maxWallet) external onlyOwner {
        require(_maxWallet > 0, "Max wallet must be greater than 0%");
        maxWallet = totalSupply() * _maxWallet / 100;
        emit UpdatedMaxWallet(maxWallet);
    }

    // Update bonus rewards and rewards fee multipliers
    function updateMultipliers(uint256 _bonusRewardsMultiplier, uint256 _rewardsFeeMultiplier) external onlyOwner {
        require(_bonusRewardsMultiplier > 0, "Bonus rewards multiplier cannot be 0");
        require(_bonusRewardsMultiplier <= 5, "Bonus rewards multiplier greater than 5");
        require(_rewardsFeeMultiplier <= 2, "Rewards fee multiplier greater than 2");
        bonusRewardsMultiplier = _bonusRewardsMultiplier;
        rewardsFeeMultiplier = _rewardsFeeMultiplier;
        emit UpdatedMultipliers(bonusRewardsMultiplier, rewardsFeeMultiplier);
    }

    // Update support threshold
    function updateSupportThreshold(uint256 _supportThreshold) external onlyOwner {
        require(_supportThreshold >= 5 , "Threshold lower than 5%");
        require(_supportThreshold <= 20, "Threshold greater than 20%");
        supportThreshold = _supportThreshold;
        emit UpdatedSupportThreshold(supportThreshold);
    }

    // Update token threshold for when the contract sells for liquidity and treasury
    function updateSwapTokensAtAmount(uint256 _swapTokensAtAmount) external onlyOwner { 
  	    require(_swapTokensAtAmount <= (totalSupply() * 1 / 1000) / 10**18, "Threshold higher than 0.1% total supply");
  	    swapTokensAtAmount = _swapTokensAtAmount * 10**18;
  	}

    /* ------------------------------- Private Helper Functions ------------------------------- */

    // Liquidity injection helper function
    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0,
            0,
            owner(),
            block.timestamp
        );
    }

    // Check current price and modify bonus rewards & reward fees accordingly
    function checkPrice() private {
        currentPrice = getCurrentPrice();
        require(currentPrice != 0, "Not a valid price");

        if (currentPrice <= currentAth || currentAth == 0) {
            resetAth(currentPrice);
        } else if (currentPrice > currentAth) {
            if (resetAthTime == 0) {
                resetAthTime = block.timestamp + 7 * 1 days;
            } else {
                if (block.timestamp >= resetAthTime) {
                    resetAth(currentPrice);
                }
            }

            uint256 priceDifference = (10000 - (10000 * currentAth / currentPrice));

            if (priceDifference / 100 >= supportThreshold) {
                bonusRewards = bonusRewardsMultiplier * supportThreshold;
                rewardsFee = rewardsFeeMultiplier * supportThreshold;
            } else {
                if (priceDifference % 100 >= 50) {
                    bonusRewards = bonusRewardsMultiplier * ((priceDifference / 100) + 1);
                    rewardsFee = rewardsFeeMultiplier * ((priceDifference / 100) + 1);
                } else {
                    bonusRewards = bonusRewardsMultiplier * ((priceDifference / 100));
                    rewardsFee = rewardsFeeMultiplier * ((priceDifference / 100));
                }
            }
        }
    }

    // Set the current ATH to current price
    function resetAth(uint256 _currentPrice) private {
        currentAth = _currentPrice;
        resetAthTime = 0;
        bonusRewards = 0;
        rewardsFee = 0;
    }

    // Contract sells for liquidity and treasury
    function swapBack() private {
        uint256 contractBalance = balanceOf(address(this));
        uint256 totalTokensToSwap = tokensForTreasury + tokensForLiquidity;
        
        if (contractBalance == 0 || totalTokensToSwap == 0) {
            return;
        }

        if (contractBalance > swapTokensAtAmount * 10) {
            contractBalance = swapTokensAtAmount * 10;
        }

        bool success;
        uint256 liquidityTokens = contractBalance * tokensForLiquidity / totalTokensToSwap / 2;
        swapTokensForETH(contractBalance - liquidityTokens); 

        uint256 ethBalance = address(this).balance;
        uint256 ethForTreasury = ethBalance * tokensForTreasury / (totalTokensToSwap - (tokensForLiquidity / 2));
        uint256 ethForLiquidity = ethBalance - ethForTreasury;

        tokensForLiquidity = 0;
        tokensForTreasury = 0;
        
        if (liquidityTokens > 0 && ethForLiquidity > 0) {
            addLiquidity(liquidityTokens, ethForLiquidity);
        }

        (success,) = address(skyTreasury).call{value: address(this).balance}("");
    }

    // Swap native token for ETH
    function swapTokensForETH(uint256 tokenAmount) private {
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

    /* -------------------------------- Public View Functions --------------------------------- */

    // Retrieve current exchange rate of native token for 1 WETH
    function getCurrentPrice() public view returns (uint256) {
        try uniswapV2Router.getAmountsOut(1 * 10**18, wethContractPath) returns (uint256[] memory amounts) {
            return amounts[1];
        } catch {
            return 0;
        }
    }
}