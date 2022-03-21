// SPDX-License-Identifier: MIT

pragma solidity >=0.6.0 <=0.8.0;
pragma experimental ABIEncoderV2;
/*
-------------------------------------- dexRouter.sol ---------------------------------
*/
interface IPancakeswapFactory {
    event PairCreated(address indexed token0, address indexed token1, address pair, uint);

    function feeTo() external view returns (address);
    function feeToSetter() external view returns (address);

    function getPair(address tokenA, address tokenB) external view returns (address pair);
    function allPairs(uint) external view returns (address pair);
    function allPairsLength() external view returns (uint);

    function createPair(address tokenA, address tokenB) external returns (address pair);

    function setFeeTo(address) external;
    function setFeeToSetter(address) external;
}

interface IPancakeswapPair {
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

interface IPancakeswapRouter{
    function factory() external view returns (address);
    function WETH() external view returns (address);

    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB, uint liquidity);
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external payable returns (uint amountToken, uint amountETH, uint liquidity);
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountToken, uint amountETH);
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountA, uint amountB);
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountToken, uint amountETH);
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);
    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        returns (uint[] memory amounts);
    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        payable
        returns (uint[] memory amounts);

    function quote(uint amountA, uint reserveA, uint reserveB) external pure returns (uint amountB);
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) external pure returns (uint amountOut);
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) external pure returns (uint amountIn);
    function getAmountsOut(uint amountIn, address[] calldata path) external view returns (uint[] memory amounts);
    function getAmountsIn(uint amountOut, address[] calldata path) external view returns (uint[] memory amounts);
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external returns (uint amountETH);
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external returns (uint amountETH);

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable;
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external;
}

interface IERC20 {
    event Approval(address indexed owner, address indexed spender, uint value);
    event Transfer(address indexed from, address indexed to, uint value);

    function name() external view returns (string memory);
    function symbol() external view returns (string memory);
    function decimals() external view returns (uint8);
    function totalSupply() external view returns (uint);
    function balanceOf(address owner) external view returns (uint);
    function allowance(address owner, address spender) external view returns (uint);

    function approve(address spender, uint value) external returns (bool);
    function transfer(address to, uint value) external returns (bool);
    function transferFrom(address from, address to, uint value) external returns (bool);

    function mint(address account, uint256 amount) external;
    function burn(address account, uint256 amount) external;
}

interface IWETH {
    function deposit() external payable;
    function transfer(address to, uint value) external returns (bool);
    function withdraw(uint) external;
}

