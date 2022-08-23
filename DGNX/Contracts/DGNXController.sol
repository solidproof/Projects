// SPDX-License-Identifier: MIT
pragma solidity >=0.8.4;

import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';
import '@uniswap/lib/contracts/libraries/TransferHelper.sol';

import '@openzeppelin/contracts/access/Ownable.sol';
import '@openzeppelin/contracts/token/ERC20/ERC20.sol';
import '@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol';
import '@openzeppelin/contracts/utils/math/SafeMath.sol';
import '@openzeppelin/contracts/security/ReentrancyGuard.sol';
import '@openzeppelin/contracts/utils/Address.sol';

import './DGNXLibrary.sol';

contract DGNXController is ReentrancyGuard, Ownable {
    using SafeERC20 for ERC20;
    using Address for address;
    using SafeMath for uint256;

    bool public inFee = false;
    bool public applyFee = true;

    // track busd
    uint256 public liquidityBUSD;

    // taxation
    uint256 public burnTax = 100;
    uint256 public backingTax = 200;
    uint256 public liquidityTax = 300;
    uint256 public marketingTax = 100;
    uint256 public platformTax = 200;
    uint256 public investmentFundTax = 200;

    // collect tokens for purpose
    uint256 public burnAmount;
    uint256 public backingAmount;
    uint256 public liquidityAmount;
    uint256 public marketingAmount;
    uint256 public platformAmount;
    uint256 public investmentFundAmount;

    // define thresholds for transfers
    uint256 public backingThreshold = 1000 * 10**18;
    uint256 public liquidityThreshold = 5 * 10**18;
    uint256 public platformThreshold = 1000 * 10**18;
    uint256 public investmentFundThreshold = 1000 * 10**18;

    // Some basic stuff we need
    address public constant DEV = 0xdF090f6675034Fde637031c6590FD1bBeBc4fa45;
    address public constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address public constant MARKETING =
        0x16eF18E42A7d72E52E9B213D7eABA269B90A4643;
    address public constant BACKING =
        0x31CE1540414361cFf99e83a05e4ad6d35D425202;
    address public constant PLATFORM =
        0xcA01A9d36F47561F03226B6b697B14B9274b1B10;
    address public constant INVESTMENT_FUND =
        0x829619513F202e1bFD8929f656EF96bac73BDAe8;

    // needs to be set
    address public previousController;
    address public dgnx;
    address public busd;
    address public mainPair;

    // track all pairs
    address[] private allPairs;

    mapping(address => bool) private pairs;
    mapping(address => address[]) private pairsPath;
    mapping(address => bool) private factories;
    mapping(address => bool) private allowedContracts;

    event PairAdded(address pair, address[] pathToBUSD, address sender);
    event PairRemoved(address pair, address sender);
    event FactoryAdded(address factory, address sender);
    event FactoryRemoved(address factory, address sender);

    event DistributeLiquidity(
        address token0,
        uint256 amount0,
        address token1,
        uint256 amount1,
        address sender
    );

    uint256 constant MAX_INT = 2**256 - 1;

    constructor(address _dgnx, address _busd) {
        require(_dgnx != address(0), 'wrong token');
        require(_busd != address(0), 'wrong token');
        require(_dgnx != _busd, 'wrong token');
        dgnx = _dgnx;
        busd = _busd;
        allowedContracts[_dgnx] = true;
    }

    modifier onlyAllowed() {
        _onlyAllowed();
        _;
    }

    function _onlyAllowed() private view {
        require(
            allowedContracts[msg.sender] || msg.sender == owner(),
            'not allowed'
        );
    }

    function transferFees(
        address from,
        address to,
        uint256 amount
    ) external virtual onlyAllowed returns (uint256 newAmount) {
        require(amount > 0, 'no amount set');

        bool isSell = isPair(to);
        bool isBuy = isPair(from);

        if (
            isAllowed(from) ||
            isAllowed(to) ||
            (!isSell && !isBuy) ||
            !applyFee ||
            inFee
        ) return amount;

        address pair = isSell ? to : from;

        newAmount = amount;
        (
            ,
            uint256 _liquidityAmount,
            uint256 _backingAmount,
            uint256 _burnAmount,
            uint256 _marketingAmount,
            uint256 _platformAmount,
            uint256 _investmentFundAmount
        ) = estimateTransferFees(from, to, amount);

        if (isSell) {
            backingAmount += _backingAmount;
            liquidityAmount += _liquidityAmount;
            burnAmount += _burnAmount;
            platformAmount += _platformAmount;
            investmentFundAmount += _investmentFundAmount;
            newAmount -= (_backingAmount +
                _liquidityAmount +
                _burnAmount +
                _platformAmount +
                _investmentFundAmount);
        } else if (isBuy) {
            backingAmount += _backingAmount;
            liquidityAmount += _liquidityAmount;
            marketingAmount += _marketingAmount;
            platformAmount += _platformAmount;
            investmentFundAmount += _investmentFundAmount;
            newAmount -= (_backingAmount +
                _liquidityAmount +
                _marketingAmount +
                _platformAmount +
                _investmentFundAmount);
        }

        // flag that you are in fee
        inFee = true;

        // turn fees off
        applyFee = false;

        if (burnAmount > 0) {
            uint256 _amount = burnAmount;
            burnAmount = 0;
            require(ERC20(dgnx).transfer(DEAD, _amount), 'tx failed');
        }

        if (marketingAmount > 0) {
            uint256 _amount = marketingAmount;
            marketingAmount = 0;
            require(ERC20(dgnx).transfer(MARKETING, _amount), 'tx failed');
        }

        if (platformAmount >= platformThreshold) {
            uint256 _amount = platformAmount;
            uint256 __devAmount = (_amount * 40) / 100; // 40%
            uint256 __platformAmount = _amount - __devAmount; // 60%
            platformAmount = 0;
            require(ERC20(dgnx).transfer(DEV, __devAmount), 'tx failed');
            require(
                ERC20(dgnx).transfer(PLATFORM, __platformAmount),
                'tx failed'
            );
        }

        if (investmentFundAmount >= investmentFundThreshold) {
            uint256 _amount = investmentFundAmount;
            investmentFundAmount = 0;
            require(
                ERC20(dgnx).transfer(INVESTMENT_FUND, _amount),
                'tx failed'
            );
        }

        // just when there is more than 1 pair
        if (allPairs.length > 1) {
            uint256 dgnxBefore;
            uint256 liquifyAmount;
            address swapPair;
            uint256 busdBefore;
            (liquifyAmount, swapPair) = bestBUSDValue(liquidityAmount, pair);
            if (liquifyAmount >= liquidityThreshold) {
                dgnxBefore = ERC20(dgnx).balanceOf(address(this));
                busdBefore = ERC20(busd).balanceOf(address(this));
                swapTokensToBUSD(
                    liquidityAmount,
                    IUniswapV2Pair(swapPair),
                    address(this)
                );
                liquidityBUSD +=
                    ERC20(busd).balanceOf(address(this)) -
                    busdBefore;
                liquidityAmount -=
                    dgnxBefore -
                    ERC20(dgnx).balanceOf(address(this));
                dgnxBefore = 0;
                busdBefore = 0;
            }

            // if main pair is not traded, lets kick some ballz here
            if (mainPair != pair && liquidityBUSD >= liquidityThreshold)
                distributeLiquidityToMainPool();

            if (backingAmount > 0) {
                (liquifyAmount, swapPair) = bestBUSDValue(backingAmount, pair);
                if (liquifyAmount > backingThreshold) {
                    dgnxBefore = ERC20(dgnx).balanceOf(address(this));
                    swapTokensToBUSD(
                        backingAmount,
                        IUniswapV2Pair(swapPair),
                        BACKING // currently we are storing it on a wallet until we have a fancy contract for it to handle
                    );
                    backingAmount -=
                        dgnxBefore -
                        ERC20(dgnx).balanceOf(address(this));
                    dgnxBefore = 0;
                }
            }
        }

        // turn fees on again
        applyFee = true;
        inFee = false;
    }

    function estimateTransferFees(
        address from,
        address to,
        uint256 amount
    )
        public
        view
        returns (
            uint256 newAmount,
            uint256 _liquidityAmount,
            uint256 _backingAmount,
            uint256 _burnAmount,
            uint256 _marketingAmount,
            uint256 _platformAmount,
            uint256 _investmentFundAmount
        )
    {
        require(amount > 0, 'no amount set');

        bool isSell = isPair(to);
        bool isBuy = isPair(from);

        if (
            isAllowed(from) ||
            isAllowed(to) ||
            (!isSell && !isBuy) ||
            !applyFee ||
            inFee
        ) return (amount, 0, 0, 0, 0, 0, 0);

        newAmount = amount;
        _liquidityAmount = (amount * liquidityTax) / 10000;
        _backingAmount = (amount * backingTax) / 10000;
        _burnAmount = (amount * burnTax) / 10000;
        _marketingAmount = (amount * marketingTax) / 10000;
        _platformAmount = (amount * platformTax) / 10000;
        _investmentFundAmount = (amount * investmentFundTax) / 10000;

        if (isSell)
            newAmount -= (_backingAmount +
                _liquidityAmount +
                _burnAmount +
                _platformAmount +
                _investmentFundAmount);
        else if (isBuy)
            newAmount -= (_backingAmount +
                _liquidityAmount +
                _marketingAmount +
                _platformAmount +
                _investmentFundAmount);
    }

    function distributeLiquidityToMainPool() public onlyAllowed nonReentrant {
        uint256 busdBefore = ERC20(busd).balanceOf(address(this));
        uint256 forSwap = liquidityBUSD / 2;
        uint256 forLiquidity = liquidityBUSD - forSwap;
        uint256[] memory amounts = swapBUSDToToken(
            forSwap,
            IUniswapV2Pair(mainPair),
            address(this)
        );
        addLiquidity(
            IUniswapV2Pair(mainPair).factory(),
            IUniswapV2Pair(mainPair).token0(),
            IUniswapV2Pair(mainPair).token1(),
            amounts[1],
            forLiquidity,
            address(this)
        );

        liquidityBUSD -= busdBefore - ERC20(busd).balanceOf(address(this));
        emit DistributeLiquidity(
            IUniswapV2Pair(mainPair).token0(),
            amounts[1],
            IUniswapV2Pair(mainPair).token1(),
            forLiquidity,
            msg.sender
        );
    }

    function swapTokensToBUSD(
        uint256 amountIn,
        IUniswapV2Pair pair,
        address to
    ) internal returns (uint256[] memory amounts) {
        address[] memory path = getPathForPair(address(pair), dgnx);
        amounts = getAmountsOut(pair.factory(), amountIn, path);
        TransferHelper.safeTransfer(path[0], address(pair), amounts[0]);
        _swap(pair.factory(), amounts, path, to);
    }

    function swapBUSDToToken(
        uint256 amountIn,
        IUniswapV2Pair pair,
        address to
    ) internal returns (uint256[] memory amounts) {
        address[] memory path = getPathForPair(address(pair), busd);
        amounts = getAmountsOut(pair.factory(), amountIn, path);
        TransferHelper.safeTransfer(path[0], address(pair), amounts[0]);
        _swap(pair.factory(), amounts, path, to);
    }

    function _swap(
        address factory,
        uint256[] memory amounts,
        address[] memory path,
        address _to
    ) internal {
        for (uint256 i; i < path.length - 1; i++) {
            (address input, address output) = (path[i], path[i + 1]);
            (address token0, ) = DGNXLibrary.sortTokens(input, output);
            uint256 amountOut = amounts[i + 1];
            (uint256 amount0Out, uint256 amount1Out) = input == token0
                ? (uint256(0), amountOut)
                : (amountOut, uint256(0));
            address to = i < path.length - 2
                ? IUniswapV2Factory(factory).getPair(output, path[i + 2])
                : _to;
            IUniswapV2Pair(IUniswapV2Factory(factory).getPair(input, output))
                .swap(amount0Out, amount1Out, to, new bytes(0));
        }
    }

    function addLiquidity(
        address factory,
        address tokenA,
        address tokenB,
        uint256 amountADesired,
        uint256 amountBDesired,
        address to
    )
        internal
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        )
    {
        (uint256 reserveA, uint256 reserveB) = DGNXLibrary.getReserves(
            factory,
            tokenA,
            tokenB
        );
        if (reserveA == 0 && reserveB == 0) {
            (amountA, amountB) = (amountADesired, amountBDesired);
        } else {
            uint256 amountBOptimal = DGNXLibrary.quote(
                amountADesired,
                reserveA,
                reserveB
            );
            if (amountBOptimal <= amountBDesired) {
                (amountA, amountB) = (amountADesired, amountBOptimal);
            } else {
                uint256 amountAOptimal = DGNXLibrary.quote(
                    amountBDesired,
                    reserveB,
                    reserveA
                );
                assert(amountAOptimal <= amountADesired);
                (amountA, amountB) = (amountAOptimal, amountBDesired);
            }
        }
        address pair = IUniswapV2Factory(factory).getPair(tokenA, tokenB);
        TransferHelper.safeTransfer(tokenA, pair, amountA);
        TransferHelper.safeTransfer(tokenB, pair, amountB);
        liquidity = IUniswapV2Pair(pair).mint(to);
    }

    function bestBUSDValue(uint256 tokenAmount, address ignorePair)
        internal
        view
        returns (uint256 value, address usePair)
    {
        if (allPairs.length > 0 && tokenAmount > 0) {
            uint256 currentValue;
            for (uint256 i; i < allPairs.length; i++) {
                address pair = allPairs[i];
                if (ignorePair != pair) {
                    address[] memory path = getPathForPair(pair, dgnx);
                    uint256[] memory amounts = getAmountsOut(
                        IUniswapV2Pair(pair).factory(),
                        tokenAmount,
                        path
                    );
                    currentValue = amounts[amounts.length - 1];
                    if (currentValue > value) {
                        value = currentValue;
                        usePair = pair;
                    }
                }
            }
        }
    }

    /**
     * Add example:
     *   addr => TOKEN/WBTC
     *   pathToBUSD => WBTC => WBNB => busd
     */
    function addPair(address addr, address[] memory pathToBUSD)
        external
        onlyAllowed
    {
        require(addr != address(0), 'no pair');
        require(IUniswapV2Pair(addr).factory() != address(0), 'no factory');
        require(factories[IUniswapV2Pair(addr).factory()], 'wrong factory');
        require(!pairs[addr], 'pair already exists');
        address t0 = IUniswapV2Pair(addr).token0();
        address t1 = IUniswapV2Pair(addr).token1();
        require(t0 == dgnx || t1 == dgnx, 'no dgnx');
        (t0, t1) = t0 == dgnx ? (t0, t1) : (t1, t0);
        if (pathToBUSD.length == 1) revert('swap path needs 2 addresses');
        if (pathToBUSD.length > 1) {
            require(pathToBUSD[0] == t1, 'wrong paired token path');
            require(
                pathToBUSD[pathToBUSD.length - 1] == busd,
                'wrong busd path'
            );
            for (uint256 i; i < pathToBUSD.length - 1; i++) {
                require(
                    IUniswapV2Factory(IUniswapV2Pair(addr).factory()).getPair(
                        pathToBUSD[i],
                        pathToBUSD[i + 1]
                    ) != address(0),
                    'invalid pair'
                );
            }
            pairsPath[addr] = pathToBUSD;
        } else {
            require(t0 == busd || t1 == busd, 'no busd token');
        }

        pairs[addr] = true;
        allPairs.push(addr);

        emit PairAdded(addr, pathToBUSD, msg.sender);
    }

    function removePair(address addr) external onlyOwner {
        require(pairs[addr], 'no pair');
        pairs[addr] = false;
        emit PairRemoved(addr, msg.sender);
    }

    function isPair(address addr) private view returns (bool) {
        return pairs[addr];
    }

    function addFactory(address addr) external onlyOwner {
        require(addr != address(0), 'wrong address');
        require(!factories[addr], 'already existing');
        factories[addr] = true;
        emit FactoryAdded(addr, msg.sender);
    }

    function removeFactory(address addr) external onlyOwner {
        require(factories[addr], 'not existing');
        factories[addr] = false;
        emit FactoryRemoved(addr, msg.sender);
    }

    function getAmountsOut(
        address factory,
        uint256 amountIn,
        address[] memory path
    ) public view returns (uint256[] memory amounts) {
        return DGNXLibrary.getAmountsOut(factory, amountIn, path);
    }

    function getPathForPair(address addr, address from)
        internal
        view
        returns (address[] memory path)
    {
        (address t0, address t1) = IUniswapV2Pair(addr).token0() == from
            ? (IUniswapV2Pair(addr).token0(), IUniswapV2Pair(addr).token1())
            : (IUniswapV2Pair(addr).token1(), IUniswapV2Pair(addr).token0());

        if (pairsPath[addr].length == 0) {
            path = new address[](2);
            (path[0], path[1]) = (t0, t1);
        } else {
            path = new address[](pairsPath[addr].length + 1);
            path[0] = t0;
            for (uint256 j; j < pairsPath[addr].length; j++) {
                path[j + 1] = pairsPath[addr][j];
            }
        }
    }

    function feeOff() external onlyAllowed {
        applyFee = false;
    }

    function feeOn() external onlyAllowed {
        applyFee = true;
    }

    // if we update controller, we need to transfer funds to new controller. This will be called by new controller
    function migrate() external onlyAllowed nonReentrant {
        uint256 lpTokens;
        uint256 balanceDgnx = ERC20(dgnx).balanceOf(address(this));
        uint256 balanceBusd = ERC20(busd).balanceOf(address(this));
        if (balanceDgnx > 0) {
            require(ERC20(dgnx).transfer(msg.sender, balanceDgnx), 'tx failed');
        }
        if (balanceBusd > 0) {
            require(ERC20(busd).transfer(msg.sender, balanceBusd), 'tx failed');
        }
        for (uint256 i; i < allPairs.length; i++) {
            lpTokens = ERC20(allPairs[i]).balanceOf(address(this));
            if (lpTokens > 0) {
                require(
                    ERC20(allPairs[i]).transfer(msg.sender, lpTokens),
                    'tx failed'
                );
            }
            if (
                ERC20(IUniswapV2Pair(allPairs[i]).token0()).balanceOf(
                    address(this)
                ) > 0
            ) {
                require(
                    ERC20(IUniswapV2Pair(allPairs[i]).token0()).transfer(
                        msg.sender,
                        ERC20(IUniswapV2Pair(allPairs[i]).token0()).balanceOf(
                            address(this)
                        )
                    ),
                    'tx failed'
                );
            }
            if (
                ERC20(IUniswapV2Pair(allPairs[i]).token1()).balanceOf(
                    address(this)
                ) > 0
            ) {
                require(
                    ERC20(IUniswapV2Pair(allPairs[i]).token1()).transfer(
                        msg.sender,
                        ERC20(IUniswapV2Pair(allPairs[i]).token1()).balanceOf(
                            address(this)
                        )
                    ),
                    'tx failed'
                );
            }
        }
    }

    // this is called by the token to initiate the migration from the new controller
    function migration(address _previousController)
        external
        onlyAllowed
        nonReentrant
    {
        require(
            _previousController != address(this) &&
                _previousController != address(0),
            '!migration'
        );
        previousController = _previousController;
        DGNXController(previousController).migrate();
    }

    // if there are any tokens send by accident, we can revover it
    function recoverToken(address token, address to)
        external
        onlyAllowed
        nonReentrant
    {
        require(dgnx != token, 'No drain allowed');
        require(busd != token, 'No drain allowed');
        for (uint256 i; i < allPairs.length; i++) {
            require(allPairs[i] != token, 'No drain allowed');
        }
        require(
            ERC20(token).transfer(to, ERC20(token).balanceOf(address(this))),
            'tx failed'
        );
    }

    function allowContract(address addr) external onlyAllowed nonReentrant {
        require(addr.isContract(), 'no contract');
        allowedContracts[addr] = true;
    }

    function removeContract(address addr) external onlyAllowed {
        require(allowedContracts[addr], 'no contract');
        delete allowedContracts[addr];
    }

    function isAllowed(address addr) public view returns (bool) {
        return allowedContracts[addr];
    }

    function setMainPair(address pair) external onlyOwner {
        require(pair != address(0), 'zero address');
        require(pair != mainPair, 'pair already set');
        mainPair = pair;
    }

    function getAllPairs() external view returns (address[] memory addr) {
        addr = allPairs;
    }

    function setBurnTax(uint256 _tax) external onlyOwner {
        burnTax = _tax;
    }

    function setBackingTax(uint256 _tax) external onlyOwner {
        backingTax = _tax;
    }

    function setLiquidityTax(uint256 _tax) external onlyOwner {
        liquidityTax = _tax;
    }

    function setMarketingTax(uint256 _tax) external onlyOwner {
        marketingTax = _tax;
    }

    function setPlatformTax(uint256 _tax) external onlyOwner {
        platformTax = _tax;
    }

    function setInvestmentFundTax(uint256 _tax) external onlyOwner {
        investmentFundTax = _tax;
    }

    function setLiquidityThreshold(uint256 _threshold) external onlyOwner {
        require(_threshold >= 1000 * 10**18, 'bad threshold');
        liquidityThreshold = _threshold;
    }

    function setBackingThreshold(uint256 _threshold) external onlyOwner {
        require(_threshold >= 10 * 10**18, 'bad threshold');
        backingThreshold = _threshold;
    }

    function setPlatformThreshold(uint256 _threshold) external onlyOwner {
        require(_threshold >= 10 * 10**18, 'bad threshold');
        platformThreshold = _threshold;
    }

    function setInvestmentFundThreshold(uint256 _threshold) external onlyOwner {
        require(_threshold >= 10 * 10**18, 'bad threshold');
        investmentFundThreshold = _threshold;
    }
}
