//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./IERC20.sol";
import "./Ownable.sol";
import "./IUniswapV2Router02.sol";

interface IXUSDReceiver {
    function deposit(uint256 amount) external;
}

interface IXSurge {
    function sell(uint256 amount) external returns (address, uint256);
    function getUnderlyingAssets() external view returns(address[] memory);
}

contract SwapHelper {

    address public immutable DEX;
    IUniswapV2Router02 immutable public router;

    constructor(address dex) {
        DEX = dex;
        router = IUniswapV2Router02(dex);
    }

    function _sellSurge(address surge) internal {
        IXSurge(surge).sell(IERC20(surge).balanceOf(address(this)));
    }

    function _tokenToToken(address tokenIn, address tokenOut, uint256 amountIn) internal {

        // approve router
        IERC20(tokenIn).approve(DEX, amountIn);

        address[] memory path = new address[](3);
        path[0] = tokenIn;
        path[1] = router.WETH();
        path[2] = tokenOut;

        // swap token for bnb
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn, 0, path, address(this), block.timestamp + 300);

        delete path;
    }

    function _tokenToTokenDirect(address tokenIn, address tokenOut, uint256 amountIn) internal {
    
        // approve router
        IERC20(tokenIn).approve(DEX, amountIn);

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = tokenOut;

        // swap token for bnb
        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(amountIn, 0, path, address(this), block.timestamp + 300);

        delete path;
    }

    function _bnbToToken(address token, uint256 amount) internal {

        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = token;

        // swap token for bnb
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(0, path, address(this), block.timestamp + 300);

        delete path;
    }

    function _tokenToBNB(address tokenIn, uint256 amountIn) internal {

        // approve router
        IERC20(tokenIn).approve(DEX, amountIn);

        address[] memory path = new address[](2);
        path[0] = tokenIn;
        path[1] = router.WETH();

        // swap token for bnb
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(amountIn, 0, path, address(this), block.timestamp + 300);

        delete path;
    }

}

/**
    Allocates XUSD Taxation Across Various Resources
 */
contract ResourceCollector is Ownable, SwapHelper(0x10ED43C718714eb63d5aA57B78B54704E256024E){

    // receiving structure
    struct Receiver {
        uint256 points;
        uint256 index;
    }

    // divides up XUSD based on resourcePoints / totalPoints
    mapping ( address => Receiver ) public receivers;

    // list of resources to receive funding
    address[] public resources;

    // total points
    uint256 public totalPoints;

    // XUSD Address
    address public XUSD;

    // Events
    event ResourceAdded(address resource, uint256 points);
    event ResourceRemoved(address resource);

    constructor(address _XUSD){
        XUSD = _XUSD;
    }

    function setXUSD(address XUSD_) external onlyOwner {
        XUSD = XUSD_;
    }

    function tokenToBNB(address token) external onlyOwner {
        if (IERC20(token).balanceOf(address(this)) > 0) {
            _tokenToBNB(token, IERC20(token).balanceOf(address(this)));
        }
    }

    function bnbToToken(address token) external onlyOwner {
        if (address(this).balance > 0) {
            _bnbToToken(token, address(this).balance);
        }
    }

    function deliver() external onlyOwner {
        _deliver();
    }

    function sellAndDeliver(address token) external onlyOwner {
        _tokenToBNB(token, IERC20(token).balanceOf(address(this)));
        _deliver();
    }

    function sellXUSDAndDeliver() external onlyOwner {
        (address token,) = IXSurge(XUSD).sell(IERC20(XUSD).balanceOf(address(this)));
        _tokenToBNB(token, IERC20(token).balanceOf(address(this)));
        _deliver();
    }

    function sellAllAndDeliver() external onlyOwner {
        if (IERC20(XUSD).balanceOf(address(this)) > 0) {
            _sellSurge(XUSD);
        }
        address[] memory tokensToSell = IXSurge(XUSD).getUnderlyingAssets();
        for (uint i = 0; i < tokensToSell.length; i++) {
            if (IERC20(tokensToSell[i]).balanceOf(address(this)) > 0) {
                _tokenToBNB(tokensToSell[i], IERC20(tokensToSell[i]).balanceOf(address(this)));
            }
        }
        _deliver();
    }

    function deliverToken(address token) external onlyOwner {
        _deliverToken(token);
    }

    function deliverSellableTokens() external onlyOwner {
        address[] memory tokensToSell = IXSurge(XUSD).getUnderlyingAssets();
        for (uint i = 0; i < tokensToSell.length; i++) {
            if (IERC20(tokensToSell[i]).balanceOf(address(this)) > 100) {
                _deliverToken(tokensToSell[i]);
            }
        }
    }

    function _deliver() internal {
        uint256[] memory distributions = _fetchDistribution(address(this).balance);        
        for (uint i = 0; i < resources.length; i++) {
            if (distributions[i] > 0) {
                (bool s,) = payable(resources[i]).call{value: distributions[i]}("");
                require(s);
            }
        }
    }

    function _deliverToken(address token) internal {
        uint256[] memory distributions = _fetchDistribution(IERC20(token).balanceOf(address(this)));        
        for (uint i = 0; i < resources.length; i++) {
            if (distributions[i] > 0) {
                IERC20(token).transfer(resources[i], distributions[i]);
            }
        }
    }

    function sellXUSD() external onlyOwner {
        _sellSurge(XUSD);
    }

    function sellSurge(address surge) external onlyOwner {
        _sellSurge(surge);
    }

    function changeResourcePoints(address resource, uint newPoints) external onlyOwner {
        require(receivers[resource].points > 0, 'No Points');
        require(newPoints > 0, 'Remove Resource If Points Are Set To Zero');

        totalPoints = totalPoints - receivers[resource].points + newPoints;
        receivers[resource].points = newPoints;
    }

    function addResource(
        address resource,
        uint256 points
    ) external onlyOwner {

        // set structure data
        receivers[resource].points = points;
        receivers[resource].index = resources.length;

        // increment total points
        totalPoints += points;

        // add resource to list
        resources.push(resource);
        emit ResourceAdded(resource, points);
    }

    function removeResource(
        address resource
    ) external onlyOwner {
        require(
            receivers[resource].points > 0,
            'Not Receiver'
        );

        // decrement total points
        totalPoints -= receivers[resource].points;

        // remove element from array and mapping
        receivers[
            resources[resources.length - 1]
        ].index = receivers[resource].index;
        resources[
            receivers[resource].index
        ] = resources[resources.length - 1];
        resources.pop();
        delete receivers[resource];
        emit ResourceRemoved(resource);
    }

    /**
        Iterates through sources and fractions out amount
        Between them based on their points score
     */
    function _fetchDistribution(uint256 amount) internal view returns (uint256[] memory) {
        uint256[] memory distributions = new uint256[](resources.length);
        for (uint i = 0; i < resources.length; i++) {
            distributions[i] = ( amount * receivers[resources[i]].points / totalPoints ) - 1;
        }
        return distributions;
    }
}