contract PancakeswapRouter is IPancakeswapRouter {
    using SafeMath for uint;

    address public override  factory;
    address public override  WETH;

    modifier ensure(uint deadline) {
        require(deadline >= block.timestamp, 'PancakeswapRouter: EXPIRED');
        _;
    }

    constructor(address _factory, address _WETH)  {
        factory = _factory;
        WETH = _WETH;
    }

    receive() external payable {
        assert(msg.sender == WETH); // only accept ETH via fallback from the WETH contract
    }

    // **** ADD LIQUIDITY ****
    function _addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin
    ) internal virtual returns (uint amountA, uint amountB) {
        // create the pair if it doesn't exist yet
        if (IPancakeswapFactory(factory).getPair(tokenA, tokenB) == address(0)) {
            IPancakeswapFactory(factory).createPair(tokenA, tokenB);
        }
        (uint reserveA, uint reserveB) = PancakeswapLibrary.getReserves(factory, tokenA, tokenB);
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint amountBOptimal = PancakeswapLibrary.quote(amountADesired, reserveA, reserveB);
            if (amountBOptimal <= amountBDesired) {
                require(amountBOptimal >= amountBMin, 'PancakeswapRouter: INSUFFICIENT_B_AMOUNT');
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint amountAOptimal = PancakeswapLibrary.quote(amountBDesired, reserveB, reserveA);
                assert(amountAOptimal <= amountADesired);
                require(amountAOptimal >= amountAMin, 'PancakeswapRouter: INSUFFICIENT_A_AMOUNT');
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
    }
    function addLiquidity(
        address tokenA,
        address tokenB,
        uint amountADesired,
        uint amountBDesired,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint amountA, uint amountB, uint liquidity) {
        (amountA, amountB) = _addLiquidity(tokenA, tokenB, amountADesired, amountBDesired, amountAMin, amountBMin);
        address pair = PancakeswapLibrary.pairFor(factory, tokenA, tokenB);
        TransferHelper.safeTransferFrom(tokenA, msg.sender, pair, amountA);
        TransferHelper.safeTransferFrom(tokenB, msg.sender, pair, amountB);
        liquidity = IPancakeswapPair(pair).mint(to);
    }
    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) external virtual override payable ensure(deadline) returns (uint amountToken, uint amountETH, uint liquidity) {
        (amountToken, amountETH) = _addLiquidity(
            token,
            WETH,
            amountTokenDesired,
            msg.value,
            amountTokenMin,
            amountETHMin
        );
        address pair = PancakeswapLibrary.pairFor(factory, token, WETH);
        TransferHelper.safeTransferFrom(token, msg.sender, pair, amountToken);
        IWETH(WETH).deposit{value: amountETH}();
        assert(IWETH(WETH).transfer(pair, amountETH));
        liquidity = IPancakeswapPair(pair).mint(to);
        // refund dust eth, if any
        if (msg.value > amountETH) TransferHelper.safeTransferETH(msg.sender, msg.value - amountETH);
    }

    // **** REMOVE LIQUIDITY ****
    function removeLiquidity(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountA, uint amountB) {
        address pair = PancakeswapLibrary.pairFor(factory, tokenA, tokenB);
        IPancakeswapPair(pair).transferFrom(msg.sender, pair, liquidity); // send liquidity to pair
        (uint amount0, uint amount1) = IPancakeswapPair(pair).burn(to);
        (address token0,) = PancakeswapLibrary.sortTokens(tokenA, tokenB);
        (amountA, amountB) = tokenA == token0 ? (amount0, amount1) : (amount1, amount0);
        require(amountA >= amountAMin, 'PancakeswapRouter: INSUFFICIENT_A_AMOUNT');
        require(amountB >= amountBMin, 'PancakeswapRouter: INSUFFICIENT_B_AMOUNT');
    }
    function removeLiquidityETH(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountToken, uint amountETH) {
        (amountToken, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, amountToken);
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }
    function removeLiquidityWithPermit(
        address tokenA,
        address tokenB,
        uint liquidity,
        uint amountAMin,
        uint amountBMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountA, uint amountB) {
        address pair = PancakeswapLibrary.pairFor(factory, tokenA, tokenB);
        uint value = approveMax ? type(uint).max : liquidity;
        IPancakeswapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountA, amountB) = removeLiquidity(tokenA, tokenB, liquidity, amountAMin, amountBMin, to, deadline);
    }
    function removeLiquidityETHWithPermit(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountToken, uint amountETH) {
        address pair = PancakeswapLibrary.pairFor(factory, token, WETH);
        uint value = approveMax ? type(uint).max : liquidity;
        IPancakeswapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        (amountToken, amountETH) = removeLiquidityETH(token, liquidity, amountTokenMin, amountETHMin, to, deadline);
    }

    // **** REMOVE LIQUIDITY (supporting fee-on-transfer tokens) ****
    function removeLiquidityETHSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    ) public virtual override ensure(deadline) returns (uint amountETH) {
        (, amountETH) = removeLiquidity(
            token,
            WETH,
            liquidity,
            amountTokenMin,
            amountETHMin,
            address(this),
            deadline
        );
        TransferHelper.safeTransfer(token, to, IERC20(token).balanceOf(address(this)));
        IWETH(WETH).withdraw(amountETH);
        TransferHelper.safeTransferETH(to, amountETH);
    }
    function removeLiquidityETHWithPermitSupportingFeeOnTransferTokens(
        address token,
        uint liquidity,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline,
        bool approveMax, uint8 v, bytes32 r, bytes32 s
    ) external virtual override returns (uint amountETH) {
        address pair = PancakeswapLibrary.pairFor(factory, token, WETH);
        uint value = approveMax ? type(uint).max : liquidity;
        IPancakeswapPair(pair).permit(msg.sender, address(this), value, deadline, v, r, s);
        amountETH = removeLiquidityETHSupportingFeeOnTransferTokens(
            token, liquidity, amountTokenMin, amountETHMin, to, deadline
        );
    }

    // **** SWAP ****
    // requires the initial amount to have already been sent to the first pair
    function _swap(uint[] memory amounts, address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = PancakeswapLibrary.sortTokens(input, output);
            uint amountOut = amounts[i + 1];
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOut) : (amountOut, uint(0));
            address to = i < path.length - 2 ? PancakeswapLibrary.pairFor(factory, output, path[i + 2]) : _to;
            IPancakeswapPair(PancakeswapLibrary.pairFor(factory, input, output)).swap(
                amount0Out, amount1Out, to, new bytes(0)
            );
        }
    }

    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        amounts = PancakeswapLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'PancakeswapRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, PancakeswapLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }

    function swapTokensForExactTokens(
        uint amountOut,
        uint amountInMax,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) returns (uint[] memory amounts) {
        amounts = PancakeswapLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'PancakeswapRouter: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, PancakeswapLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, to);
    }
    
    function swapExactETHForTokens(uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, 'PancakeswapRouter: INVALID_PATH');
        amounts = PancakeswapLibrary.getAmountsOut(factory, msg.value, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'PancakeswapRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(PancakeswapLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
    }

    function swapTokensForExactETH(uint amountOut, uint amountInMax, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, 'PancakeswapRouter: INVALID_PATH');
        amounts = PancakeswapLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= amountInMax, 'PancakeswapRouter: EXCESSIVE_INPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, PancakeswapLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapExactTokensForETH(uint amountIn, uint amountOutMin, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[path.length - 1] == WETH, 'PancakeswapRouter: INVALID_PATH');
        amounts = PancakeswapLibrary.getAmountsOut(factory, amountIn, path);
        require(amounts[amounts.length - 1] >= amountOutMin, 'PancakeswapRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, PancakeswapLibrary.pairFor(factory, path[0], path[1]), amounts[0]
        );
        _swap(amounts, path, address(this));
        IWETH(WETH).withdraw(amounts[amounts.length - 1]);
        TransferHelper.safeTransferETH(to, amounts[amounts.length - 1]);
    }

    function swapETHForExactTokens(uint amountOut, address[] calldata path, address to, uint deadline)
        external
        virtual
        override
        payable
        ensure(deadline)
        returns (uint[] memory amounts)
    {
        require(path[0] == WETH, 'PancakeswapRouter: INVALID_PATH');
        amounts = PancakeswapLibrary.getAmountsIn(factory, amountOut, path);
        require(amounts[0] <= msg.value, 'PancakeswapRouter: EXCESSIVE_INPUT_AMOUNT');
        IWETH(WETH).deposit{value: amounts[0]}();
        assert(IWETH(WETH).transfer(PancakeswapLibrary.pairFor(factory, path[0], path[1]), amounts[0]));
        _swap(amounts, path, to);
        // refund dust eth, if any
        if (msg.value > amounts[0]) TransferHelper.safeTransferETH(msg.sender, msg.value - amounts[0]);
    }

    // **** SWAP (supporting fee-on-transfer tokens) ****
    // requires the initial amount to have already been sent to the first pair
    function _swapSupportingFeeOnTransferTokens(address[] memory path, address _to) internal virtual {
        for (uint i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0,) = PancakeswapLibrary.sortTokens(input, output);
            IPancakeswapPair pair = IPancakeswapPair(PancakeswapLibrary.pairFor(factory, input, output));
            uint amountInput;
            uint amountOutput;
            { // scope to avoid stack too deep errors
            (uint reserve0, uint reserve1,) = pair.getReserves();
            (uint reserveInput, uint reserveOutput) = input == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
            amountInput = IERC20(input).balanceOf(address(pair)).sub(reserveInput);
            amountOutput = PancakeswapLibrary.getAmountOut(amountInput, reserveInput, reserveOutput);
            }
            (uint amount0Out, uint amount1Out) = input == token0 ? (uint(0), amountOutput) : (amountOutput, uint(0));
            address to = i < path.length - 2 ? PancakeswapLibrary.pairFor(factory, output, path[i + 2]) : _to;
            pair.swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external virtual override ensure(deadline) {
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, PancakeswapLibrary.pairFor(factory, path[0], path[1]), amountIn
        );
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'PancakeswapRouter: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }

    function swapExactETHForTokensSupportingFeeOnTransferTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        virtual
        override
        payable
        ensure(deadline)
    {
        require(path[0] == WETH, 'PancakeswapRouter: INVALID_PATH');
        uint amountIn = msg.value;
        IWETH(WETH).deposit{value: amountIn}();
        assert(IWETH(WETH).transfer(PancakeswapLibrary.pairFor(factory, path[0], path[1]), amountIn));
        uint balanceBefore = IERC20(path[path.length - 1]).balanceOf(to);
        _swapSupportingFeeOnTransferTokens(path, to);
        require(
            IERC20(path[path.length - 1]).balanceOf(to).sub(balanceBefore) >= amountOutMin,
            'PancakeswapRouter: INSUFFICIENT_OUTPUT_AMOUNT'
        );
    }

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    )
        external
        virtual
        override
        ensure(deadline)
    {
        require(path[path.length - 1] == WETH, 'PancakeswapRouter: INVALID_PATH');
        TransferHelper.safeTransferFrom(
            path[0], msg.sender, PancakeswapLibrary.pairFor(factory, path[0], path[1]), amountIn
        );
        _swapSupportingFeeOnTransferTokens(path, address(this));
        uint amountOut = IERC20(WETH).balanceOf(address(this));
        require(amountOut >= amountOutMin, 'PancakeswapRouter: INSUFFICIENT_OUTPUT_AMOUNT');
        IWETH(WETH).withdraw(amountOut);
        TransferHelper.safeTransferETH(to, amountOut);
    }

    // **** LIBRARY FUNCTIONS ****
    function quote(uint amountA, uint reserveA, uint reserveB) public pure virtual override returns (uint amountB) {
        return PancakeswapLibrary.quote(amountA, reserveA, reserveB);
    }

    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountOut)
    {
        return PancakeswapLibrary.getAmountOut(amountIn, reserveIn, reserveOut);
    }

    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut)
        public
        pure
        virtual
        override
        returns (uint amountIn)
    {
        return PancakeswapLibrary.getAmountIn(amountOut, reserveIn, reserveOut);
    }

    function getAmountsOut(uint amountIn, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return PancakeswapLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getAmountsIn(uint amountOut, address[] memory path)
        public
        view
        virtual
        override
        returns (uint[] memory amounts)
    {
        return PancakeswapLibrary.getAmountsIn(factory, amountOut, path);
    }
}


