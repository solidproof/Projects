// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.7;

import "./CommonERC20.sol";
import {IAlgebraPool} from "@cryptoalgebra/integral-core/contracts/interfaces/IAlgebraPool.sol";
import {INonfungiblePositionManager} from "@cryptoalgebra/integral-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {IWNativeToken} from "@cryptoalgebra/integral-periphery/contracts/interfaces/external/IWNativeToken.sol";
import {TickMath} from "@cryptoalgebra/integral-core/contracts/libraries/TickMath.sol";
import {PresaleManager, Presale} from "./PresaleManager.sol";

contract PresaleReleaseExcutor {
    address public immutable WNativeToken;

    INonfungiblePositionManager public positionManager;
    PresaleManager public presaleManager;

    constructor(
        INonfungiblePositionManager _positionManager,
        address _WNativeToken,
        PresaleManager _presaleManager
    ) {
        positionManager = _positionManager;
        WNativeToken = _WNativeToken;
        presaleManager = _presaleManager;
    }

    function release(address poolAddress) external {
        require(msg.sender == address(presaleManager), "TokenMaker : FORBIDDEN");
        Presale memory presale = presaleManager.getPresale(poolAddress);
        require(presale.released == false, "TokenMaker : presale is already released");

        PositionInfo memory position = getPositionInfo(presale.positionTokenId);
        positionManager.decreaseLiquidity(
            INonfungiblePositionManager.DecreaseLiquidityParams(
                presale.positionTokenId,
                position.liquidity,
                0,
                0,
                block.timestamp + 100
            )
        );
        positionManager.collect(
            INonfungiblePositionManager.CollectParams(
                presale.positionTokenId,
                address(this),
                type(uint128).max,
                type(uint128).max
            )
        );
        positionManager.burn(presale.positionTokenId);

        IAlgebraPool pool = IAlgebraPool(poolAddress);
        uint256 wethBalance = IWNativeToken(WNativeToken).balanceOf(address(this));
        if (wethBalance > 0) {
            IWNativeToken(WNativeToken).withdraw(wethBalance);
        }

        CommonERC20 token = CommonERC20(presale.token);
        uint256 ethBalance = address(this).balance;
        uint256 tokenBalance = token.balanceOf(address(this));
        uint256 mintAmount0;
        uint256 mintAmount1;
        if (pool.token0() == WNativeToken) {
            mintAmount0 = ethBalance;
            mintAmount1 = tokenBalance;
        } else {
            mintAmount0 = tokenBalance;
            mintAmount1 = ethBalance;
        }

        int24 tickSpacing = pool.tickSpacing();
        token.approve(poolAddress, type(uint256).max);
        token.approve(address(positionManager), type(uint256).max);
        (uint256 newTokenId, uint128 _liquidity, uint256 _amount0, uint256 _amount1) = positionManager.mint{
            value: ethBalance
        }(
            INonfungiblePositionManager.MintParams(
                pool.token0(),
                pool.token1(),
                TickMath.MIN_TICK - (TickMath.MIN_TICK % tickSpacing),
                TickMath.MAX_TICK - (TickMath.MAX_TICK % tickSpacing),
                mintAmount0,
                mintAmount1,
                0,
                0,
                address(this),
                block.timestamp + 100
            )
        );
        positionManager.transferFrom(address(this), address(presaleManager), newTokenId);
    }

    function getPositionInfo(uint256 tokenId) internal view returns (PositionInfo memory) {
        (
            uint88 nonce,
            address operator,
            address token0,
            address token1,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        ) = positionManager.positions(tokenId);
        return
            PositionInfo(
                nonce,
                operator,
                token0,
                token1,
                tickLower,
                tickUpper,
                liquidity,
                feeGrowthInside0LastX128,
                feeGrowthInside1LastX128,
                tokensOwed0,
                tokensOwed1
            );
    }

    receive() external payable {}

    fallback() external payable {}

    struct PositionInfo {
        uint88 nonce;
        address operator;
        address token0;
        address token1;
        int24 tickLower;
        int24 tickUpper;
        uint128 liquidity;
        uint256 feeGrowthInside0LastX128;
        uint256 feeGrowthInside1LastX128;
        uint128 tokensOwed0;
        uint128 tokensOwed1;
    }
}
