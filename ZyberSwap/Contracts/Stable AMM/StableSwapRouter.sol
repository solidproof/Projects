// SPDX-License-Identifier: MIT

pragma solidity 0.7.0;

import "./interfaces/ISwap.sol";

contract StableSwapRouter {
    using SafeERC20 for IERC20;

    function convert(
        ISwap fromPool,
        ISwap toPool,
        uint256 amount,
        uint256 minToMint,
        uint256 deadline
    ) external returns (uint256) {
        uint256 fromPoolLength = fromPool.getNumberOfTokens();
        uint256 toPoolLength = toPool.getNumberOfTokens();
        require(address(fromPool) != address(toPool), "fromPool = toPool");
        require(fromPoolLength == toPoolLength, "poolTokensLengthMissmatch");
        IERC20 fromToken = fromPool.getLpToken();
        IERC20 toToken = toPool.getLpToken();
        uint256[] memory min_amounts = new uint256[](fromPoolLength);
        // validate token
        for (uint8 i = 0; i < fromPoolLength; i++) {
            IERC20 coin = fromPool.getToken(i);
            toPool.getTokenIndex(address(coin));
        }
        fromToken.transferFrom(msg.sender, address(this), amount);
        fromToken.safeIncreaseAllowance(address(fromPool), amount);
        fromPool.removeLiquidity(amount, min_amounts, deadline);

        uint256[] memory meta_amounts = new uint256[](toPoolLength);

        for (uint8 i = 0; i < toPoolLength; i++) {
            IERC20 coin = toPool.getToken(i);
            uint256 addBalance = coin.balanceOf(address(this));
            coin.safeIncreaseAllowance(address(toPool), addBalance);
            meta_amounts[i] = addBalance;
        }
        toPool.addLiquidity(meta_amounts, minToMint, deadline);

        uint256 lpAmount = toToken.balanceOf(address(this));
        toToken.transfer(msg.sender, lpAmount);
        return lpAmount;
    }

    function addLiquidity(
        ISwap pool,
        ISwap basePool,
        uint256[] memory meta_amounts,
        uint256[] memory base_amounts,
        uint256 minToMint,
        uint256 deadline
    ) external returns (uint256) {
        IERC20 token = IERC20(pool.getLpToken());
        IERC20 base_lp = IERC20(basePool.getLpToken());
        require(
            base_amounts.length == basePool.getNumberOfTokens(),
            "invalidBaseAmountsLength"
        );
        require(
            meta_amounts.length == pool.getNumberOfTokens(),
            "invalidMetaAmountsLength"
        );
        bool deposit_base = false;
        for (uint8 i = 0; i < base_amounts.length; i++) {
            uint256 amount = base_amounts[i];
            if (amount > 0) {
                deposit_base = true;
                IERC20 coin = basePool.getToken(i);
                uint256 transferred = transferIn(coin, msg.sender, amount);
                coin.safeIncreaseAllowance(address(basePool), transferred);
                base_amounts[i] = transferred;
            }
        }

        uint256 base_lp_received;
        if (deposit_base) {
            base_lp_received = basePool.addLiquidity(base_amounts, 0, deadline);
        }

        for (uint8 i = 0; i < meta_amounts.length; i++) {
            IERC20 coin = pool.getToken(i);

            uint256 transferred;
            if (address(coin) == address(base_lp)) {
                transferred = base_lp_received;
            } else if (meta_amounts[i] > 0) {
                transferred = transferIn(coin, msg.sender, meta_amounts[i]);
            }

            meta_amounts[i] = transferred;
            if (transferred > 0) {
                coin.safeIncreaseAllowance(address(pool), transferred);
            }
        }

        uint256 base_lp_prior = base_lp.balanceOf(address(this));
        pool.addLiquidity(meta_amounts, minToMint, deadline);
        if (deposit_base) {
            require(
                (base_lp.balanceOf(address(this)) + base_lp_received) ==
                    base_lp_prior,
                "invalidBasePool"
            );
        }

        uint256 lpAmount = token.balanceOf(address(this));
        token.transfer(msg.sender, lpAmount);
        return lpAmount;
    }

    function removeLiquidity(
        ISwap pool,
        ISwap basePool,
        uint256 _amount,
        uint256[] calldata min_amounts_meta,
        uint256[] calldata min_amounts_base,
        uint256 deadline
    )
        external
        returns (uint256[] memory amounts, uint256[] memory base_amounts)
    {
        IERC20 token = pool.getLpToken();
        IERC20 baseToken = basePool.getLpToken();
        token.transferFrom(msg.sender, address(this), _amount);
        token.safeIncreaseAllowance(address(pool), _amount);
        pool.removeLiquidity(_amount, min_amounts_meta, deadline);
        uint256 _base_amount = baseToken.balanceOf(address(this));
        baseToken.safeIncreaseAllowance(address(basePool), _base_amount);

        basePool.removeLiquidity(_base_amount, min_amounts_base, deadline);
        // Transfer all coins out
        amounts = new uint256[](pool.getNumberOfTokens());
        for (uint8 i = 0; i < pool.getNumberOfTokens(); i++) {
            IERC20 coin = pool.getToken(i);
            amounts[i] = coin.balanceOf(address(this));
            if (amounts[i] > 0) {
                coin.safeTransfer(msg.sender, amounts[i]);
            }
        }

        base_amounts = new uint256[](basePool.getNumberOfTokens());
        for (uint8 i = 0; i < basePool.getNumberOfTokens(); i++) {
            IERC20 coin = basePool.getToken(i);
            base_amounts[i] = coin.balanceOf(address(this));
            if (base_amounts[i] > 0) {
                coin.safeTransfer(msg.sender, base_amounts[i]);
            }
        }
    }

    function removeBaseLiquidityOneToken(
        ISwap pool,
        ISwap basePool,
        uint256 _token_amount,
        uint8 i,
        uint256 _min_amount,
        uint256 deadline
    ) external returns (uint256) {
        IERC20 token = pool.getLpToken();
        IERC20 baseToken = basePool.getLpToken();
        uint8 baseTokenIndex = pool.getTokenIndex(address(baseToken));
        token.transferFrom(msg.sender, address(this), _token_amount);
        token.approve(address(pool), _token_amount);
        pool.removeLiquidityOneToken(
            _token_amount,
            baseTokenIndex,
            0,
            deadline
        );
        uint256 _base_amount = baseToken.balanceOf(address(this));
        baseToken.approve(address(basePool), _base_amount);
        basePool.removeLiquidityOneToken(
            _base_amount,
            i,
            _min_amount,
            deadline
        );
        IERC20 coin = basePool.getToken(i);
        uint256 coin_amount = coin.balanceOf(address(this));
        coin.safeTransfer(msg.sender, coin_amount);
        return coin_amount;
    }

    function swapFromBase(
        ISwap pool,
        ISwap basePool,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    ) external returns (uint256) {
        IERC20 baseToken = basePool.getLpToken();
        uint8 baseTokenIndex = pool.getTokenIndex(address(baseToken));
        uint256[] memory base_amounts = new uint256[](
            basePool.getNumberOfTokens()
        );
        base_amounts[tokenIndexFrom] = dx;
        IERC20 coin = basePool.getToken(tokenIndexFrom);
        coin.safeTransferFrom(msg.sender, address(this), dx);
        coin.safeIncreaseAllowance(address(basePool), dx);
        uint256 baseLpAmount = basePool.addLiquidity(base_amounts, 0, deadline);
        if (baseTokenIndex != tokenIndexTo) {
            baseToken.safeIncreaseAllowance(address(pool), baseLpAmount);
            pool.swap(
                baseTokenIndex,
                tokenIndexTo,
                baseLpAmount,
                minDy,
                deadline
            );
        }
        IERC20 coinTo = pool.getToken(tokenIndexTo);
        uint256 amountOut = coinTo.balanceOf(address(this));
        coinTo.safeTransfer(msg.sender, amountOut);
        return amountOut;
    }

    function swapToBase(
        ISwap pool,
        ISwap basePool,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx,
        uint256 minDy,
        uint256 deadline
    ) external returns (uint256) {
        IERC20 baseToken = basePool.getLpToken();
        uint8 baseTokenIndex = pool.getTokenIndex(address(baseToken));
        IERC20 coin = pool.getToken(tokenIndexFrom);
        coin.safeTransferFrom(msg.sender, address(this), dx);
        uint256 tokenLPAmount = dx;
        if (baseTokenIndex != tokenIndexFrom) {
            coin.safeIncreaseAllowance(address(pool), dx);
            tokenLPAmount = pool.swap(
                tokenIndexFrom,
                baseTokenIndex,
                dx,
                0,
                deadline
            );
        }
        baseToken.safeIncreaseAllowance(address(basePool), tokenLPAmount);
        basePool.removeLiquidityOneToken(
            tokenLPAmount,
            tokenIndexTo,
            minDy,
            deadline
        );
        IERC20 coinTo = basePool.getToken(tokenIndexTo);
        uint256 amountOut = coinTo.balanceOf(address(this));
        coinTo.safeTransfer(msg.sender, amountOut);
        return amountOut;
    }

    // =========== VIEW ===========

    function calculateConvert(
        ISwap fromPool,
        ISwap toPool,
        uint256 amount
    ) external view returns (uint256) {
        uint256 fromPoolLength = fromPool.getNumberOfTokens();
        uint256[] memory amounts = fromPool.calculateRemoveLiquidity(amount);
        uint256[] memory meta_amounts = new uint256[](fromPoolLength);
        for (uint8 i = 0; i < fromPoolLength; i++) {
            IERC20 fromCoin = fromPool.getToken(i);
            uint256 toCoinIndex = toPool.getTokenIndex(address(fromCoin));
            meta_amounts[toCoinIndex] = amounts[i];
        }
        return toPool.calculateTokenAmount(meta_amounts, true);
    }

    function calculateTokenAmount(
        ISwap pool,
        ISwap basePool,
        uint256[] memory meta_amounts,
        uint256[] memory base_amounts,
        bool is_deposit
    ) external view returns (uint256) {
        IERC20 baseToken = basePool.getLpToken();
        uint8 baseTokenIndex = pool.getTokenIndex(address(baseToken));
        uint256 _base_tokens = basePool.calculateTokenAmount(
            base_amounts,
            is_deposit
        );
        meta_amounts[baseTokenIndex] =
            meta_amounts[baseTokenIndex] +
            _base_tokens;
        return pool.calculateTokenAmount(meta_amounts, is_deposit);
    }

    function calculateRemoveLiquidity(
        ISwap pool,
        ISwap basePool,
        uint256 amount
    )
        external
        view
        returns (uint256[] memory meta_amounts, uint256[] memory base_amounts)
    {
        IERC20 baseToken = basePool.getLpToken();
        uint8 baseTokenIndex = pool.getTokenIndex(address(baseToken));
        meta_amounts = pool.calculateRemoveLiquidity(amount);
        uint256 lpAmount = meta_amounts[baseTokenIndex];
        meta_amounts[baseTokenIndex] = 0;
        base_amounts = basePool.calculateRemoveLiquidity(lpAmount);
    }

    function calculateRemoveBaseLiquidityOneToken(
        ISwap pool,
        ISwap basePool,
        uint256 _token_amount,
        uint8 iBase
    ) external view returns (uint256 availableTokenAmount) {
        IERC20 baseToken = basePool.getLpToken();
        uint8 baseTokenIndex = pool.getTokenIndex(address(baseToken));
        uint256 _base_tokens = pool.calculateRemoveLiquidityOneToken(
            _token_amount,
            baseTokenIndex
        );
        availableTokenAmount = basePool.calculateRemoveLiquidityOneToken(
            _base_tokens,
            iBase
        );
    }

    function calculateSwapFromBase(
        ISwap pool,
        ISwap basePool,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) external view returns (uint256) {
        IERC20 baseToken = basePool.getLpToken();
        uint8 baseTokenIndex = pool.getTokenIndex(address(baseToken));
        uint256[] memory base_amounts = new uint256[](
            basePool.getNumberOfTokens()
        );
        base_amounts[tokenIndexFrom] = dx;
        uint256 baseLpAmount = basePool.calculateTokenAmount(
            base_amounts,
            true
        );
        if (baseTokenIndex == tokenIndexTo) {
            return baseLpAmount;
        }
        return pool.calculateSwap(baseTokenIndex, tokenIndexTo, baseLpAmount);
    }

    function calculateSwapToBase(
        ISwap pool,
        ISwap basePool,
        uint8 tokenIndexFrom,
        uint8 tokenIndexTo,
        uint256 dx
    ) external view returns (uint256) {
        IERC20 baseToken = basePool.getLpToken();
        uint8 baseTokenIndex = pool.getTokenIndex(address(baseToken));
        uint256 tokenLPAmount = dx;
        if (baseTokenIndex != tokenIndexFrom) {
            tokenLPAmount = pool.calculateSwap(
                tokenIndexFrom,
                baseTokenIndex,
                dx
            );
        }
        return
            basePool.calculateRemoveLiquidityOneToken(
                tokenLPAmount,
                tokenIndexTo
            );
    }

    function transferIn(
        IERC20 token,
        address from,
        uint256 amount
    ) internal returns (uint256 transferred) {
        uint256 prior_balance = token.balanceOf(address(this));
        token.safeTransferFrom(from, address(this), amount);
        transferred = token.balanceOf(address(this)) - prior_balance;
    }
}
