// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import '@openzeppelin/contracts/token/ERC20/IERC20.sol';

import './interfaces/IStableSwapRouter.sol';
import './interfaces/IStableSwap.sol';
import './interfaces/IStableSwapFactory.sol';
import "./interfaces/IStableSwapInfo.sol";

import './libraries/TransferHelper.sol';

/// @title Stable Swap Router
contract StableSwapRouter is IStableSwapRouter, ReentrancyGuard {
    address public stableSwapFactory;
    address public stableSwapTwoPoolInfo;
    address public stableSwapThreePoolInfo;

    constructor(
        address _stableSwapFactory,
        address _stableSwapTwoPoolInfo,
        address _stableSwapThreePoolInfo
    ) {
        require(_stableSwapFactory != address(0) && _stableSwapTwoPoolInfo != address(0) && _stableSwapThreePoolInfo != address(0), "Illegal address");
        stableSwapFactory = _stableSwapFactory;
        stableSwapTwoPoolInfo = _stableSwapTwoPoolInfo;
        stableSwapThreePoolInfo = _stableSwapThreePoolInfo;
    }

    function swap(
        address[] memory path,
        uint256[] memory flag
    ) private {
        require(flag.length < 5, "swap: invalid flag");
        require(path.length - 1 == flag.length, "swap: invalid path");
        
        for (uint256 i = 0; i < flag.length; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (uint256 k, uint256 j, address swapContract) = getStableInfo(stableSwapFactory, input, output, flag[i]);
            uint256 amountIn_ = IERC20(input).balanceOf(address(this));
            TransferHelper.safeApprove(input, swapContract, amountIn_);
            IStableSwap(swapContract).exchange(k, j, amountIn_, 0);
        }
    }

    /** 
     * @param flag token amount in a stable swap pool. 2 for 2pool, 3 for 3pool    
     */
    function exactInputStableSwap(
        address[] calldata path,
        uint256[] calldata flag,
        uint256 amountIn,
        uint256 amountOutMin,
        address to
    ) external override nonReentrant returns (uint256 amountOut) {
        require(path.length > 1, "exactInputStableSwap: invalid path");

        address srcToken = path[0];
        address dstToken = path[path.length - 1];
        TransferHelper.safeTransferFrom(srcToken, msg.sender, address(this), amountIn);
        swap(path, flag);
        amountOut = IERC20(dstToken).balanceOf(address(this));
        require(amountOut >= amountOutMin, "exactInputStableSwap: INSUFFICIENT_OUTPUT_AMOUNT");

        TransferHelper.safeTransfer(dstToken, to, amountOut);
    }

    /** 
     * @param flag token amount in a stable swap pool. 2 for 2pool, 3 for 3pool    
     */
    function exactOutputStableSwap(
        address[] calldata path,
        uint256[] calldata flag,
        uint256 amountOut,
        uint256 amountInMax,
        address to
    ) external override nonReentrant returns (uint256 amountIn) {
        require(path.length > 1, "exactOutputStableSwap: invalid path");
        
        address srcToken = path[0];
        address dstToken = path[path.length - 1];
        amountIn = getStableAmountsIn(path, flag, amountOut)[0];
        require(amountIn <= amountInMax, "exactOutputStableSwap: EXCESSIVE_INPUT_AMOUNT");
        
        TransferHelper.safeTransferFrom(srcToken, msg.sender, address(this), amountIn);
        swap(path, flag);
        uint256 _amountOut = IERC20(dstToken).balanceOf(address(this));
        
        TransferHelper.safeTransfer(dstToken, to, _amountOut);

    }
    function getAmountsIn(
        address[] calldata path,
        uint256[] calldata flag,
        uint256 amountOut
    ) external view returns (uint256[] memory amountsIn) {
        amountsIn = getStableAmountsIn(path, flag, amountOut);
    }

    function getAmountsOut(
        address[] calldata path,
        uint256[] calldata flag,
        uint256 amountIn
    ) external view returns (uint256[] memory amountsOut) {
        amountsOut = getStableAmountsOut(path, flag, amountIn);
    }
    
    function getStableInfo(
        address factory,
        address input,
        address output,
        uint256 flag
    ) public view returns (uint256 i, uint256 j, address swapContract) {
        if (flag == 2) {
            IStableSwapFactory.StableSwapPairInfo memory info = IStableSwapFactory(factory).getPairInfo(input, output);
            i = input == info.token0 ? 0 : 1;
            j = (i == 0) ? 1 : 0;
            swapContract = info.swapContract;
        } else if (flag == 3) {
            IStableSwapFactory.StableSwapThreePoolPairInfo memory info = IStableSwapFactory(factory).getThreePoolPairInfo(input, output);

            if (input == info.token0) i = 0;
            else if (input == info.token1) i = 1;
            else if (input == info.token2) i = 2;

            if (output == info.token0) j = 0;
            else if (output == info.token1) j = 1;
            else if (output == info.token2) j = 2;

            swapContract = info.swapContract;
        }

        require(swapContract != address(0), "getStableInfo: invalid pool address");
    }

    function getStableAmountsIn(
        address[] memory path,
        uint256[] memory flag,
        uint256 amountOut
    ) internal view returns (uint256[] memory amounts) {
        uint256 length = path.length;
        require(length >= 2, "getStableAmountsIn: incorrect length");
        require(path.length - 1 == flag.length, "getStableAmountsIn: invalid flag");

        amounts = new uint256[](length);
        amounts[length - 1] = amountOut;

        for (uint256 i = length - 1; i > 0;) {
            uint256 last = i - 1;
            (uint256 k, uint256 j, address swapContract) = getStableInfo(stableSwapFactory, path[last], path[i], flag[last]);
            uint256 n_coins = IStableSwap(swapContract).N_COINS();
            address poolInfo;
            if (n_coins == 3) {
                poolInfo = stableSwapThreePoolInfo;
            }
            else {
                poolInfo = stableSwapTwoPoolInfo;
            }
            amounts[last] = IStableSwapInfo(poolInfo).get_dx(swapContract, k, j, amounts[i], type(uint256).max);

            unchecked {
                i--;
            }
        }
    }

    function getStableAmountsOut(
        address[] memory path,
        uint256[] memory flag,
        uint256 amountIn
    ) internal view returns (uint256[] memory amounts) {
        uint256 length = path.length;
        require(length >= 2, "getStableAmountsIn: incorrect length");

        amounts = new uint256[](length);
        amounts[length - 1] = amountIn;

        for (uint256 i = length - 1; i > 0;) {
            uint256 last = i - 1;
            (uint256 k, uint256 j, address swapContract) = getStableInfo(stableSwapFactory, path[last], path[i], flag[last]);
            
            amounts[last] = IStableSwap(swapContract).get_dy(k, j, amounts[i]);
            unchecked {
                i--;
            }
        }
    }
}