library SafeMath {
    function add(uint x, uint y) internal pure returns (uint z) {
        require((z = x + y) >= x, 'ds-math-add-overflow');
    }

    function sub(uint x, uint y) internal pure returns (uint z) {
        require((z = x - y) <= x, 'ds-math-sub-underflow');
    }

    function mul(uint x, uint y) internal pure returns (uint z) {
        require(y == 0 || (z = x * y) / y == x, 'ds-math-mul-overflow');
    }
    function div(uint x, uint y) internal pure returns (uint) {
        return x/y;
    }
}

library PancakeswapLibrary {

    using SafeMath for uint;

    // returns sorted token addresses, used to handle return values from pairs sorted in this order
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        require(tokenA != tokenB, 'PancakeswapLibrary: IDENTICAL_ADDRESSES');
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        require(token0 != address(0), 'PancakeswapLibrary: ZERO_ADDRESS');
    }

    // calculates the CREATE2 address for a pair without making any external calls
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        pair = address(uint160(uint(keccak256(abi.encodePacked(
                hex'ff',
                factory,
                keccak256(abi.encodePacked(token0, token1)),
                hex'a560a29831257f84732ad1b1d23aaa8add153ccad7ed1f90bc94e787a8c32f5f' // init code hash
            )))));
    }

    // fetches and sorts the reserves for a pair
    function getReserves(address factory, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        (address token0,) = sortTokens(tokenA, tokenB);
        (uint reserve0, uint reserve1,) = IPancakeswapPair(pairFor(factory, tokenA, tokenB)).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    // given some amount of an asset and pair reserves, returns an equivalent amount of the other asset
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        require(amountA > 0, 'PancakeswapLibrary: INSUFFICIENT_AMOUNT');
        require(reserveA > 0 && reserveB > 0, 'PancakeswapLibrary: INSUFFICIENT_LIQUIDITY');
        amountB = amountA.mul(reserveB) / reserveA;
    }

    // given an input amount of an asset and pair reserves, returns the maximum output amount of the other asset
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'PancakeswapLibrary: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'PancakeswapLibrary: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }

    // given an output amount of an asset and pair reserves, returns a required input amount of the other asset
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        require(amountOut > 0, 'PancakeswapLibrary: INSUFFICIENT_OUTPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'PancakeswapLibrary: INSUFFICIENT_LIQUIDITY');
        uint numerator = reserveIn.mul(amountOut).mul(1000);
        uint denominator = reserveOut.sub(amountOut).mul(997);
        amountIn = (numerator / denominator).add(1);
    }

    // performs chained getAmountOut calculations on any number of pairs
    function getAmountsOut(address factory, uint amountIn, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'PancakeswapLibrary: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[0] = amountIn;
        for (uint i; i < path.length - 1; i++) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
            amounts[i + 1] = getAmountOut(amounts[i], reserveIn, reserveOut);
        }
    }

    // performs chained getAmountIn calculations on any number of pairs
    function getAmountsIn(address factory, uint amountOut, address[] memory path) internal view returns (uint[] memory amounts) {
        require(path.length >= 2, 'PancakeswapLibrary: INVALID_PATH');
        amounts = new uint[](path.length);
        amounts[amounts.length - 1] = amountOut;
        for (uint i = path.length - 1; i > 0; i--) {
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
}

library TransferHelper {
    function safeApprove(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('approve(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x095ea7b3, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: APPROVE_FAILED');
    }

    function safeTransfer(address token, address to, uint value) internal {
        // bytes4(keccak256(bytes('transfer(address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0xa9059cbb, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FAILED');
    }

    function safeTransferFrom(address token, address from, address to, uint value) internal {
        // bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(0x23b872dd, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'TransferHelper: TRANSFER_FROM_FAILED');
    }

    function safeTransferETH(address to, uint value) internal {
        (bool success,) = to.call{value:value}(new bytes(0));
        require(success, 'TransferHelper: ETH_TRANSFER_FAILED');
    }
}

/*
-------------------------------------- MasterChef.sol ---------------------------------
*/

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }

    function _msgData() internal view virtual returns (bytes calldata) {
        return msg.data;
    }
}

