// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IERC20 {
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function approve(address spender, uint value) external returns (bool);

    function transfer(address to, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);

    function decimals() external view returns (uint8);
}

interface IPulseRouter {
    function swapExactTokensForTokens(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactTokensForETH(
        uint amountIn,
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external returns (uint[] memory amounts);

    function swapExactETHForTokens(
        uint amountOutMin,
        address[] calldata path,
        address to,
        uint deadline
    ) external payable returns (uint[] memory amounts);

    function addLiquidityETH(
        address token,
        uint amountTokenDesired,
        uint amountTokenMin,
        uint amountETHMin,
        address to,
        uint deadline
    )
        external
        payable
        returns (uint amountToken, uint amountETH, uint liquidity);

    function getAmountOut(
        uint amountIn,
        uint reserveIn,
        uint reserveOut
    ) external pure returns (uint amountOut);

    function factory() external pure returns (address);
}

interface IPulsePair {
    function getReserves()
        external
        view
        returns (uint112 reserve0, uint112 reserve1, uint32 blockTimestampLast);
}

interface IPulseFactory {
    function getPair(
        address tokenA,
        address tokenB
    ) external view returns (address pair);
}

contract HLAWZapper is Ownable, ReentrancyGuard {
    IPulseRouter private pulseRouter =
        IPulseRouter(0x98bf93ebf5c380C0e6Ae8e192A7e2AE08edAcc02);
    IERC20 private dai = IERC20(0xefD766cCb38EaF1dfd701853BFCe31359239F305);
    IERC20 private wpls = IERC20(0xA1077a294dDE1B09bB078844df40758a5D0f9a27);

    uint256 private denominator = 10000;
    uint256 public convenienceFee = 0;
    address public treasury;

    mapping(address => bool) public zapCurrs;

    event Zapped(
        address user,
        address curr,
        uint256 currAmount,
        uint256 lpAmount
    );

    constructor() Ownable(msg.sender) {
        zapCurrs[0xA1077a294dDE1B09bB078844df40758a5D0f9a27] = true; // PLS Wrapped
        zapCurrs[0x95B303987A60C71504D99Aa1b13B4DA07b0790ab] = true; // PLSX
        zapCurrs[0x2fa878Ab3F87CC1C9737Fc071108F904c0B0C95d] = true; // INC
        zapCurrs[0x02DcdD04e3F455D838cd1249292C58f3B79e3C3C] = true; // WETH
        zapCurrs[0xefD766cCb38EaF1dfd701853BFCe31359239F305] = true; // DAI
        zapCurrs[0x0Cb6F5a34ad42ec934882A05265A7d5F59b51A2f] = true; // USDT
        zapCurrs[0x15D38573d2feeb82e7ad5187aB8c1D52810B1f07] = true; // USDC
        zapCurrs[0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39] = true; // PHEX
        zapCurrs[0x57fde0a71132198BBeC939B98976993d8D89D225] = true; // EHEX

        IERC20(0x95B303987A60C71504D99Aa1b13B4DA07b0790ab).approve(
            address(pulseRouter),
            type(uint256).max
        );
        IERC20(0x2fa878Ab3F87CC1C9737Fc071108F904c0B0C95d).approve(
            address(pulseRouter),
            type(uint256).max
        );
        IERC20(0x02DcdD04e3F455D838cd1249292C58f3B79e3C3C).approve(
            address(pulseRouter),
            type(uint256).max
        );
        IERC20(0xefD766cCb38EaF1dfd701853BFCe31359239F305).approve(
            address(pulseRouter),
            type(uint256).max
        );
        IERC20(0x0Cb6F5a34ad42ec934882A05265A7d5F59b51A2f).approve(
            address(pulseRouter),
            type(uint256).max
        );
        IERC20(0x15D38573d2feeb82e7ad5187aB8c1D52810B1f07).approve(
            address(pulseRouter),
            type(uint256).max
        );
        IERC20(0x2b591e99afE9f32eAA6214f7B7629768c40Eeb39).approve(
            address(pulseRouter),
            type(uint256).max
        );
        IERC20(0x57fde0a71132198BBeC939B98976993d8D89D225).approve(
            address(pulseRouter),
            type(uint256).max
        );

        treasury = msg.sender;
    }

    function withdraw() public onlyOwner {
        uint256 balance = address(this).balance;
        payable(msg.sender).transfer(balance);
    }

    function withdrawTokens(
        address _tokenAddress,
        uint256 _amount
    ) public onlyOwner {
        require(
            _amount <= IERC20(_tokenAddress).balanceOf(address(this)),
            "Insufficient token balance in contract."
        );

        IERC20(_tokenAddress).transfer(address(msg.sender), _amount);
    }

    function setCurr(address _curr, bool _allowed) public onlyOwner {
        require(_curr != address(0), "Invalid address set.");
        if (!_allowed) {
            zapCurrs[_curr] = false;
            IERC20(_curr).approve(address(pulseRouter), 0);
        } else {
            zapCurrs[_curr] = true;
            IERC20(_curr).approve(address(pulseRouter), type(uint256).max);
        }
    }

    function setFeeAndTreasury(
        uint256 _newFee,
        address _treasury
    ) public onlyOwner {
        require(_treasury != address(0), "Invalid treasury address set.");
        convenienceFee = _newFee;
        require(convenienceFee <= 30, "Max 0.3 percent");
        treasury = _treasury;
    }

    function zapTokens(
        address _curr,
        uint256 _currAmount,
        uint256 _amountOutMin1,
        uint256 _amountOutMin2,
        uint256 _amountOutMin3
    ) external nonReentrant returns (uint256) {
        //Requires
        require(
            zapCurrs[_curr],
            "Must be one of the allowed currencies to zap"
        );

        uint256 feeAmount = 0;
        if (convenienceFee > 0) {
            feeAmount = (_currAmount * convenienceFee) / denominator;
            _currAmount = _currAmount - feeAmount;
        }

        // Track starting balances
        uint256 currBefore = IERC20(_curr).balanceOf(address(this));
        uint256 plsBefore = address(this).balance;
        uint256 daiBefore = dai.balanceOf(address(this));

        // Transfer _curr from user
        IERC20(_curr).transferFrom(msg.sender, address(this), _currAmount);
        if (feeAmount > 0) {
            IERC20(_curr).transferFrom(
                msg.sender,
                address(treasury),
                feeAmount
            );
        }

        // Swap and track PLS/DAI gained
        (uint256 plsAmount, uint256 daiAmount) = _swapTokens(
            _curr,
            _currAmount,
            _amountOutMin1,
            _amountOutMin2,
            _amountOutMin3
        );

        // Add LP and track the amount of LP tokens gained
        (, , uint256 lpTokensGained) = pulseRouter.addLiquidityETH{
            value: plsAmount
        }(address(dai), daiAmount, 0, 0, address(msg.sender), block.timestamp);

        // There may be dust remnants remaining, we will refund any dust back to the user
        if (address(this).balance > plsBefore) {
            uint256 plsRefund = address(this).balance - plsBefore;
            (bool success, ) = payable(msg.sender).call{value: plsRefund, gas: 30000}("");
            success;
        }

        if (dai.balanceOf(address(this)) > daiBefore) {
            uint256 daiRefund = dai.balanceOf(address(this)) - daiBefore;
            dai.transfer(msg.sender, daiRefund);
        }

        if (IERC20(_curr).balanceOf(address(this)) > currBefore) {
            uint256 currRefund = IERC20(_curr).balanceOf(address(this)) -
                currBefore;
            IERC20(_curr).transfer(msg.sender, currRefund);
        }

        emit Zapped(msg.sender, _curr, _currAmount, lpTokensGained);
        return lpTokensGained;
    }

    function zapPls(
        uint256 _amountOutMin
    ) external payable nonReentrant returns (uint256) {
        // Track starting balances
        uint256 daiBefore = dai.balanceOf(address(this));
        uint256 zapAmount = msg.value;
        uint256 feeAmount = 0;

        // Apply convenience fee if necessary
        if (convenienceFee > 0) {
            feeAmount = (msg.value * convenienceFee) / denominator;
            zapAmount = msg.value - feeAmount;
            (bool success, ) = payable(treasury).call{value: feeAmount, gas: 30000}("");
            success;
        }

        // Swap and track PLS/DAI gained
        (uint256 plsAmount, uint256 daiAmount) = _swapPls(
            zapAmount / 2,
            _amountOutMin
        );

        // Track remaining PLS before adding liquidity
        uint256 plsRemainingBeforeAddLiquidity = address(this).balance;

        // Add liquidity and track the amount of LP tokens gained
        (, , uint256 lpTokensGained) = pulseRouter.addLiquidityETH{
            value: plsAmount
        }(address(dai), daiAmount, 0, 0, msg.sender, block.timestamp);

        // Calculate PLS used for liquidity
        uint256 plsUsed = plsRemainingBeforeAddLiquidity -
            address(this).balance;

        // Refund any PLS remaining that was not used for liquidity or other processes
        uint256 plsRefund = zapAmount - plsUsed - feeAmount;
        if (plsRefund > 0) {
            (bool success, ) = payable(msg.sender).call{value: plsRefund, gas: 30000}("");
            success;
        }

        // Refund any excess DAI dust
        uint256 daiRemaining = dai.balanceOf(address(this)) - daiBefore;
        if (daiRemaining > 0) {
            dai.transfer(msg.sender, daiRemaining);
        }

        emit Zapped(msg.sender, address(0), zapAmount, lpTokensGained);
        return lpTokensGained;
    }

    function _swapPls(
        uint256 _amount,
        uint256 _amountOutMin
    ) internal returns (uint256, uint256) {
        // Track staring balances
        uint256 daiBefore = dai.balanceOf(address(this));

        // Swap 50% of PLS to DAI
        address[] memory path = new address[](2);
        path[0] = address(wpls);
        path[1] = address(dai);

        pulseRouter.swapExactETHForTokens{value: _amount}(
            _amountOutMin,
            path,
            address(this),
            block.timestamp
        );

        return (_amount, dai.balanceOf(address(this)) - daiBefore);
    }

    function _swapTokens(
        address _curr,
        uint256 _amount,
        uint256 _amountOutMin1,
        uint256 _amountOutMin2,
        uint256 _amountOutMin3
    ) internal returns (uint256, uint256) {
        uint256 plsBefore = address(this).balance;

        if (_curr != address(dai)) {
            // Swap 100% of _curr to PLS
            address[] memory path = new address[](2);
            path[0] = address(_curr);
            path[1] = address(wpls);

            pulseRouter.swapExactTokensForETH(
                _amount,
                _amountOutMin1,
                path,
                address(this),
                block.timestamp
            );

            // Track PLS gained and DAI starting balance
            uint256 plsGained = address(this).balance - plsBefore;
            uint256 daiBefore = dai.balanceOf(address(this));

            // Swap 50% of PLS to DAI
            address[] memory path2 = new address[](2);
            path2[0] = address(wpls);
            path2[1] = address(dai);

            pulseRouter.swapExactETHForTokens{value: plsGained / 2}(
                _amountOutMin2,
                path2,
                address(this),
                block.timestamp
            );

            // Track DAI gained
            uint256 daiGained = dai.balanceOf(address(this)) - daiBefore;

            return (plsGained / 2, daiGained);
        } else {

            // Swap 50% of DAI to PLS
            address[] memory path = new address[](2);
            path[0] = address(_curr);
            path[1] = address(wpls);

            pulseRouter.swapExactTokensForETH(
                _amount / 2,
                _amountOutMin3,
                path,
                address(this),
                block.timestamp
            );

            // Track PLS gained and DAI starting balance
            uint256 plsGained = address(this).balance - plsBefore;

            return (plsGained, _amount / 2);
        }
    }

    function getExpectedAmountOut(
        uint256 amountIn,
        address tokenIn,
        address tokenOut
    ) public view returns (uint256) {
        address pairAddress = getPairAddress(tokenIn, tokenOut);

        (uint112 reserve0, uint112 reserve1, ) = IPulsePair(pairAddress)
            .getReserves();

        (uint reserveIn, uint reserveOut) = tokenIn < tokenOut
            ? (reserve0, reserve1)
            : (reserve1, reserve0);

        uint amountOut = pulseRouter.getAmountOut(
            amountIn,
            reserveIn,
            reserveOut
        );

        return amountOut;
    }

    function getPairAddress(
        address tokenA,
        address tokenB
    ) public view returns (address) {
        return IPulseFactory(pulseRouter.factory()).getPair(tokenA, tokenB);
    }

    receive() external payable {}
}
