// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.8.7;

import "./CommonERC20.sol";
import {IAlgebraPluginFactory} from "@cryptoalgebra/integral-core/contracts/interfaces/plugin/IAlgebraPluginFactory.sol";
import {IAlgebraFactory} from "@cryptoalgebra/integral-core/contracts/interfaces/IAlgebraFactory.sol";
import {IAlgebraPool} from "@cryptoalgebra/integral-core/contracts/interfaces/IAlgebraPool.sol";
import {INonfungiblePositionManager} from "@cryptoalgebra/integral-periphery/contracts/interfaces/INonfungiblePositionManager.sol";
import {IWNativeToken} from "@cryptoalgebra/integral-periphery/contracts/interfaces/external/IWNativeToken.sol";
import {TickMath} from "@cryptoalgebra/integral-core/contracts/libraries/TickMath.sol";
import {PresaleManager, Presale} from "./PresaleManager.sol";
import "@openzeppelin/contracts/token/ERC721/IERC721Receiver.sol";

contract PresaleMaker is IERC721Receiver {
    address public immutable WNativeToken;

    IAlgebraPluginFactory pluginFactory = IAlgebraPluginFactory(address(0x313F9DEe835569F1AaEA51854818C72cD6302509));
    uint8 pluginConfig = 0x00000000000000000000000000000000000000000000000000000000000000c1;

    uint256 public fee = 1e16;
    uint256 public ethFee = 5e14;
    address private feeVault;
    uint256 public minimalTotalSupply = 10000000e18;

    IAlgebraFactory public factory;
    INonfungiblePositionManager public positionManager;
    PresaleManager public presaleManager;

    constructor(
        IAlgebraFactory _factory,
        INonfungiblePositionManager _positionManager,
        address _WNativeToken,
        PresaleManager _presaleManager,
        address _feeVault
    ) {
        factory = _factory;
        positionManager = _positionManager;
        WNativeToken = _WNativeToken;
        presaleManager = _presaleManager;
        feeVault = _feeVault;
    }

    function create(
        uint160 sqrtPriceX96,
        string memory name,
        string memory symbol,
        uint256 totalSupply,
        uint256 minterAllocation,
        int24 bottomTick,
        int24 topTick,
        uint256 presaleAmount,
        string memory data
    ) external payable {
        require(totalSupply > minimalTotalSupply, "TokenMaker : totalSupply is too low");
        require(minterAllocation < totalSupply, "TokenMaker : minterAllocation is too high");
        require(ethFee <= msg.value, "TokenMaker : fee is too low");

        CommonERC20 token = new CommonERC20(name, symbol, totalSupply);
        address poolAddress = factory.createPool(WNativeToken, address(token));
        uint256 feeAmount = (totalSupply * fee) / 1e18;

        token.transfer(feeVault, feeAmount);
        payable(feeVault).transfer(ethFee);

        if (minterAllocation > 0) {
            token.transfer(msg.sender, minterAllocation);
        }

        uint256 lpAmount = token.balanceOf(address(this));
        token.approve(poolAddress, lpAmount);
        token.approve(address(positionManager), lpAmount);

        IAlgebraPool _pool = IAlgebraPool(poolAddress);
        _pool.initialize(sqrtPriceX96);

        uint256 token0Amount;
        uint256 token1Amount;
        if (_pool.token0() == WNativeToken) {
            token0Amount = 0;
            token1Amount = lpAmount;
        } else {
            token0Amount = lpAmount;
            token1Amount = 0;
        }

        (uint256 tokenId, uint128 liquidity, uint256 amount0, uint256 amount1) = positionManager.mint(
            INonfungiblePositionManager.MintParams(
                _pool.token0(),
                _pool.token1(),
                bottomTick,
                topTick,
                token0Amount,
                token1Amount,
                0,
                0,
                address(this),
                block.timestamp + 100
            )
        );
        positionManager.approve(address(presaleManager), tokenId);
        presaleManager.putPresale(
            Presale(
                name,
                symbol,
                presaleAmount,
                address(token),
                address(_pool),
                totalSupply,
                minterAllocation,
                data,
                tokenId,
                false
            )
        );
    }

    receive() external payable {}

    fallback() external payable {}

    function onERC721Received(
        address operator,
        address,
        uint256 tokenId,
        bytes calldata
    ) external override returns (bytes4) {
        return this.onERC721Received.selector;
    }
}

