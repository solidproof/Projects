// SPDX-License-Identifier: MIT

pragma solidity 0.8.9;
import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "./interfaces/IPancakeRouter02.sol";
import "./interfaces/IPancakeFactory.sol";
import "./interfaces/IPancakePair.sol";
import "./interfaces/IAvionCollection.sol";

contract AvionToken is ERC20Upgradeable, OwnableUpgradeable, ReentrancyGuardUpgradeable  {
    using SafeMathUpgradeable for uint256;

    bool public initialDistributionFinished;
    bool public swapEnabled;
    bool public autoRebase;

    uint256[] public rewardYields;
    uint256 public rewardYieldDenominator;

    uint256 public rebaseFrequency;
    uint256 public nextRebase;

    mapping(address => bool) _isFeeExempt;
    address[] public _markerPairs;
    mapping(address => bool) public automatedMarketMakerPairs;

    uint256 private constant MAX_UINT256 = ~uint256(0);
    uint256 private constant INITIAL_FRAGMENTS_SUPPLY =
        400000 * 10**18;
    uint256 private constant MAX_SUPPLY = ~uint128(0);

    uint256 private constant TOTAL_GONS =
        MAX_UINT256 - (MAX_UINT256 % INITIAL_FRAGMENTS_SUPPLY);

    address constant DEAD = 0x000000000000000000000000000000000000dEaD;
    address constant ZERO = 0x0000000000000000000000000000000000000000;

    address public liquidityReceiver;
    address public treasuryReceiver;
    address public teamReceiver;
    address public burnReceiver;
    
    address public busdToken;
    address public avionNFT;

    IPancakeRouter02 public router;
    address public pair;

    uint256[] public buyFees;
    uint256[] public sellFees;

    uint256 public totalBuyFee;
    uint256 public totalSellFee;
    uint256 public totalTransferFee;
    
    uint256 public feeDenominator; 

    uint256 public percentageForLessThanSevenDays;
    uint256 public percentageForMoreThanSevenDays;

    bool inSwap;

    modifier swapping() {
        require (inSwap == false, "ReentrancyGuard: reentrant call");
        inSwap = true;
        _;
        inSwap = false;
    }

    modifier validRecipient(address to) {
        require(to != address(0x0), "Recipient zero address");
        _;
    }

    uint256 private _totalSupply;
    uint256[] private _yields;
    uint256[] private supplys;
    uint256 private gonSwapThreshold;

    struct userSale {
        uint256 amountAvailable;
        uint256 lastTimeSold;
    }

    mapping(address => userSale) public usersInfo;

    mapping(address => uint256) private _gonBalances;
    mapping(address => uint256) public _depositBalances;
    mapping(address => mapping(address => uint256)) private _allowedFragments;
    mapping(address => bool) public isMigrate;

    function initialize(address busdAddress, address _router, address _avionNFT) public initializer {

        __ERC20_init("Avion Finance", "AVION");
        __ReentrancyGuard_init();
        __Ownable_init();

        rewardYieldDenominator = 10000000000;

        /* For testing without pair */
        if (_router != address(0x0)) {
            busdToken = busdAddress;

            router = IPancakeRouter02(_router);
            address factory = router.factory();
            pair = IPancakeFactory(factory).createPair(
                address(this),
                busdToken
            );
            
            _allowedFragments[address(this)][pair] = type(uint256).max;
            _allowedFragments[address(this)][address(router)] = type(uint256).max;

            setAutomatedMarketMakerPair(pair, true);

            IERC20(busdToken).approve(address(router), type(uint256).max);
        }
        
        avionNFT = _avionNFT;

        _allowedFragments[address(this)][address(this)] = type(uint256).max;

        _totalSupply = INITIAL_FRAGMENTS_SUPPLY;
        _gonBalances[msg.sender] = TOTAL_GONS;

        _yields = [TOTAL_GONS.div(_totalSupply), TOTAL_GONS.div(_totalSupply), TOTAL_GONS.div(_totalSupply), TOTAL_GONS.div(_totalSupply)];

        gonSwapThreshold = (1500 * (10 ** 18)) * rewardYieldDenominator;

        _isFeeExempt[treasuryReceiver] = true;
        _isFeeExempt[teamReceiver] = true;
        _isFeeExempt[address(this)] = true;
        _isFeeExempt[msg.sender] = true;

        emit Transfer(address(0x0), msg.sender, _totalSupply);

        swapEnabled = true;

        rewardYields = [2256250, 3980833, 4375000, 4788333];

        supplys = [_totalSupply, _totalSupply, _totalSupply, _totalSupply];
        

        rebaseFrequency = 1800;
        nextRebase = block.timestamp + 31536000;

        liquidityReceiver = 0xd16455d232541976fa0CAe45beBeD2EBc0E22a36;
        treasuryReceiver = 0xd16455d232541976fa0CAe45beBeD2EBc0E22a36;
        teamReceiver = 0xef85dD99AfDC6b8c2878F1ea50d57F1Ad75fC9bB;
        burnReceiver = 0xd4b83a1fbb5A9B5925A77fEbb78D6e7b99975815;

        feeDenominator = 100;

        percentageForLessThanSevenDays = 50;
        percentageForMoreThanSevenDays = 100;
    }






    /* Blacklist */

    mapping(address => bool) public blacklist;

    function setBlacklist(address user, bool isBlacklist) external onlyOwner {
        blacklist[user] = isBlacklist;
    }

    modifier noBlacklist(address user) {
        require(blacklist[user] == false, "You're blacklist");
        _;
    }






    /* Basic token function */
    
    function allowance(address owner_, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowedFragments[owner_][spender];
    }

    function balanceOf(address who) public view override returns (uint256) {
        return _gonBalances[who].div(getYield(who));
    }

    function transfer(address to, uint256 value)
        public
        override
        returns (bool)
    {
        _transferFrom(msg.sender, to, value);
        return true;
    }

    function _basicTransfer(
        address from,
        address to,
        uint256 amount
    ) internal returns (bool) {
        uint256 gonAmountFrom = amount.mul(getYield(from));
        uint256 gonAmountTo = amount.mul(getYield(to));
        _gonBalances[from] = _gonBalances[from].sub(gonAmountFrom);
        _gonBalances[to] = _gonBalances[to].add(gonAmountTo);
        
        emit Transfer(from, to, amount);

        return true;
    }

    function _transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) internal noBlacklist(sender) noBlacklist(recipient) returns (bool) {
        bool excludedAccount = _isFeeExempt[sender] || _isFeeExempt[recipient];

        require(
            initialDistributionFinished || excludedAccount,
            "Trading not started"
        );

        if (inSwap) {
            return _basicTransfer(sender, recipient, amount);
        } 

        uint256 gonAmountFrom = amount.mul(getYield(sender));
        uint256 gonAmountTo = amount.mul(getYield(recipient));

        if (shouldSwapBack()) {
            swapBack();
        }

        _gonBalances[sender] = _gonBalances[sender].sub(gonAmountFrom);

        uint256 gonAmountReceived = shouldTakeFee(sender, recipient)
            ? takeFee(sender, recipient, gonAmountTo, getYield(recipient))
            : gonAmountTo;
            
        _gonBalances[recipient] = _gonBalances[recipient].add(
            gonAmountReceived
        ); 

        if (usersInfo[recipient].lastTimeSold == 0) usersInfo[recipient].lastTimeSold = block.timestamp;

        emit Transfer(
            sender,
            recipient,
            gonAmountReceived.div(getYield(recipient))
        );

        if (shouldRebase() && autoRebase) {
            _rebase();
        }

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public override validRecipient(to) returns (bool) {
        if (_allowedFragments[from][msg.sender] != type(uint256).max) {
            _allowedFragments[from][msg.sender] = _allowedFragments[from][
                msg.sender
            ].sub(value, "Insufficient Allowance");
        }

        _transferFrom(from, to, value);
        return true;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }
    
    function getCirculatingSupply() public view returns (uint256) {
        return
            (_totalSupply.sub(_gonBalances[DEAD]).sub(_gonBalances[ZERO])).mul(
                _yields[0]
            );
    }
    
    function mint(uint256 amount) external onlyOwner {
        _gonBalances[msg.sender] += amount.mul(getYield(msg.sender));
    }
    
    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        override
        returns (bool)
    {
        uint256 oldValue = _allowedFragments[msg.sender][spender];
        if (subtractedValue >= oldValue) {
            _allowedFragments[msg.sender][spender] = 0;
        } else {
            _allowedFragments[msg.sender][spender] = oldValue.sub(
                subtractedValue
            );
        }
        emit Approval(
            msg.sender,
            spender,
            _allowedFragments[msg.sender][spender]
        );
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        override
        returns (bool)
    {
        _allowedFragments[msg.sender][spender] = _allowedFragments[msg.sender][
            spender
        ].add(addedValue);
        emit Approval(
            msg.sender,
            spender,
            _allowedFragments[msg.sender][spender]
        );
        return true;
    }

    function approve(address spender, uint256 value)
        public
        override
        returns (bool)
    {
        _allowedFragments[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }




    /* Rebase function */

    

    function setNextRebase(uint256 _nextRebase) external onlyOwner {
        nextRebase = _nextRebase;
        emit SetNextRebase(_nextRebase);
    }

    function shouldRebase() internal view returns (bool) {
        return nextRebase <= block.timestamp;
    }
    
    function updateYield(address user, uint256 newTier) external  {
        require(msg.sender == avionNFT, "You're not nft collection");

        uint256 tokenBalance = _gonBalances[user].div(getYield(user));
        _gonBalances[user] = tokenBalance.mul(_yields[newTier]);
    }
    
    function _rebase() private {
        if (!inSwap) {
            uint256 epoch = block.timestamp;
            nextRebase = epoch + rebaseFrequency;

            for (uint256 i; i < rewardYields.length; i++) {

                supplys[i] += supplys[i] * rewardYields[i] / rewardYieldDenominator;

                _yields[i]= TOTAL_GONS.div(supplys[i]);
            }

            if (pair != address(0x0)) IPancakePair(pair).sync();

            emit LogRebase(epoch);
        }
    }
    
    function setAutoRebase(bool _autoRebase) external onlyOwner {
        require(autoRebase != _autoRebase, "Not changed");
        autoRebase = _autoRebase;
        emit SetAutoRebase(_autoRebase);
    }
    
    function getYield(address user) public view returns(uint256) {
        return _yields[IAvionCollection(avionNFT).getHigherTier(user)];
    }

    function manualRebase() external  nonReentrant{
        require(!inSwap, "Try again");
        require(nextRebase <= block.timestamp, "Not in time");

        _rebase();
        emit ManualRebase();
    }

    function setRebaseFrequency(uint256 _rebaseFrequency) external onlyOwner {
        rebaseFrequency = _rebaseFrequency;
        emit SetRebaseFrequency(_rebaseFrequency);
    }

    function setRewardYield(
        uint256[] memory _rewardYield,
        uint256 _rewardYieldDenominator
    ) external onlyOwner {
        rewardYields = _rewardYield;
        rewardYieldDenominator = _rewardYieldDenominator;
        emit SetRewardYield(_rewardYield,_rewardYieldDenominator);
    }






    /* Tax functions */

    function setFeeExempt(address _addr, bool _value) external onlyOwner {
        require(_isFeeExempt[_addr] != _value, "Not changed");
        _isFeeExempt[_addr] = _value;
        emit SetFeeExempted(_addr, _value);
    }

    function setSwapBackSettings(
        bool _enabled,
        uint256 _num,
        uint256 _denom
    ) external onlyOwner {
        swapEnabled = _enabled;
        gonSwapThreshold = _totalSupply.div(_denom).mul(_num);
        emit SetSwapBackSettings(_enabled, _num, _denom);
    }
    
    function checkFeeExempt(address _addr) external view returns (bool) {
        return _isFeeExempt[_addr];
    }
    
    function setFees(
        //0 : Liquidity
        //1 : Treasury
        //2 : Team
        //3 : Burn
        uint256[] memory _buyFees,
        uint256[] memory _sellFees,
        uint256[] memory _transferFees,
        uint256 _feeDenominator
    ) external onlyOwner {

        buyFees = _buyFees;
        sellFees = _sellFees;

        totalBuyFee = 0;
        totalSellFee = 0;
        totalTransferFee = 0;

        for (uint256 i; i < buyFees.length; i++) {
            totalBuyFee += buyFees[i];
        }

        for (uint256 i; i < sellFees.length; i++) {
            totalSellFee += sellFees[i];
        }

        for (uint256 i; i < _transferFees.length; i++) {
            totalTransferFee += _transferFees[i];
        }
        
        feeDenominator = _feeDenominator;
    }
    
    function shouldTakeFee(address from, address to)
        internal
        view
        returns (bool)
    {
        if (_isFeeExempt[from] || _isFeeExempt[to]) {
            return false;
        } else return true;
    } 
    
    function takeFee(
        address sender,
        address recipient,
        uint256 gonAmount,
        uint256 gonsPerFragment
    ) internal returns (uint256) {
        uint256 _realFee = totalTransferFee;
        if (automatedMarketMakerPairs[recipient]) _realFee = totalSellFee;
        if (automatedMarketMakerPairs[sender]) _realFee = totalBuyFee;

        if (recipient == pair) {
            updateAvailableAmount(sender, gonAmount);
        }

        uint256 contractGons = getYield(address(this));

        uint256 feeAmount = gonAmount.div(gonsPerFragment).mul(contractGons).mul(_realFee).div(feeDenominator);

        _gonBalances[address(this)] = _gonBalances[address(this)].add(
            feeAmount
        );
        
        emit Transfer(sender, address(this), feeAmount.div(contractGons));

        return gonAmount.sub(feeAmount.div(contractGons).mul(gonsPerFragment));
    }





    /* Swap Back sell tokens */

    function setRouter(address _router) external onlyOwner {
        router = IPancakeRouter02(_router);
    }
    
    function setFeeReceivers(
        address _liquidityReceiver,
        address _treasuryReceiver,
        address _teamReceiver,
        address _burnReceiver
    ) external onlyOwner {
        liquidityReceiver = _liquidityReceiver;
        treasuryReceiver = _treasuryReceiver;
        teamReceiver = _teamReceiver;
        burnReceiver = _burnReceiver;
        emit SetFeeReceivers(_liquidityReceiver, _treasuryReceiver, _teamReceiver);
    }
    
    function checkSwapThreshold() external view returns (uint256) {
        return gonSwapThreshold.div(getYield(address(this)));
    } 

    function shouldSwapBack() internal view returns (bool) {
        return
            !automatedMarketMakerPairs[msg.sender] &&
            !inSwap &&
            swapEnabled &&
            totalBuyFee.add(totalSellFee).add(totalTransferFee) > 0 &&
            _gonBalances[address(this)] >= gonSwapThreshold;
    }
    
    function _swapAndLiquify(uint256 contractTokenBalance) private {
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);

        uint256 initialBalance = IERC20(busdToken).balanceOf(address(this));

        _swapTokensForStable(half, address(this));

        uint256 newBalance = IERC20(busdToken).balanceOf(address(this)).sub(
            initialBalance
        );

        _addLiquidityStable(otherHalf, newBalance);

        emit SwapAndLiquify(half, newBalance, otherHalf);
    }

    function _addLiquidityStable(uint256 tokenAmount, uint256 stableAmount)
        private
    {
        router.addLiquidity(
            address(this),
            busdToken,
            tokenAmount,
            stableAmount,
            0,
            0,
            liquidityReceiver,
            block.timestamp
        );
    }

    function _swapTokensForStable(uint256 tokenAmount, address receiver) private {
        address[] memory path = new address[](3);
        path[0] = address(this);
        path[1] = busdToken;

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            receiver,
            block.timestamp
        );
    }

    function swapBack() internal swapping {
        uint256 buyAmount = balanceOf(address(this)).div(3);
        uint256 sellAmount = balanceOf(address(this)).sub(3);
        uint256 transferAmount = balanceOf(address(this)).sub(buyAmount).sub(sellAmount);

        uint256 amountToLiquify = buyAmount
            .mul(buyFees[0])
            .div(totalBuyFee);

        amountToLiquify += sellAmount
            .mul(sellFees[0])
            .div(totalSellFee);

        amountToLiquify += transferAmount
            .mul(sellFees[0])
            .div(totalTransferFee);



        uint256 amountToTreasury = buyAmount
            .mul(buyFees[1])
            .div(totalBuyFee);

        amountToTreasury += sellAmount
            .mul(sellFees[1])
            .div(totalSellFee);

        amountToTreasury += transferAmount
            .mul(sellFees[1])
            .div(totalTransferFee);



        uint256 amountToTeam = buyAmount
            .mul(buyFees[2])
            .div(totalBuyFee);

        amountToTeam += sellAmount
            .mul(sellFees[2])
            .div(totalSellFee);

        amountToTeam += transferAmount
            .mul(sellFees[2])
            .div(totalTransferFee);



        uint256 amountToBurn = buyAmount
            .mul(buyFees[3])
            .div(totalBuyFee);

        amountToBurn += sellAmount
            .mul(sellFees[3])
            .div(totalSellFee);

        amountToBurn += transferAmount
            .mul(sellFees[3])
            .div(totalTransferFee);



        if (amountToLiquify > 0) {
            _swapAndLiquify(amountToLiquify);
        }

        if (amountToTreasury > 0) {
            _swapTokensForStable(amountToTreasury, treasuryReceiver);
        }

        if (amountToTeam > 0) {
            _swapTokensForStable(amountToTeam, teamReceiver);
        }

        if (amountToBurn > 0) {
            transfer(burnReceiver, amountToBurn);
        }

        emit SwapBack(
            buyAmount.add(sellAmount).add(transferAmount),
            amountToLiquify,
            amountToTreasury,
            amountToTeam,
            amountToBurn
        );
    }

    function manualSwapBack() external onlyOwner {
        swapBack();
    }




    /* Anti Dump system */

    function changePercentageForSaleAmount(uint256 _percentageForLessThanSevenDays, uint256 _percentageForMoreThanSevenDays) external onlyOwner {
        percentageForLessThanSevenDays = _percentageForLessThanSevenDays;
        percentageForMoreThanSevenDays = _percentageForMoreThanSevenDays;
    }
    
    function updateAvailableAmount (address sender, uint256 amount) internal {
        uint256 yieldSender = getYield(sender);
        if (block.timestamp - usersInfo[sender].lastTimeSold >= 1 days && block.timestamp - usersInfo[sender].lastTimeSold < 7 days) {
            usersInfo[sender].amountAvailable = (_gonBalances[sender].div(yieldSender) * percentageForLessThanSevenDays) / 1000;
            usersInfo[sender].lastTimeSold = block.timestamp;
        } else if (block.timestamp - usersInfo[sender].lastTimeSold >= 7 days) {
            usersInfo[sender].amountAvailable = (_gonBalances[sender].div(yieldSender) * percentageForMoreThanSevenDays) / 1000;
            usersInfo[sender].lastTimeSold = block.timestamp;
        }

        require(amount.div(yieldSender) <=  usersInfo[sender].amountAvailable, "Avion: you sell more than you can");

        usersInfo[sender].amountAvailable = (usersInfo[sender].amountAvailable).sub(amount.div(yieldSender));
    }

    function getAvailableAmount (address sender) external view returns(uint256) {
        if (block.timestamp - usersInfo[sender].lastTimeSold >= 1 days && block.timestamp - usersInfo[sender].lastTimeSold < 7 days) {
            return balanceOf(sender) * percentageForLessThanSevenDays / 1000;
        } else if (block.timestamp - usersInfo[sender].lastTimeSold >= 7 days) {
            return balanceOf(sender) * percentageForMoreThanSevenDays / 1000;
        }
        return usersInfo[sender].amountAvailable;
    }

    



    /* Random things */

    receive() external payable {}

    function setNft(address _avionNFT) external onlyOwner {
        avionNFT = _avionNFT;
    }

    function setBUSD(address _busdToken) external onlyOwner {
        busdToken = _busdToken;
    }

    function setAutomatedMarketMakerPair(address _pair, bool _value)
        public
        onlyOwner
    {
        automatedMarketMakerPairs[_pair] = _value;
        pair = _pair;

        emit SetAutomatedMarketMakerPair(_pair, _value);
    }

    function setInitialDistributionFinished(bool _value) external onlyOwner {
        require(initialDistributionFinished != _value, "Not changed");
        initialDistributionFinished = _value;
        emit SetInitialDistributionFinished(_value);
    }
    
    function clearStuckBalance(address _receiver) external onlyOwner {
        uint256 balance = address(this).balance;
        payable(_receiver).transfer(balance);
        emit ClearStuckBalance(_receiver);
    }

    function getLink(address _receiver) external onlyOwner {
        IERC20(0xF8A0BF9cF54Bb92F17374d9e9A321E6a111a51bD).transfer(_receiver, IERC20(0xF8A0BF9cF54Bb92F17374d9e9A321E6a111a51bD).balanceOf(address(this)));
    }
    

    event SwapBack(
        uint256 contractTokenBalance,
        uint256 amountToLiquify,
        uint256 amountToTreasury,
        uint256 amountToTeam,
        uint256 amountToBurn
    );
    event SwapAndLiquify(
        uint256 tokensSwapped,
        uint256 bnbReceived,
        uint256 tokensIntoLiqudity
    );
    event LogRebase(uint256 indexed epoch);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
    event ManualRebase();
    event SetInitialDistributionFinished(bool _value);
    event SetFeeExempted(address _addr, bool _value);
    event SetSwapBackSettings(bool _enabled, uint256 _num, uint256 _denom);
    event SetFeeReceivers(
        address _liquidityReceiver,
        address _treasuryReceiver,
        address _teamReceiver
    );
    event ClearStuckBalance(address _receiver);
    event SetAutoRebase(bool _autoRebase);
    event SetRebaseFrequency(uint256 _rebaseFrequency);
    event SetRewardYield(uint256[] _rewardYield, uint256 _rewardYieldDenominator);
    event SetIsLiquidityInBnb(bool _value);
    event SetNextRebase(uint256 _nextRebase);

}