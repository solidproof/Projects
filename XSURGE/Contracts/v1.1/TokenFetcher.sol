//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

import "./IUniswapV2Router02.sol";
import "./IERC20.sol";

interface IXUSD {
    function burn(uint256 amount) external;
    function getUnderlyingAssets() external view returns(address[] memory);
    function stableAssets(address asset) external view returns (bool,bool,uint8);
}

contract TokenFetcher {

    address public immutable XUSD;
    IUniswapV2Router02 public router;

    constructor(address XUSD_) {
        require(XUSD_ != address(0), 'Zero Address');
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
        require(address(this).balance > 0, 'Zero Balance');
        (bool s,) = payable(XUSD).call{value: address(this).balance}("");
        if (s) {
            IXUSD(XUSD).burn(IERC20(XUSD).balanceOf(address(this)));
        }
    }

    /** Fetches Optimal Stable To Swap For On PCS */
    function chooseStable() public view returns (address) {

        // iterate through stables finding one with the least amount
        address least; uint256 leastAmount = 10**55;
        address[] memory stables = IXUSD(XUSD).getUnderlyingAssets();

        if (stables.length < 2) {
            return stables[0];
        }

        for (uint i = 0; i < stables.length; i++) {
            uint256 bal = IERC20(stables[i]).balanceOf(XUSD);
            (,bool mintDisabled,) = IXUSD(XUSD).stableAssets(stables[i]);
            if (bal < leastAmount && !mintDisabled) {
                least = stables[i];
                leastAmount = bal;
            }
        }

        // fetch pseudo-random number, doesn't need to be random for effect to work
        uint256 odds = ( ( block.timestamp + leastAmount ) % block.number ) % 100; 
        return odds < 30 ? stables[0] : least;
    }

    function _swapForStable(address stable, uint256 amount, uint256 minOut) internal {

        require(
            amount > 0 && stable != address(0)
        );

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