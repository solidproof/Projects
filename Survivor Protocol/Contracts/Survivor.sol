// SPDX-License-Identifier: Unlicensed

pragma solidity 0.8.4;

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address who) external view returns (uint256);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function transfer(address to, uint256 value) external returns (bool);

    function approve(address spender, uint256 value) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

interface IPancakeSwapPair {
    function sync() external;
}

interface IPancakeSwapRouter {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );

    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);

    function swapExactTokensForETH(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external returns (uint256[] memory amounts);
}

interface IPancakeSwapFactory {
    function getPair(address tokenA, address tokenB)
        external
        view
        returns (address pair);

    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
}

contract Ownable {
    address private _owner;

    event OwnershipRenounced(address indexed previousOwner);

    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        _owner = msg.sender;
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(isOwner(), "Must be called by Owner");
        _;
    }

    function isOwner() public view returns (bool) {
        return msg.sender == _owner;
    }

    function renounceOwnership() public onlyOwner {
        emit OwnershipRenounced(_owner);
        _owner = address(0);
    }

    function transferOwnership(address newOwner) public onlyOwner {
        _transferOwnership(newOwner);
    }

    function _transferOwnership(address newOwner) internal {
        require(newOwner != address(0), "Owner can't be zero address");
        emit OwnershipTransferred(_owner, newOwner);
        _owner = newOwner;
    }
}

abstract contract ERC20Detailed is IERC20 {
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    constructor(
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;
    }

    function name() public view returns (string memory) {
        return _name;
    }

    function symbol() public view returns (string memory) {
        return _symbol;
    }

    function decimals() public view returns (uint8) {
        return _decimals;
    }
}