abstract contract Ownable is Context {
    address private _owner;

    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);

    constructor() {
        _transferOwnership(_msgSender());
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    /**
     * @dev Throws if called by any account other than the owner.
     */
    modifier onlyOwner() {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        _transferOwnership(address(0));
    }

    function transferOwnership(address newOwner) public virtual onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal virtual {
        address oldOwner = _owner;
        _owner = newOwner;
        emit OwnershipTransferred(oldOwner, newOwner);
    }
}
// Items, NFTs or resources
interface ERCItem {
    function mint(address account) external;
    function burn(address account, uint256 amount) external;
    function balanceOf(address account) external view returns (uint256);
    function totalSupply() external view returns (uint256);
    function walletOfOwner() external view returns (uint256[] memory);
}
interface IMSCH {
    function totalSupply() external view returns (uint256); 
    function transfer(address to, uint tokens) external returns (bool success);
    function approve(address spender, uint tokens) external returns (bool success);
    function allowance(address tokenOwner, address spender) external view returns (uint remaining);
    function transferFrom(address from, address to, uint tokens) external returns (bool success);
    function mint(address account, uint256 amount) external;
    function burn(address account, uint256 amount) external;
    function balanceOf(address acount) external view returns (uint256);
    function decimals() external view returns (uint256);

