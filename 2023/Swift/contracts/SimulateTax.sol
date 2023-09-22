// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";


interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}

interface IPancakePair {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external pure returns (string memory);
    function symbol() external pure returns (string memory);
    function decimals() external pure returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function DOMAIN_SEPARATOR() external view returns (bytes32);
    function PERMIT_TYPEHASH() external pure returns (bytes32);
    function nonces(address owner) external view returns (uint);

    function permit(address owner, address spender, uint value, uint deadline, uint8 v, bytes32 r, bytes32 s) external;

    event Mint(address indexed sender, uint amount0, uint amount1);
    event Burn(address indexed sender, uint amount0, uint amount1, address indexed to);
    event Swap(
        address indexed sender,
        uint amount0In,
        uint amount1In,
        uint amount0Out,
        uint amount1Out,
        address indexed to
    );
    event Sync(uint112 reserve0, uint112 reserve1);

    function MINIMUM_LIQUIDITY() external pure returns (uint);
    function factory() external view returns (address);
    function token0() external view returns (address);
    function token1() external view returns (address);
    function getReserves() external view returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
    function price0CumulativeLast() external view returns (uint);
    function price1CumulativeLast() external view returns (uint);
    function kLast() external view returns (uint);

    function mint(address to) external returns (uint liquidity);
    function burn(address to) external returns (uint amount0, uint amount1);
    function swap(uint amount0Out, uint amount1Out, address to, bytes calldata data) external;
    function skim(address to) external;
    function sync() external;

    function initialize(address, address) external;
}

contract SimulateTax {
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut, uint256 feeDeduct) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'PancakeLibrary: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'PancakeLibrary: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn * (10000 - feeDeduct);
        uint numerator = amountInWithFee * reserveOut;
        uint denominator = reserveIn * 10000 + amountInWithFee;
        amountOut = numerator / denominator;
    }

    function pairSwap(address currentPair, address currentToken, address _to, uint256 feeDeduct) internal returns (uint256) {
        IPancakePair pair = IPancakePair(currentPair);
        uint amountInput;
        uint amountOutput;
        { // scope to avoid stack too deep errors
            (uint reserve0, uint reserve1,) = pair.getReserves();
            (uint reserveInput, uint reserveOutput) = pair.token0() == currentToken ? (reserve0, reserve1) : (reserve1, reserve0);
            amountInput = IERC20(currentToken).balanceOf(address(pair)) - reserveInput;
            amountOutput = getAmountOut(amountInput, reserveInput, reserveOutput, feeDeduct);
        }
        (uint amount0Out, uint amount1Out) = pair.token0() == currentToken ? (uint(0), amountOutput) : (amountOutput, uint(0));
        pair.swap(amount0Out, amount1Out, _to, new bytes(0));

        return amount0Out > 0? amount0Out: amount1Out;
    }

    function testTax(address token, address weth, address[] calldata pairChain, uint256 feeDeduct) external payable returns (
        uint256 totalBuyAmount,
        uint256 boughtAmount,
        uint256 totalSellAmount,
        uint256 soldAmount
    ) {
        IERC20 tokenContract = IERC20(token);
        require(pairChain.length > 0, "Null pair chain");
        require(IPancakePair(pairChain[0]).token0() == weth || IPancakePair(pairChain[0]).token1() == weth, "WETH is not set");

        {
            uint amountIn = msg.value;
            IWETH(weth).deposit{value: amountIn}();
            assert(IWETH(weth).transfer(pairChain[0], amountIn));
        }

        address[] memory tokenChain = new address[](pairChain.length + 1);
        {
            tokenChain[0] = weth;
            uint256 i;
            for (i = 1; i < tokenChain.length; i ++) {
                if (IPancakePair(pairChain[i - 1]).token0() == tokenChain[i - 1]) tokenChain[i] = IPancakePair(pairChain[i - 1]).token1();
                else if (IPancakePair(pairChain[i - 1]).token1() == tokenChain[i - 1]) tokenChain[i] = IPancakePair(pairChain[i - 1]).token0();
                else revert("Not valid pair chain");
            }

            require(token == tokenChain[tokenChain.length - 1], "Token not set");
        }

        {
            // buy chain processing
            address to = address(this);
            uint256 oldBalance = tokenContract.balanceOf(to);

            //_swapSupportingFeeOnTransferTokens(path, to)
            for (uint256 i = 0; i < tokenChain.length - 1; i++) {
                uint256 outAmount = pairSwap(pairChain[i], tokenChain[i], i < tokenChain.length - 2 ? pairChain[i + 1]: to, feeDeduct);

                if (i >= tokenChain.length - 2) {
                    totalBuyAmount = outAmount;
                }
            }

            boughtAmount = tokenContract.balanceOf(to) - oldBalance;
        }
        {
            // sell chain processing
            // address to = address(this);
            IPancakePair pair;
            bool bFirstToken;
            {
                address tokenPair = pairChain[pairChain.length - 1];
                pair = IPancakePair(tokenPair);
                bFirstToken = pair.token0() == token;

                // (uint oldReserve0, uint oldReserve1,) = pair.getReserves();
                // (uint oldReserveInput, uint oldReserveOutput) = bFirstToken ? (oldReserve0, oldReserve1) : (oldReserve1, oldReserve0);

                tokenContract.transfer(tokenPair, boughtAmount);
                
                (uint newReserve0, uint newReserve1,) = pair.getReserves();
                (uint newReserveInput, ) = bFirstToken ? (newReserve0, newReserve1) : (newReserve1, newReserve0);

                soldAmount = tokenContract.balanceOf(tokenPair) - newReserveInput;
                // if (newReserveInput > oldReserveInput) { // contract sell
                // } else if (newReserveInput < oldReserveInput) { // contract buy
                // }
            }

            totalSellAmount = boughtAmount;
            // uint256 outAmount = pairSwap(address(pair), token, to);
        }
    }

    receive() external payable {
    }
}