contract Survivor is ERC20Detailed, Ownable {
    struct Fees {
        uint256 lifeLock; // Liquidity Purchases
        uint256 lifeLine; // Buyback Fund
        uint256 treasury; // Treasury
        uint256 burialGroundAddress; // Burn Address
        uint256 rationPool; // BUSD Reflections
        uint256 jackpot; // Jackpot
    }

    Fees public buyFees = Fees(20, 40, 50, 30, 20, 0); // 16%

    bool public buyFeesEnabled = true;

    Fees public sellFeesWeekOne = Fees(60, 70, 60, 40, 70, 30); // 33%
    Fees public sellFeesWeekTwo = Fees(40, 50, 60, 30, 70, 30); // 28%
    Fees public sellFeesForever = Fees(40, 50, 60, 20, 30, 10); // 21%

    bool public sellFeesEnabled = true;

    uint256 public constant feeDenominator = 1000;

    uint256 private constant MAX_INT = 2**256 - 1;
    uint256 private constant MAX_SHARES = MAX_INT - (MAX_INT % MAX_SUPPLY);

    uint256 public constant DECIMALS = 5;
    uint256 private constant INITIAL_SUPPLY = 100000 * 10**DECIMALS;
    uint256 private constant MAX_SUPPLY = 1000000000 * 10**DECIMALS;
    uint256 public _totalSupply;

    address public routerAddress;
    IPancakeSwapRouter public router;

    address public treasuryAddress;
    uint256 private _pendingTreasury;
    address public lifeLockAddress;
    uint256 private _pendingLifeLock;
    address public lifeLineAddress;
    uint256 private _pendingLifeLine;
    address public rationPoolAddress;
    uint256 private _pendingRationPool;
    address public jackpotAddress;
    address public constant burialGroundAddress =
        0x000000000000000000000000000000000000dEaD;

    uint256 private _nextToSwap; // 0 = Treasury, 1 = RationPool, 2 = LifeLine. Only swap one during any transaction to keep gas down.
    address public pair;
    IPancakeSwapPair public pairContract;

    uint8 public constant RATE_DECIMALS = 7;
    uint256[11] public _rebasePcts = [
        2368, // tier 10
        2170,
        1972,
        1775,
        1578,
        1381,
        1185,
        981,
        803,
        622, // tier 1
        2432 // "special tier" (tribal leaders)
    ];

    bool public autoRebaseEnabled;
    uint256 public firstRebasedTime;
    uint256 public lastRebasedTime;

    bool public autoLiquidityEnabled;
    uint256 public lastLiquidityAddedTime;

    uint256[11] private _tierShares;
    uint256[11] private _tierSupply;
    uint256[11] private _sharesPerFragment;

    mapping(address => uint256) private _shareBalances;
    mapping(address => uint256) public tiers;

    mapping(address => bool) private _isFeeExempt;
    mapping(address => bool) private _mayTransfer;
    mapping(address => mapping(address => uint256)) private _allowedFragments;

    bool inSwap = false;

    // MODIFIERS
    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }

    // CUSTOM ERRORS
    error ZeroAddressUsed();

    error NotAuthorizedToTransfer(address from, address to);

    error AlreadyWhitelisted(address wallet);

    error AlreadySold(address wallet);

    error NotEmpty(address wallet);

    error InsufficientAllowance(
        address spender,
        address from,
        address to,
        uint256 value,
        uint256 allowed
    );

    // EVENTS
    event LogRebase(uint256 indexed epoch, uint256 totalSupply);

    // CONSTRUCTOR
    constructor(
        address routerAddress_,
        address treasuryAddress_,
        address lifeLockAddress_,
        address lifeLineAddress_,
        address rationPoolAddress_,
        address jackpotAddress_
    ) ERC20Detailed("Health Points", "HP", uint8(DECIMALS)) Ownable() {
        if (
            routerAddress_ == address(0) ||
            treasuryAddress_ == address(0) ||
            lifeLockAddress_ == address(0) ||
            lifeLineAddress_ == address(0) ||
            rationPoolAddress_ == address(0) ||
            jackpotAddress_ == address(0)
        ) {
            revert ZeroAddressUsed();
        }

        routerAddress = routerAddress_;
        router = IPancakeSwapRouter(routerAddress);

        treasuryAddress = treasuryAddress_;
        lifeLockAddress = lifeLockAddress_;
        lifeLineAddress = lifeLineAddress_;
        rationPoolAddress = rationPoolAddress_;
        jackpotAddress = jackpotAddress_;

        pair = IPancakeSwapFactory(router.factory()).createPair(
            router.WETH(),
            address(this)
        );
        pairContract = IPancakeSwapPair(pair);

        _allowedFragments[address(this)][routerAddress] = MAX_INT;

        _totalSupply = INITIAL_SUPPLY;
        _tierSupply[0] = INITIAL_SUPPLY;
        _tierShares[0] = MAX_SHARES;

        _sharesPerFragment[0] = MAX_SHARES / INITIAL_SUPPLY;
        _sharesPerFragment[10] = MAX_SHARES / INITIAL_SUPPLY;

        _shareBalances[treasuryAddress] = MAX_SHARES;
        emit Transfer(address(0), treasuryAddress, _totalSupply);

        lastLiquidityAddedTime = block.timestamp;
        firstRebasedTime = block.timestamp;
        lastRebasedTime = block.timestamp;
        _mayTransfer[treasuryAddress] = true;
        _mayTransfer[lifeLockAddress] = true;
        _mayTransfer[lifeLineAddress] = true;
        _mayTransfer[pair] = true;
        _mayTransfer[burialGroundAddress] = true;

        _isFeeExempt[treasuryAddress] = true;
        _isFeeExempt[address(this)] = true;

        _transferOwnership(treasuryAddress);
    }

    function _isTimeToRebase() internal view returns (bool) {
        // It is time to rebase when all of these are true:
        // - The autoRebaseEnabled flag is set to true
        // - Not in the middle of a swap
        // - We have not reached max supply
        // - The transaction is NOT a buy
        // - It has been at least 15 minutes since the last rebase
        return (autoRebaseEnabled &&
            !inSwap &&
            (_totalSupply < MAX_SUPPLY) &&
            msg.sender != pair &&
            block.timestamp >= (lastRebasedTime + 15 minutes));
    }

    function _rebase() internal {
        uint256 deltaTime = block.timestamp - lastRebasedTime;
        uint256 times = deltaTime / 15 minutes;
        uint256 epoch = times * 15;

        for (uint256 i = 0; i < times; i++) {
            for (uint256 j = 0; j < 11; j++) {
                if (_tierSupply[j] > 0) {
                    _totalSupply -= _tierSupply[j];

                    _tierSupply[j] *=
                        ((10**RATE_DECIMALS) + _rebasePcts[j]) /
                        (10**RATE_DECIMALS);

                    _totalSupply += _tierSupply[j];

                    _sharesPerFragment[j] = _tierShares[j] / _tierSupply[j];
                }
            }
        }

        lastRebasedTime += (times * 15 minutes);

        pairContract.sync();

        emit LogRebase(epoch, _totalSupply);
    }

    function _isTimeToAddLiquidity() internal view returns (bool) {
        // It is time to add liquidity when all of these are true:
        // - The autoLiquidityEnabled flag is set to true
        // - Not in the middle of a swap
        // - The transaction is NOT a buy
        // - The Life Lock fee pool has at least 0.01 HP
        // - It has been at least 2 days since the last liquidity add
        return (autoLiquidityEnabled &&
            !inSwap &&
            msg.sender != pair &&
            _pendingLifeLock > 100 &&
            block.timestamp >= (lastLiquidityAddedTime + 2 days));
    }

    function _addLiquidity() internal swapping {
        uint256 amountToLiquify = _pendingLifeLock / 2;
        uint256 amountToSwap = _pendingLifeLock - amountToLiquify;

        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        uint256 balanceBefore = address(this).balance;

        router.swapExactTokensForETH(
            amountToSwap,
            0,
            path,
            address(this),
            block.timestamp
        );

        uint256 amountETHLiquidity = address(this).balance - balanceBefore;

        router.addLiquidityETH{value: amountETHLiquidity}(
            address(this),
            amountToLiquify,
            0,
            0,
            lifeLockAddress,
            block.timestamp
        );
        lastLiquidityAddedTime = block.timestamp;
        _pendingLifeLock = 0;
    }

    function _isTimeToSwapLifeLine() internal view returns (bool) {
        return
            !inSwap &&
            msg.sender != pair &&
            _pendingLifeLine > 0 &&
            _nextToSwap == 2;
    }

    function _swapLifeLine() internal swapping {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        router.swapExactTokensForETH(
            _pendingLifeLine,
            0,
            path,
            lifeLineAddress,
            block.timestamp
        );

        _pendingLifeLine = 0;
        _nextToSwap = 0;
    }

    function _isTimeToSwapTreasury() internal view returns (bool) {
        return
            !inSwap &&
            msg.sender != pair &&
            _pendingTreasury > 0 &&
            _nextToSwap == 0;
    }

    function _swapTreasury() internal swapping {
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = router.WETH();

        router.swapExactTokensForETH(
            _pendingTreasury,
            0,
            path,
            treasuryAddress,
            block.timestamp
        );

        _pendingTreasury = 0;
        _nextToSwap++;
    }

    function _isTimeToSwapRationPool() internal view returns (bool) {
        return
            !inSwap &&
            msg.sender != pair &&
            _pendingRationPool > 0 &&
            _nextToSwap == 1;
    }

    function _swapRationPool() internal swapping {
        address[] memory path = new address[](3);
        path[0] = address(this);
        path[1] = router.WETH();
        path[2] = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56; // BUSD

        router.swapExactTokensForTokens(
            _pendingRationPool,
            0,
            path,
            rationPoolAddress,
            block.timestamp
        );

        _pendingRationPool = 0;
        _nextToSwap++;
    }

    function _takeFee(
        address from,
        address to,
        uint256 amount
    ) internal returns (uint256) {
        if (_isFeeExempt[from] || (pair != from && pair != to)) {
            return amount;
        }

        Fees memory myFees;

        if (pair == from) {
            if (!buyFeesEnabled) return amount;
            myFees = buyFees;
        }
        if (pair == to) {
            if (!sellFeesEnabled) return amount;
            uint256 timeSinceLaunch = block.timestamp - firstRebasedTime;
            if (timeSinceLaunch <= 7 days) {
                myFees = sellFeesWeekOne;
            } else if (timeSinceLaunch <= 14 days) {
                myFees = sellFeesWeekTwo;
            } else {
                myFees = sellFeesForever;
            }
        }

        uint256 totalFee;

        // Life Lock - Liquidity Purchases
        uint256 lifeLockAmount = (amount * myFees.lifeLock) / feeDenominator;
        totalFee += lifeLockAmount;
        _pendingLifeLock += lifeLockAmount;

        _tierSupply[tiers[address(this)]] += lifeLockAmount;
        _tierShares[tiers[address(this)]] +=
            lifeLockAmount *
            _sharesPerFragment[tiers[address(this)]];
        _shareBalances[address(this)] +=
            lifeLockAmount *
            _sharesPerFragment[tiers[address(this)]];

        // Life Line - Buyback Fund
        uint256 lifeLineAmount = (amount * myFees.lifeLine) / feeDenominator;

        totalFee += lifeLineAmount;
        _pendingLifeLine += lifeLineAmount;

        _tierSupply[tiers[address(this)]] += lifeLineAmount;
        _tierShares[tiers[address(this)]] +=
            lifeLineAmount *
            _sharesPerFragment[tiers[address(this)]];
        _shareBalances[address(this)] +=
            lifeLineAmount *
            _sharesPerFragment[tiers[address(this)]];

        // Treasury
        uint256 treasuryAmount = (amount * myFees.treasury) / feeDenominator;

        totalFee += treasuryAmount;
        _pendingTreasury += treasuryAmount;

        _tierSupply[tiers[address(this)]] += treasuryAmount;
        _tierShares[tiers[address(this)]] +=
            treasuryAmount *
            _sharesPerFragment[tiers[address(this)]];
        _shareBalances[address(this)] +=
            treasuryAmount *
            _sharesPerFragment[tiers[address(this)]];

        // Burial Ground - Burn Address
        uint256 burialGroundAddressAmount = (amount *
            myFees.burialGroundAddress) / feeDenominator;

        totalFee += burialGroundAddressAmount;

        _tierSupply[tiers[burialGroundAddress]] += burialGroundAddressAmount;
        _tierShares[tiers[burialGroundAddress]] +=
            burialGroundAddressAmount *
            _sharesPerFragment[tiers[burialGroundAddress]];

        _shareBalances[burialGroundAddress] +=
            burialGroundAddressAmount *
            _sharesPerFragment[tiers[burialGroundAddress]];

        // Ration Pool - BUSD Reflections
        uint256 rationPoolAmount = (amount * myFees.rationPool) /
            feeDenominator;

        totalFee += rationPoolAmount;
        _pendingRationPool += rationPoolAmount;

        _tierSupply[tiers[address(this)]] += rationPoolAmount;
        _tierShares[tiers[address(this)]] +=
            rationPoolAmount *
            _sharesPerFragment[tiers[address(this)]];
        _shareBalances[address(this)] +=
            rationPoolAmount *
            _sharesPerFragment[tiers[address(this)]];

        // Jackpot
        uint256 jackpotAmount = (amount * myFees.jackpot) / feeDenominator;

        totalFee += jackpotAmount;

        _tierSupply[tiers[jackpotAddress]] += jackpotAmount;
        _tierShares[tiers[jackpotAddress]] +=
            jackpotAmount *
            _sharesPerFragment[tiers[jackpotAddress]];

        _shareBalances[jackpotAddress] +=
            jackpotAmount *
            _sharesPerFragment[tiers[jackpotAddress]];

        return amount - totalFee;
    }

    function _basicTransfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        uint256 shareAmountFrom = amount * _sharesPerFragment[tiers[sender]];

        _tierSupply[tiers[sender]] -= amount;
        _tierShares[tiers[sender]] -= shareAmountFrom;
        _shareBalances[sender] -= shareAmountFrom;

        uint256 shareAmountTo = amount * _sharesPerFragment[tiers[recipient]];

        _tierSupply[tiers[recipient]] += amount;
        _tierShares[tiers[recipient]] += shareAmountTo;
        _shareBalances[recipient] += shareAmountTo;
    }

    function _dropTier(address paperhand) internal {
        // Executing this code? NGMI
        uint256 balanceToMove = balanceOf(paperhand);

        if (tiers[paperhand] < 9 || tiers[paperhand] == 10) {
            // Reduce the balance of the old tier
            _tierSupply[tiers[paperhand]] -= balanceToMove;
            _tierShares[tiers[paperhand]] -= _shareBalances[paperhand];

            // Tribal leaders have a value of 10. When they sell they go to 1 (which is called Tier 9 in the game)
            if (tiers[paperhand] == 10) {
                tiers[paperhand] = 1;
            } else {
                tiers[paperhand] += 1;
            }

            // Initialize the tier if it hasn't been used yet
            if (_sharesPerFragment[tiers[paperhand]] == 0) {
                _sharesPerFragment[tiers[paperhand]] = MAX_SHARES / MAX_SUPPLY;
            }

            // Increase balance of the new tier
            _tierSupply[tiers[paperhand]] += balanceToMove;
            _shareBalances[paperhand] =
                balanceToMove *
                _sharesPerFragment[tiers[paperhand]];
            _tierShares[tiers[paperhand]] += _shareBalances[paperhand];
        }
    }

    function _transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) internal returns (bool) {
        if (inSwap) {
            _basicTransfer(sender, recipient, amount);
            return (true);
        }

        // Handle the case where a user is transferring ALL tokens to a new (empty, tier 10) wallet
        if (
            tiers[recipient] == 0 &&
            balanceOf(sender) == amount &&
            balanceOf(recipient) == 0
        ) {
            tiers[recipient] = tiers[sender];
            _shareBalances[recipient] = _shareBalances[sender];
            _shareBalances[sender] = 0;
            return true;
        }

        if (
            recipient == address(0) ||
            (!_mayTransfer[sender] && !_mayTransfer[recipient])
        ) revert NotAuthorizedToTransfer(sender, recipient);

        if (_isTimeToRebase()) _rebase();

        if (_isTimeToAddLiquidity()) _addLiquidity();

        bool _swapped;

        if (_isTimeToSwapTreasury()) {
            _swapTreasury();
            _swapped = true;
        }

        if (_isTimeToSwapRationPool() && !_swapped) {
            _swapRationPool();
            _swapped = true;
        }

        if (_isTimeToSwapLifeLine() && !_swapped) _swapLifeLine();

        uint256 shareAmountFrom = amount * _sharesPerFragment[tiers[sender]];

        _tierSupply[tiers[sender]] -= amount;
        _tierShares[tiers[sender]] -= shareAmountFrom;
        _shareBalances[sender] -= shareAmountFrom;

        if (recipient == pair) _dropTier(sender);

        uint256 amountReceived = _takeFee(sender, recipient, amount);

        uint256 shareAmountTo = amountReceived *
            _sharesPerFragment[tiers[recipient]];

        _tierSupply[tiers[recipient]] += amountReceived;
        _tierShares[tiers[recipient]] += shareAmountTo;
        _shareBalances[recipient] += shareAmountTo;

        emit Transfer(sender, recipient, amountReceived);
        return true;
    }

    function getCirculatingSupply() public view returns (uint256) {
        return _totalSupply - balanceOf(burialGroundAddress);
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address who) public view override returns (uint256) {
        return _shareBalances[who] / _sharesPerFragment[tiers[who]];
    }

    function increaseAllowance(address spender, uint256 addedValue)
        external
        returns (bool)
    {
        _allowedFragments[msg.sender][spender] += addedValue;
        emit Approval(
            msg.sender,
            spender,
            _allowedFragments[msg.sender][spender]
        );
        return true;
    }

    function approve(address spender, uint256 value)
        external
        override
        returns (bool)
    {
        _allowedFragments[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    function allowance(address owner_, address spender)
        external
        view
        override
        returns (uint256)
    {
        return _allowedFragments[owner_][spender];
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        external
        returns (bool)
    {
        uint256 oldValue = _allowedFragments[msg.sender][spender];
        if (subtractedValue >= oldValue) {
            _allowedFragments[msg.sender][spender] = 0;
        } else {
            _allowedFragments[msg.sender][spender] -= subtractedValue;
        }
        emit Approval(
            msg.sender,
            spender,
            _allowedFragments[msg.sender][spender]
        );
        return true;
    }

    function transfer(address to, uint256 value)
        external
        override
        returns (bool)
    {
        return _transferFrom(msg.sender, to, value);
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) external override returns (bool) {
        if (_allowedFragments[from][msg.sender] != MAX_INT) {
            if (_allowedFragments[from][msg.sender] < value) {
                revert InsufficientAllowance(
                    msg.sender,
                    from,
                    to,
                    value,
                    _allowedFragments[from][msg.sender]
                );
            }
            unchecked {
                _allowedFragments[from][msg.sender] -= value;
            }
        }
        _transferFrom(from, to, value);
        return true;
    }

    function whitelist(address wallet) external onlyOwner {
        if (tiers[wallet] == 10) revert AlreadyWhitelisted(wallet);
        if (tiers[wallet] != 0) revert AlreadySold(wallet);
        if (balanceOf(wallet) != 0) revert NotEmpty(wallet);

        tiers[wallet] = 10;
    }

    function setFeeReceivers(
        address treasuryAddress_,
        address lifeLockAddress_,
        address lifeLineAddress_,
        address rationPoolAddress_,
        address jackpotAddress_
    ) external onlyOwner {
        if (
            treasuryAddress_ == address(0) ||
            lifeLockAddress_ == address(0) ||
            lifeLineAddress_ == address(0) ||
            rationPoolAddress_ == address(0) ||
            jackpotAddress_ == address(0)
        ) {
            revert ZeroAddressUsed();
        }

        treasuryAddress = treasuryAddress_;
        lifeLockAddress = lifeLockAddress_;
        lifeLineAddress = lifeLineAddress_;
        rationPoolAddress = rationPoolAddress_;
        jackpotAddress = jackpotAddress_;
    }

    function toggleRebase() external onlyOwner {
        autoRebaseEnabled = !autoRebaseEnabled;
    }

    function toggleLiquidity() external onlyOwner {
        autoLiquidityEnabled = !autoLiquidityEnabled;
    }

    function toggleBuyFees() external onlyOwner {
        buyFeesEnabled = !buyFeesEnabled;
    }

    function toggleSellFees() external onlyOwner {
        sellFeesEnabled = !sellFeesEnabled;
    }

    function toggleTransfers(address wallet) external onlyOwner {
        _mayTransfer[wallet] = !_mayTransfer[wallet];
    }

    receive() external payable {}
}