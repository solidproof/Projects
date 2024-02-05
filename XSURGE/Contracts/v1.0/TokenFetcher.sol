//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "../lib/IUniswapV2Router02.sol";
import "../lib/IERC20.sol";

interface IXUSD {
    function burn(uint256 amount) external;
}

contract TokenFetcher {

    address public immutable XUSD;
    IUniswapV2Router02 router;

    constructor(address XUSD_) {
        XUSD = XUSD_;
        router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
    }

    function bnbToStable(address stable, uint256 minOut) external payable {
        _swapForStable(stable, msg.value, minOut);
    }

    function balanceToStable(address stable) external {
        _swapForStable(stable, address(this).balance, 0);
    }

    function withdraw(address token) external {
        IERC20(token).transfer(XUSD, IERC20(token).balanceOf(address(this)));
    }

    function burnXUSD() external {
        require(address(this).balance > 0);
        (bool s,) = payable(XUSD).call{value: address(this).balance}("");
        if (s) {
            IXUSD(XUSD).burn(IERC20(XUSD).balanceOf(address(this)));
        }
    }

    function _swapForStable(address stable, uint256 amount, uint256 minOut) internal {

        // BNB -> Stable
        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = stable;
        
        // swap bnb for token
        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
            minOut,
            path,
            XUSD,
            block.timestamp + 30
        );
    }

}