    event Transfer(address indexed from, address indexed to, uint tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint tokens);
}
contract MasterChef is Ownable{
    using SafeMath for uint256;

    IMSCH public token;
    address public team;
    address public backup;
    address public airdrop;
    address public designer;
    address public weth;

    address public fridge;
    address public ladle;
    address public kettle;
    address public mixer;
    address public oven;

    IPancakeswapRouter public router;
    address public pair;

    address public usdc = 0x4DBCdF9B62e891a7cec5A2568C3F4FAF9E8Abe2b;                   // To be changed

    struct Stove {
        Recipe food;
        uint createdAt;
    }

    uint public chefCount = 0;
    uint public stoveCount = 0;
    mapping(address => Stove[]) fields;
    mapping(address => uint) syncedAt;
    mapping(address => uint) mschRewardsOpendAt;
    mapping(address => uint) maticRewardsOpendAt;

    constructor(address _token, address _team, address _backup, address _airdrop, address _designer) {
        token = IMSCH(_token);
        team = _team;
        backup = _backup;
        airdrop = _airdrop;
        designer = _designer;
        
        IPancakeswapRouter _pancakeswapRouter = IPancakeswapRouter(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);                 // To be changed
        if(IPancakeswapFactory(_pancakeswapRouter.factory()).getPair(_pancakeswapRouter.WETH(), address(_token)) == address(0)){
            pair = IPancakeswapFactory(_pancakeswapRouter.factory()).createPair(address(_token), _pancakeswapRouter.WETH());
        }else{
            pair = IPancakeswapFactory(_pancakeswapRouter.factory()).getPair(_pancakeswapRouter.WETH(), address(_token));
        }

        weth = _pancakeswapRouter.WETH();
        router = _pancakeswapRouter;
    }
    
    event ChefCreated(address indexed _address);
    event ChefSynced(address indexed _address);

    // Function to receive Ether. msg.data must be empty
    receive() external payable {}

    function addLiquidityFirst() public payable{
        require(msg.value >= 3*10**16, "Insufficient funds for adding liquidity");                  // To be changed
        address[] memory path = new address[](2);
        path[0] = address(weth);
        path[1] = address(token);
   
        token.mint(address(this), msg.value*10000);
        token.approve(address(router), msg.value*10000);
        router.addLiquidityETH{value: msg.value}(
            address(token),
            msg.value*10000,
            0,
            0,
            payable(team),
            block.timestamp + 5 minutes
        );
    }

    function createChef(address _charity) public payable {
        require(syncedAt[msg.sender] == 0, "FARM_EXISTS");

        require(
            // Donation must be at least 3 MATIC to play
            msg.value >= 300 * 10**18,                    // To be changed
            "INSUFFICIENT_DONATION"
        );

        require(
            // The wallet address for the team. eg. Akif
            _charity == team,
            "INVALID_CHARITY"
        );


        Stove[] storage land = fields[msg.sender];      //initialize the stoves for the user in `fields` mapping variable
        Stove memory empty = Stove({
            food: Recipe.None,
            createdAt: 0
        });
        Stove memory crepe = Stove({
            food: Recipe.Crepe,
            createdAt: 0
        });

        // Each farmer starts with 5 fields & 3 crepes
        land.push(empty);
        land.push(crepe);
        land.push(crepe);
        land.push(crepe);
        land.push(empty);

        syncedAt[msg.sender] = block.timestamp;

        // %20 will be transferred to team
        address payable payCharity = payable(_charity);
        payCharity.transfer(msg.value.div(5));

        // %10 will be transferred to backup contract
        address payable receiver = payable(backup);
        receiver.transfer(msg.value.div(10));
        
        // %50 will be added to liquidity pool
        address[] memory path = new address[](2);
        path[0] = address(router.WETH());
        path[1] = address(token);
   
        uint256[] memory desiredTokenAmounts = router.getAmountsOut(msg.value.div(2), path);
        token.mint(address(this), desiredTokenAmounts[1]);
        token.approve(address(router), desiredTokenAmounts[1]);
        router.addLiquidityETH{value: msg.value.div(2)}(
            address(token),
            desiredTokenAmounts[1],
            0,
            0,
            payable(team),
            block.timestamp + 5 minutes
        );

        chefCount += 1;
        stoveCount += 5;
            
        //Emit an event
        emit ChefCreated(msg.sender);
    }
    
    function lastSyncedAt(address owner) public view returns(uint) {
        return syncedAt[owner];
    }

    function lastMaticRewardsOpenedAt (address owner) public view returns(uint) {
        return maticRewardsOpendAt[owner];
    }

    function lastMschRewardsOpenedAt (address owner) public view returns(uint) {
        return mschRewardsOpendAt[owner];
    }

    function getLand(address owner) public view returns (Stove[] memory) {
        return fields[owner];
    }

    enum Action { Plant, Harvest }
    enum Recipe { None, Crepe, Burger , Pizza , Pasta , Chicken , Soup , Steak, Bread, Cake }

    struct Event { 
        Action action;
        Recipe food;
        uint landIndex;
        uint createdAt;
    }

    struct Chef {
        Stove[] land;
        uint balance;
    }

    function getHarvestSeconds(Recipe _food) private view returns (uint) {
        if (_food == Recipe.Crepe) {
            // 1 minute
            return 1 * 60;
        } else if (_food == Recipe.Burger) {
            return 5 * 60;                  // 5 minutes
        } else if (_food == Recipe.Pizza) {
            return 1  * 60 * 60;                    // 1 hour
        } else if (_food == Recipe.Pasta) {
            uint kettleNFTs = ERCItem(kettle).balanceOf(address(msg.sender));
            if(kettleNFTs == 0){
                return 2 * 60 * 60;                 // 2 hours
            } else{
                return 2 * 60 * 60 / 3;             // 40 min for Kettle owners
            }
        } else if (_food == Recipe.Chicken) {
            return 4 * 60 * 60;                 // 4 hours
        } else if (_food == Recipe.Soup) {
            uint mixerNFTs = ERCItem(mixer).balanceOf(address(msg.sender));
            if(mixerNFTs == 0){
                return 8 * 60 * 60;                 // 8 hours
            } else{
                return 8 * 60 * 60 / 3;             // 2 hour 40 min for Mixer owners
            }
        }
        else if (_food == Recipe.Steak) {
            return 6 * 60 * 60;                 // 8 hours
        } else if (_food == Recipe.Bread) {
            return 1 * 24 * 60 * 60;                    // 1 days
        }
        else if (_food == Recipe.Cake) {
            uint ovenNFTs = ERCItem(oven).balanceOf(address(msg.sender));
            if(ovenNFTs == 0){
                return 3 * 24 * 60 * 60;                 // 3 days
            } else{
                return 3 * 24 * 60 * 60 / 3;            // 1 day for Oven owners
            }
        }

        require(false, "INVALID_HARVEST_SECONDS");
        return 9999999;
    }

    function getPlantPrice(Recipe _food) private view returns (uint price) {
        uint decimals = token.decimals();

        if (_food == Recipe.Crepe) {
            //$0.002
            return 2 * 10**decimals / 1000;
        } else if (_food == Recipe.Burger) {
            // $0.02
            return 2 * 10**decimals / 100;
        } else if (_food == Recipe.Pizza) {
            // $0.12
            return 12 * 10**decimals / 100;
        } else if (_food == Recipe.Pasta) {
            // $0.2
            return 20 * 10**decimals/100;
        } else if (_food == Recipe.Chicken) {
            // $0.4
            return 4 * 10**decimals/10;
        } else if (_food == Recipe.Soup) {
            // $0.8
            return 8 * 10**decimals/10;
        } else if (_food == Recipe.Steak) {
            // $1.2
            return 12 * 10**decimals/10;
        }else if (_food == Recipe.Bread) {
            // $3
            return 3 * 10**decimals;
        }else if (_food == Recipe.Cake) {
            // $10
            return 10 * 10**decimals;
        }

        require(false, "INVALID_PLANT_PRICE");

        return 100000 * 10**decimals;
    }

    function getHarvestPrice(Recipe _food) public view returns (uint price) {
        uint decimals = token.decimals();

        if (_food == Recipe.Crepe) {
            //$0.004
            return 4 * 10**decimals / 1000;
        } else if (_food == Recipe.Burger) {
            // $0.032
            return 32 * 10**decimals / 1000;
        } else if (_food == Recipe.Pizza) {
            // $0.24
            return 24 * 10**decimals / 100;
        } else if (_food == Recipe.Pasta) {
            // $0.4
            return 4 * 10**decimals / 10;
        } else if (_food == Recipe.Chicken) {
            // $0.8
            return 8 * 10**decimals / 10;
        } else if (_food == Recipe.Soup) {
            // $1.6
            return 16 * 10**decimals / 10;
        } else if (_food == Recipe.Steak) {
            // $2
            return 2 * 10**decimals;
        }else if (_food == Recipe.Bread) {
            // $6
            return 6 * 10**decimals;
        }else if (_food == Recipe.Cake) {
            // $18
            return 18 * 10**decimals;
        }

        require(false, "INVALID_HARVEST_PRICE");

        return 0;
    }
    
    function requiredLandSize(Recipe _food) private pure returns (uint size) {
        if (_food == Recipe.Crepe || _food == Recipe.Burger) {
            return 5;
        } else if (_food == Recipe.Pizza || _food == Recipe.Pasta) {
            return 8;
        } else if (_food == Recipe.Chicken) {
            return 11;
        } else if (_food == Recipe.Soup  || _food == Recipe.Steak) {
            return 14;
        } else if (_food == Recipe.Bread || _food == Recipe.Cake) {
            return 17;
        }

        require(false, "INVALID_LAND_SIZE");

        return 99;
    }
    
       
    function getLandPrice(uint landSize) private view returns (uint price) {
        uint decimals = token.decimals();
        if (landSize == 5) {
            return 2 * 10**decimals;
        } else if (landSize == 8) {
            return 10 * 10**decimals;
        } else if (landSize == 11) {
            return 30 * 10**decimals;
        } else if (landSize == 14) {
            return 100 * 10**decimals;
        }
        
        return 100 * 10**decimals;
    }

    modifier hasChef {
        require(lastSyncedAt(msg.sender) > 0, "NO_FARM");
        _;
    }
     
    uint private SAVING_TIME = 25 * 60;

    function buildFarm(Event[] memory _events) private view hasChef returns (Chef memory currentFarm) {
        Stove[] memory land = fields[msg.sender];
        uint balance = token.balanceOf(msg.sender);
        
        for (uint index = 0; index < _events.length; index++) {
            Event memory farmEvent = _events[index];

            uint savingTimeAgo = block.timestamp.sub(SAVING_TIME); 
            require(farmEvent.createdAt >= savingTimeAgo, "EVENT_EXPIRED");
            require(farmEvent.createdAt >= lastSyncedAt(msg.sender), "EVENT_IN_PAST");
            require(farmEvent.createdAt <= block.timestamp, "EVENT_IN_FUTURE");

            if (index > 0) {
                require(farmEvent.createdAt >= _events[index - 1].createdAt, "INVALID_ORDER");
            }

            if (farmEvent.action == Action.Plant) {
                require(land.length >= requiredLandSize(farmEvent.food), "INVALID_LEVEL");
                
                uint price = getPlantPrice(farmEvent.food);
                uint fmcPrice = getMarketPrice(price);
                require(balance >= fmcPrice, "INSUFFICIENT_FUNDS");

                balance = balance.sub(fmcPrice);

                Stove memory mixedDough = Stove({
                    food: farmEvent.food,
                    createdAt: farmEvent.createdAt
                });
                land[farmEvent.landIndex] = mixedDough;
            } else if (farmEvent.action == Action.Harvest) {
                Stove memory stove = land[farmEvent.landIndex];
                require(stove.food != Recipe.None, "NO_FRUIT");

                uint duration = farmEvent.createdAt.sub(stove.createdAt);
                uint secondsToHarvest = getHarvestSeconds(stove.food);                  // To be inserted: nfts ownership
                require(duration >= secondsToHarvest, "NOT_RIPE");

                // Clear the land
                Stove memory emptyLand = Stove({
                    food: Recipe.None,
                    createdAt: 0
                });
                land[farmEvent.landIndex] = emptyLand;

                uint price = getHarvestPrice(stove.food);
                uint fmcPrice = getMarketPrice(price);

                balance = balance.add(fmcPrice);
            }
        }

        return Chef({
            land: land,
            balance: balance
        });
    }


    function sync(Event[] memory _events) public hasChef returns (Chef memory) {
        Chef memory farm = buildFarm(_events);

        // Update the land
        Stove[] storage land = fields[msg.sender];
        for (uint i=0; i < farm.land.length; i += 1) {
            land[i] = farm.land[i];
        }
        
        syncedAt[msg.sender] = block.timestamp;
        
        uint balance = token.balanceOf(msg.sender);
        // Update the balance - mint or burn
        if (farm.balance > balance) {
            uint profit = farm.balance.sub(balance);
            token.mint(msg.sender, profit);
        } else if (farm.balance < balance) {
            uint loss = balance.sub(farm.balance);
            token.burn(msg.sender, loss);
        }

        emit ChefSynced(msg.sender);

        return farm;
    }

    function levelUp() public hasChef {
        require(fields[msg.sender].length <= 17, "MAX_LEVEL");
        
        Stove[] storage land = fields[msg.sender];

        uint price = getLandPrice(land.length);
        uint fmcPrice = getMarketPrice(price);
        uint balance = token.balanceOf(msg.sender);

        require(balance >= fmcPrice, "INSUFFICIENT_FUNDS");
        require(token.allowance(address(msg.sender), address(this)) >= fmcPrice, "NOT_ENOUGH_ALLOWANCE");
        
        // Store rewards in the Chef Contract to redistribute
        TransferHelper.safeTransferFrom(address(token), address(msg.sender), address(this), fmcPrice);

        token.burn(address(this), fmcPrice.div(5));                // %20 will be burnt

        TransferHelper.safeTransfer(address(token), address(airdrop), fmcPrice.div(5));             // %20 will be saved at airdrop wallet
        TransferHelper.safeTransfer(address(token), address(backup), fmcPrice.div(5));              // %20 will be transferred to backup contract
        TransferHelper.safeTransfer(address(token), address(team), fmcPrice.div(5));                // %20 will be transferred to team
        // Add 3 crepes fields in the new fields
        Stove memory crepe = Stove({
            food: Recipe.Crepe,
            // Make them immediately harvestable in case they spent all their tokens
            createdAt: 0
        });

        for (uint index = 0; index < 3; index++) {
            land.push(crepe);
        }

        stoveCount += 3;
        emit ChefSynced(msg.sender);
    }

    // How many tokens do you get per dollar
    // Algorithm is totalSupply / 10000 but we do this in gradual steps to avoid widly flucating prices between plant & harvest
    function getMarketRate() private view returns (uint conversion) {
        uint decimals = token.decimals();
        uint totalSupply = token.totalSupply();

        // Less than 500, 000 tokens
        if (totalSupply < (500000 * 10**decimals)) {
            return 1;
        }

        // Less than 1, 000, 000 tokens
        if (totalSupply < (1000000 * 10**decimals)) {
            return 2;
        }

        // Less than 5, 000, 000 tokens
        if (totalSupply < (5000000 * 10**decimals)) {
            return 4;
        }

        // Less than 10, 000, 000 tokens
        if (totalSupply < (10000000 * 10**decimals)) {
            return 8;
        }

        // 1 Chef Dollar gets you a 0.00001 of a token - Linear growth from here
        return 16;
    }

    function getMarketPrice(uint price) public view returns (uint conversion) {
        uint marketRate = getMarketRate();

        return price.div(marketRate);
    }
    
    function getChefCount() public view returns (uint count) {
        return chefCount;
    }

    
    // Depending on the fields you have determines your cut of the rewards.
    function myReward() public view hasChef returns (uint amount) {        
        uint lastOpenDate = mschRewardsOpendAt[msg.sender];

        // Block timestamp is seconds based
        uint threeDaysAgo = block.timestamp.sub(60 * 60 * 24 * 3);              // To be changed

        require(lastOpenDate < threeDaysAgo, "NO_REWARD_READY");

        uint landSize = fields[msg.sender].length;
        uint chefBalance = token.balanceOf(address(this));

        uint totalLadle = ERCItem(ladle).totalSupply();
        // level/sum * ( prize pool/total ladle count )
        uint chefShare = chefBalance.mul(landSize).div(stoveCount).div(totalLadle);

        return chefShare;
    }

    //my bnb reward

    function myMaticReward() public view hasChef returns (uint amount) {        
        uint lastOpenDate = maticRewardsOpendAt[msg.sender];

        // Block timestamp is seconds based
        uint threeDaysAgo = block.timestamp.sub(60 * 60 * 24 * 3);                //To be changed 

        require(lastOpenDate < threeDaysAgo, "NO_REWARD_READY");

        uint landSize = fields[msg.sender].length;
        uint chefBalance = address(this).balance;

        uint totalFridge = ERCItem(fridge).totalSupply();
        // level/sum * ( prize pool/total ladle count )
        uint chefShare = chefBalance.mul(landSize).div(stoveCount).div(totalFridge);
        
        return chefShare;
    }

    //receive msch rewards

    function receiveReward() public hasChef {
        uint amount = myReward();
        uint ladleNFTId = ERCItem(ladle).balanceOf(address(msg.sender));
        require(ladleNFTId != 0, "NO LADLE");
        require(amount > 0, "NO_REWARD_MSCH");
        require(token.balanceOf(address(this)) >= amount, "Insufficent funds");

        mschRewardsOpendAt[msg.sender] = block.timestamp;
        token.transfer(msg.sender, amount);
    }

    //receive matic rewards

    function receiveMaticReward() public hasChef {
        uint amount = myMaticReward();
        uint fridgeNFTId = ERCItem(fridge).balanceOf(address(msg.sender));
        require(fridgeNFTId != 0, "NO FRIDGE");
        require(amount > 0, "NO_REWARD_MATIC");
        require(address(this).balance >= amount, "Insufficent funds");
        maticRewardsOpendAt[msg.sender] = block.timestamp;
        address payable receiver = payable(msg.sender);
        receiver.transfer(amount);
    }

    function getBlockTimestamp() public view returns(uint256 timestamp) {
        timestamp = block.timestamp;

        return timestamp;
    }
    
    enum NFT{ None, Fridge, Ladle, Kettle, Mixer, Oven }

    function getNFTsState() public view returns(uint fridgeNFTs, uint ladleNFTs, uint kettleNFTs, uint mixerNFTs, uint ovenNFTs) {
        fridgeNFTs = ERCItem(fridge).balanceOf(address(msg.sender));
        ladleNFTs = ERCItem(ladle).balanceOf(address(msg.sender));
        kettleNFTs = ERCItem(kettle).balanceOf(address(msg.sender));
        mixerNFTs = ERCItem(mixer).balanceOf(address(msg.sender));
        ovenNFTs = ERCItem(oven).balanceOf(address(msg.sender));

        return (fridgeNFTs, ladleNFTs, kettleNFTs, mixerNFTs, ovenNFTs);
    }
    
    function setNFTAddress(address _fridge, address _ladle, address _kettle, address _mixer, address _oven) public onlyOwner {
        fridge = _fridge;
        ladle = _ladle;
        kettle = _kettle;
        mixer = _mixer;
        oven = _oven;
    }

    function mintFridge() public payable hasChef {
        require(msg.value >= 300*10**18, "Insufficient funds");               // to be changed
        require(fridge != address(0), "Fridge NFT address is not set yet");
        require(kettle != address(0), "Kettle NFT address is not set yet");
        require(mixer != address(0), "Mixer NFT address is not set yet");
        require(oven != address(0), "Oven NFT address is not set yet");
        ERCItem(fridge).mint(msg.sender);
        ERCItem(kettle).mint(msg.sender);
        ERCItem(mixer).mint(msg.sender);
        ERCItem(oven).mint(msg.sender);
        maticRewardsOpendAt[msg.sender] = block.timestamp;
        
        address[] memory path = new address[](2);
        path[0] = address(router.WETH());
        path[1] = address(token);
        uint256[] memory desiredTokenAmounts = router.getAmountsOut(msg.value.div(2), path);
        token.mint(address(this), desiredTokenAmounts[1]);
        token.approve(address(router), desiredTokenAmounts[1]);
        router.addLiquidityETH{value: msg.value.div(2)}(
            address(token),
            desiredTokenAmounts[1],
            0,
            0,
            payable(team),
            block.timestamp + 5 minutes
        );

        TransferHelper.safeTransferETH(address(designer), msg.value.div(5));
        TransferHelper.safeTransferETH(address(backup), msg.value.div(10));
        TransferHelper.safeTransferETH(address(team), msg.value.div(5));
    }

    function mintNFT(NFT _symbol) public hasChef{
        uint256 price;
        if(_symbol == NFT.Ladle){
            price = 300*10**IERC20(usdc).decimals();                 // To be changed
            require(IERC20(usdc).balanceOf(msg.sender) >= price, "Insufficient USDC funds");
            require(IERC20(usdc).allowance(msg.sender, address(this)) >= price, "Not enough Allowance");
            ERCItem(ladle).mint(msg.sender);
            mschRewardsOpendAt[msg.sender] = block.timestamp;

        }else if(_symbol == NFT.Kettle){
            price = 200*10**IERC20(usdc).decimals();                 // To be changed
            require(kettle != address(0), "Kettle NFT address is not set yet");
            require(IERC20(usdc).balanceOf(msg.sender) >= price, "Insufficient USDC funds");
            require(IERC20(usdc).allowance(msg.sender, address(this)) >= price, "Not enough Allowance");
            ERCItem(kettle).mint(msg.sender);

        }else if(_symbol == NFT.Mixer){
            price = 200*10**IERC20(usdc).decimals();                 // To be changed
            require(mixer != address(0), "Mixer NFT address is not set yet");
            require(IERC20(usdc).balanceOf(msg.sender) >= price, "Insufficient USDC funds");
            require(IERC20(usdc).allowance(msg.sender, address(this)) >= price, "Not enough Allowance");
            ERCItem(mixer).mint(msg.sender);
            
        }else if(_symbol == NFT.Oven){
            price = 200*10**IERC20(usdc).decimals();                 // To be changed
            require(oven != address(0), "Oven NFT address is not set yet");
            require(IERC20(usdc).balanceOf(msg.sender) >= price, "Insufficient USDC funds");
            require(IERC20(usdc).allowance(msg.sender, address(this)) >= price, "Not enough Allowance");
            ERCItem(oven).mint(msg.sender);
        }
        
        TransferHelper.safeTransferFrom(address(usdc), address(msg.sender), address(this), price);             // Get USDC from minter to this contract

        uint256 initialBalance = address(this).balance;                                             // Swap USDC for wMatic to add liquidity
        // generate the uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = usdc;
        path[1] = router.WETH();

        TransferHelper.safeApprove(address(usdc), address(router), price.div(2)) ;
        // make the swap
        router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            price.div(2) ,
            0, // accept any amount of ETH
            path,
            address(this), // The contract
            block.timestamp + 5 minutes
        );

        uint256 transferredBalance = address(this).balance - initialBalance;
        
        address[] memory pathToken = new address[](2);                                                    // %50 will be added to liquidity pool
        pathToken[0] = address(router.WETH());
        pathToken[1] = address(token);
        uint256[] memory desiredTokenAmounts = router.getAmountsOut(transferredBalance, pathToken);
        token.mint(address(this), desiredTokenAmounts[1]);
        token.approve(address(router), desiredTokenAmounts[1]);
        router.addLiquidityETH{value: transferredBalance}(
            address(token),
            desiredTokenAmounts[1],
            0,
            0,
            payable(team),
            block.timestamp + 5 minutes
        );

        TransferHelper.safeTransfer(address(usdc), designer, price.div(5));                 // %20 will be rewarded to designers
        TransferHelper.safeTransfer(address(usdc), backup, price.div(10));                  // %%10 will be rewarded to backup
        TransferHelper.safeTransfer(address(usdc), team, price.div(5));                     // %20 will be rewarded to team
    }
}