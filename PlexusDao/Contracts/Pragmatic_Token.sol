    // SPDX-License-Identifier: None

    pragma solidity 0.7.4;

    library SafeMathInt {
        int256 private constant MIN_INT256 = int256(1) << 255;
        int256 private constant MAX_INT256 = ~(int256(1) << 255);

        function mul(int256 a, int256 b) internal pure returns (int256) {
            int256 c = a * b;

            require(c != MIN_INT256 || (a & MIN_INT256) != (b & MIN_INT256));
            require((b == 0) || (c / b == a));
            return c;
        }

        function div(int256 a, int256 b) internal pure returns (int256) {
            require(b != -1 || a != MIN_INT256);

            return a / b;
        }

        function sub(int256 a, int256 b) internal pure returns (int256) {
            int256 c = a - b;
            require((b >= 0 && c <= a) || (b < 0 && c > a));
            return c;
        }

        function add(int256 a, int256 b) internal pure returns (int256) {
            int256 c = a + b;
            require((b >= 0 && c >= a) || (b < 0 && c < a));
            return c;
        }

        function abs(int256 a) internal pure returns (int256) {
            require(a != MIN_INT256);
            return a < 0 ? -a : a;
        }
    }

    interface IERC20 {
        function totalSupply() external view returns (uint256);

        function balanceOf(address who) external view returns (uint256);

        function allowance(address owner, address spender) external view returns (uint256);

        function transfer(address to, uint256 value) external returns (bool);

        function approve(address spender, uint256 value) external returns (bool);

        function transferFrom(address from, address to, uint256 value) external returns (bool);

        event Transfer(address indexed from, address indexed to, uint256 value);

        event Approval(address indexed owner, address indexed spender, uint256 value);

    }

    library SafeMath {
        function add(uint256 a, uint256 b) internal pure returns (uint256) {
            uint256 c = a + b;
            require(c >= a, "SafeMath: addition overflow");

            return c;
        }

        function sub(uint256 a, uint256 b) internal pure returns (uint256) {
            return sub(a, b, "SafeMath: subtraction overflow");
        }

        function sub(
            uint256 a,
            uint256 b,
            string memory errorMessage
        ) internal pure returns (uint256) {
            require(b <= a, errorMessage);
            uint256 c = a - b;

            return c;
        }

        function mul(uint256 a, uint256 b) internal pure returns (uint256) {
            if (a == 0) {
                return 0;
            }

            uint256 c = a * b;
            require(c / a == b, "SafeMath: multiplication overflow");

            return c;
        }

        function div(uint256 a, uint256 b) internal pure returns (uint256) {
            return div(a, b, "SafeMath: division by zero");
        }

        function div(
            uint256 a,
            uint256 b,
            string memory errorMessage
        ) internal pure returns (uint256) {
            require(b > 0, errorMessage);
            uint256 c = a / b;

            return c;
        }

        function mod(uint256 a, uint256 b) internal pure returns (uint256) {
            require(b != 0);
            return a % b;
        }
    }

    interface InterfaceLP {
        function sync() external;
    }

    library Roles {
        struct Role {
            mapping (address => bool) bearer;
        }

        function add(Role storage role, address account) internal {
            require(!has(role, account), "Roles: account already has role");
            role.bearer[account] = true;
        }

        function remove(Role storage role, address account) internal {
            require(has(role, account), "Roles: account does not have role");
            role.bearer[account] = false;
        }

        function has(Role storage role, address account) internal view returns (bool) {
            require(account != address(0), "Roles: account is the zero address");
            return role.bearer[account];
        }
    }

    abstract contract ERC20Detailed is IERC20 {
        string private _name;
        string private _symbol;
        uint8 private _decimals;

        constructor(
            string memory _tokenName,
            string memory _tokenSymbol,
            uint8 _tokenDecimals
        ) {
            _name = _tokenName;
            _symbol = _tokenSymbol;
            _decimals = _tokenDecimals;
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

    interface IDEXRouter {
        function factory() external pure returns (address);

        function WETH() external pure returns (address);

        function addLiquidity(
            address tokenA,
            address tokenB,
            uint256 amountADesired,
            uint256 amountBDesired,
            uint256 amountAMin,
            uint256 amountBMin,
            address to,
            uint256 deadline
        )
        external
        returns (
            uint256 amountA,
            uint256 amountB,
            uint256 liquidity
        );

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

        function swapExactTokensForTokensSupportingFeeOnTransferTokens(
            uint256 amountIn,
            uint256 amountOutMin,
            address[] calldata path,
            address to,
            uint256 deadline
        ) external;

        function swapExactETHForTokensSupportingFeeOnTransferTokens(
            uint256 amountOutMin,
            address[] calldata path,
            address to,
            uint256 deadline
        ) external payable;

        function swapExactTokensForETHSupportingFeeOnTransferTokens(
            uint256 amountIn,
            uint256 amountOutMin,
            address[] calldata path,
            address to,
            uint256 deadline
        ) external;
    }

    interface IDEXFactory {
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
            require(msg.sender == _owner, "Not owner");
            _;
        }

        function renounceOwnership() public onlyOwner {
            emit OwnershipRenounced(_owner);
            _owner = address(0);
        }

        function transferOwnership(address newOwner) public onlyOwner {
            _transferOwnership(newOwner);
        }

        function _transferOwnership(address newOwner) internal {
            require(newOwner != address(0), "Zero Address Validation");
            emit OwnershipTransferred(_owner, newOwner);
            _owner = newOwner;
        }
    }

    interface IReferralCA {
        function getReferrer(address _address) external view returns (address);

        function getIsReferred(address _address) external view returns (bool);

        function updateReferralIncome(address _address, uint256 _income) external;

    }

    contract PlexusDAO is ERC20Detailed, Ownable {
        using SafeMath for uint256;
        using SafeMathInt for int256;

        //Events
        event TimeFupdated(uint256 _timeF);
        event SwapBack(uint256 contractTokenBalance,uint256 amountToLiquify,uint256 amountToRFV,uint256 amountToTreasury);
        event SwapAndLiquify(uint256 tokensSwapped, uint256 bnbReceived, uint256 tokensForLiquidity);
        event SwapAndLiquifyBusd(uint256 tokensSwapped, uint256 busdReceived, uint256 tokensForLiquidity);
        event LogRebase(uint256 indexed epoch, uint256 totalSupply);
        event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
        event SetMaxSupply(uint256 _maxSupply);
        event SetMaxWalletExempt(address _address, bool _bool);
        event SetMaxSellAmount(uint256 _maxTxn);
        event SellFeesChanged(uint256 _liquidityFee, uint256 _treasuryFee, uint256 _sellFeeRFV, uint256 _stakingFee);
        event BuyFeesChanged(uint256 _liquidityFee, uint256 _treasuryFee, uint256 _buyFeeRFV, uint256 _referralFee, uint256 _stakingFee);
        event SetRebaseFrequency(uint256 _rebaseFrequency);
        event MinReferralAmountActive(bool _bool);
        event SetTransferFee(uint256 _transferFee);
        event SetFeeReceivers(address _liquidityReceiver, address _treasuryReceiver, address _riskFreeValueReceiver, address _stakingFeeReceiver);
        event ChangedSwapBack(bool _enabled, uint256 _num, uint256 _denom);
        event SetFeeExempt(address _addr, bool _value);
        event InitialDistributionFinished(bool _value);
        event MinReferralSupplyUpdated(uint256 _minSupply);
        event ChangedMaxWalletDenom(uint256 _maxWalletDenom);
        event ChangeRewardYield(uint256 _rewardYield, uint256 _rewardYieldDenominator);
        event ChangeLiquidityInBNB(bool _value);
        event SetNextRebase(uint256 _nextRebase);

        //Variables
        bool public initialDistributionFinished = false;
        bool public swapEnabled = true;
        bool public isLiquidityInBnb = true;

        uint256 private rewardYield = 7367829;
        uint256 private rewardYieldDenominator = 10000000000;
        uint256 public maxSellTransactionAmount = 25000000 * 10 ** 18;

        uint256 public rebaseFrequency = 1800;
        uint256 public nextRebase = block.timestamp + 31536000;

        mapping(address => bool) public _isFeeExempt;
        address[] public _markerPairs;
        mapping (address => bool) public automatedMarketMakerPairs;

        uint256 private constant MAX_REBASE_FREQUENCY = 1800;
        uint256 private constant DECIMALS = 18;
        uint256 private constant MAX_UINT256 = ~uint256(0);
        uint256 private constant INITIAL_FRAGMENTS_SUPPLY = 5 * 10**9 * 10**DECIMALS;
        uint256 private constant TOTAL_GONS = MAX_UINT256 - (MAX_UINT256 % INITIAL_FRAGMENTS_SUPPLY);
        uint256 private MAX_SUPPLY = ~uint128(0);

        address private constant DEAD = 0x000000000000000000000000000000000000dEaD;
        address private constant ZERO = 0x0000000000000000000000000000000000000000;

        address private liquidityReceiver = 0xf2f17F41de48A5E8a24C6De5F649577aA856a7A6;
        address private treasuryReceiver = 0xE0E2EADafcF00A50c79B42705dF132941F388C3f;
        address private riskFreeValueReceiver = 0x0d8173884F4b0eD2FE66772cd3e8651E60D2a018;
        address private stakingFeeReceiver = 0xa94FCA74301b5760D5d4323db0910aA56b5F4992;

        address private constant busdToken = 0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7; //Testnet 0x78867BbEeF44f2326bF8DDd1941a4439382EF2A7 //Mainnet: 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56


        IDEXRouter public router;
        address public pair;
        address public pairBusd;

        uint256 private timeF;
        uint256 private launchTimestamp;

        //buyFee
        uint256 private liquidityFee = 5;
        uint256 private treasuryFee = 4;
        uint256 private buyFeeRFV = 2;
        uint256 private referralFee = 5;
        uint256 private stakingFee = 0;


        //sellFee
        uint256 private sellFeeTreasury = 6;
        uint256 private sellFeeRFV = 5;
        uint256 private sellFeeLiquidity = 5;
        uint256 private sellFeeStaking = 2;

        //transfer Fee
        uint256 private transferFee = 15;

        uint256 public constant maxFee = 30;


        uint256 private totalBuyFee = liquidityFee.add(treasuryFee).add(buyFeeRFV).add(referralFee).add(stakingFee);
        uint256 private totalSellFee = sellFeeLiquidity.add(sellFeeRFV).add(sellFeeTreasury).add(sellFeeStaking);
        uint256 private constant feeDenominator = 100;


        mapping (address => bool) public isMaxWalletExempt;
        mapping (address => bool) public isBl;
        uint256 public _maxWalletSize = (INITIAL_FRAGMENTS_SUPPLY * 1) / 100;
        uint256 private maxWalletDenom = 100;

        mapping (address => bool) private isAllowedToRebase;



        //Referrals

        IReferralCA private referralCA;

        uint256 private minSupplyForReferralReward = (INITIAL_FRAGMENTS_SUPPLY * 5) / 10000 ; //0.05% of the supply needs to be updated depending on rebasing
        bool public minReferralActive = false;

        //util
        bool private inSwap;

        modifier swapping() {
            inSwap = true;
            _;
            inSwap = false;
        }

        modifier validRecipient(address to) {
            require(to != address(0x0), "Invalid recipient");
            _;
        }

        uint256 private _totalSupply;
        uint256 public _gonsPerFragment;
        uint256 public gonSwapThreshold = (TOTAL_GONS * 10) / 10000;

        mapping(address => uint256) private _gonBalances;
        mapping(address => mapping(address => uint256)) private _allowedFragments;

        constructor(address _referralCA) ERC20Detailed("Plexus DAO", "PLEXUS", uint8(DECIMALS)) {
            router = IDEXRouter(0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3); //Mainnet BSC :0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c // Testnet BSC: 0x9Ac64Cc6e4415144C455BD8E4837Fea55603e5c3
            pair = IDEXFactory(router.factory()).createPair(address(this), router.WETH());
            pairBusd = IDEXFactory(router.factory()).createPair(address(this), busdToken);

            _allowedFragments[address(this)][address(router)] = uint256(-1);
            _allowedFragments[address(this)][pair] = uint256(-1);
            _allowedFragments[address(this)][address(this)] = uint256(-1);
            _allowedFragments[address(this)][pairBusd] = uint256(-1);

            setAutomatedMarketMakerPair(pair, true);
            setAutomatedMarketMakerPair(pairBusd, true);

            _totalSupply = INITIAL_FRAGMENTS_SUPPLY;
            _gonBalances[msg.sender] = TOTAL_GONS;
            _gonsPerFragment = TOTAL_GONS.div(_totalSupply);

            _isFeeExempt[treasuryReceiver] = true;
            _isFeeExempt[riskFreeValueReceiver] = true;
            _isFeeExempt[address(this)] = true;
            _isFeeExempt[msg.sender] = true;

            isMaxWalletExempt[address(this)] = true;
            isMaxWalletExempt[msg.sender] = true;
            isMaxWalletExempt[stakingFeeReceiver] = true;
            isMaxWalletExempt[pair] = true;
            isMaxWalletExempt[pairBusd] = true;

            IERC20(busdToken).approve(address(router), uint256(-1));
            IERC20(busdToken).approve(address(pairBusd), uint256(-1));
            IERC20(busdToken).approve(address(this), uint256(-1));

            referralCA = IReferralCA(_referralCA);

            emit Transfer(address(0x0), msg.sender, _totalSupply);
        }

        receive() external payable {}

        function totalSupply() external view override returns (uint256) {
            return _totalSupply;
        }

        function allowance(address owner_, address spender) external view override returns (uint256){
            return _allowedFragments[owner_][spender];
        }

        function balanceOf(address who) public view override returns (uint256) {
            return _gonBalances[who].div(_gonsPerFragment);
        }

        function checkFeeExempt(address _addr) external view returns (bool) {
            return _isFeeExempt[_addr];
        }

        function checkSwapThreshold() external view returns (uint256) {
            return gonSwapThreshold.div(_gonsPerFragment);
        }


        function shouldSwapBack() public view returns (bool) {
            return
            !automatedMarketMakerPairs[msg.sender] &&
            !inSwap &&
            swapEnabled &&
            totalBuyFee.add(totalSellFee) > 0 &&
            _gonBalances[address(this)] >= gonSwapThreshold;
        }

        function getCirculatingSupply() public view returns (uint256) {
            return (TOTAL_GONS.sub(_gonBalances[DEAD]).sub(_gonBalances[ZERO])).div(_gonsPerFragment);
        }


        function getGonsPerFragment() public view returns (uint256) {
            return _gonsPerFragment;
        }

        function manualSync() public {
            for(uint i = 0; i < _markerPairs.length; i++){
                InterfaceLP(_markerPairs[i]).sync();
            }
        }

        //Transfer
        function transfer(address to, uint256 value) external override validRecipient(to) returns (bool){
            _transferFrom(msg.sender, to, value);
            return true;
        }

        function _basicTransfer(address from, address to, uint256 amount) internal returns (bool) {
            require(balanceOf(from) >= amount, "Not Enough tokens");
            uint256 gonAmount = amount.mul(_gonsPerFragment);
            _gonBalances[from] = _gonBalances[from].sub(gonAmount);
            _gonBalances[to] = _gonBalances[to].add(gonAmount);

            emit Transfer(from, to, amount);

            return true;
        }

        function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {
            require (!isBl[sender] && !isBl[recipient], "You are a sniper");
            bool excludedAccount = _isFeeExempt[sender] || _isFeeExempt[recipient];

            require(initialDistributionFinished || excludedAccount, "Trading not started");

            if (inSwap) {
                return _basicTransfer(sender, recipient, amount);
            }

            uint256 gonAmount = amount.mul(_gonsPerFragment);
            uint256 gonAmountReceived = gonAmount;

            if (shouldSwapBack() && recipient!= DEAD) {
                swapBack();
            }

            if(automatedMarketMakerPairs[sender]) { //buy
                if(!_isFeeExempt[recipient]) {
                    require(isMaxWalletExempt[recipient] || _gonBalances[recipient] + gonAmount <= _maxWalletSize.mul(_gonsPerFragment), "Transfer amount exceeds max wallet size.");
                    gonAmountReceived = takeBuyFee(sender, recipient, gonAmount);
                }

            } else if(automatedMarketMakerPairs[recipient]) { //sell
                if(!_isFeeExempt[sender]) {
                    require(amount <= maxSellTransactionAmount, "Error amount");
                    gonAmountReceived = takeSellFee(sender, gonAmount);
                }

            } else {
                if (!_isFeeExempt[sender]) {
                    gonAmountReceived = takeTransferFee(sender, gonAmount);
                }
            }

            _gonBalances[sender] = _gonBalances[sender].sub(gonAmount);
            _gonBalances[recipient] = _gonBalances[recipient].add(gonAmountReceived);

            emit Transfer(
                sender,
                recipient,
                gonAmountReceived.div(_gonsPerFragment)
            );

            return true;
        }

        function transferFrom(address from, address to, uint256 value) external override validRecipient(to) returns (bool) {
            if (_allowedFragments[from][msg.sender] != uint256(-1)) {
                _allowedFragments[from][msg.sender] = _allowedFragments[from][
                msg.sender
                ].sub(value, "Insufficient Allowance");
            }

            _transferFrom(from, to, value);
            return true;
        }

        function _swapAndLiquify(uint256 _amount) private {
            uint256 half = _amount.div(2);
            uint256 otherHalf = _amount.sub(half);

            if(isLiquidityInBnb){
                uint256 initialBalance = address(this).balance;

                _swapTokensForBNB(half, address(this));

                uint256 newBalance = address(this).balance.sub(initialBalance);

                _addLiquidity(otherHalf, newBalance);

                emit SwapAndLiquify(half, newBalance, otherHalf);
            }else{
                uint256 initialBalance = IERC20(busdToken).balanceOf(address(this));

                _swapTokensForBusd(half, address(this));

                uint256 newBalance = IERC20(busdToken).balanceOf(address(this)).sub(initialBalance);

                _addLiquidityBusd(otherHalf, newBalance);

                emit SwapAndLiquifyBusd(half, newBalance, otherHalf);
            }
        }

        function _addLiquidity(uint256 tokenAmount, uint256 bnbAmount) private {
            router.addLiquidityETH{value: bnbAmount}(
                address(this),
                tokenAmount,
                0,
                0,
                liquidityReceiver,
                block.timestamp
            );
        }
        function _addLiquidityBusd(uint256 tokenAmount, uint256 busdAmount) private {
            router.addLiquidity(
                address(this),
                busdToken,
                tokenAmount,
                busdAmount,
                0,
                0,
                liquidityReceiver,
                block.timestamp
            );
        }

        function _swapTokensForBNB(uint256 tokenAmount, address receiver) private {
            address[] memory path = new address[](2);
            path[0] = address(this);
            path[1] = router.WETH();

            router.swapExactTokensForETHSupportingFeeOnTransferTokens(
                tokenAmount,
                0,
                path,
                receiver,
                block.timestamp
            );
        }
        function _swapTokensForBusd(uint256 tokenAmount, address receiver) private {
            address[] memory path = new address[](3);
            path[0] = address(this);
            path[1] = router.WETH();
            path[2] = busdToken;

            router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
                tokenAmount,
                0,
                path,
                receiver,
                block.timestamp
            );
        }


        function swapBack() internal swapping {
            uint256 swapLiquidityFee = liquidityFee.add(sellFeeLiquidity);
            uint256 swapTreasuryFee = treasuryFee.add(sellFeeTreasury);
            uint256 swapRFVFee = buyFeeRFV.add(sellFeeRFV);
            uint256 realTotalFee =swapLiquidityFee.add(swapTreasuryFee).add(swapRFVFee);

            uint256 contractTokenBalance = _gonBalances[address(this)].div(_gonsPerFragment);

            uint256 amountToLiquify = contractTokenBalance.mul(swapLiquidityFee).div(realTotalFee);
            uint256 amountToRFV = contractTokenBalance.mul(swapRFVFee).div(realTotalFee);
            uint256 amountToTreasury = contractTokenBalance.sub(amountToLiquify).sub(amountToRFV).sub(1e18);

            if(amountToLiquify > 0){
               _swapAndLiquify(amountToLiquify);
            }

            if(amountToRFV > 0){
                _swapTokensForBusd(amountToRFV, riskFreeValueReceiver);
            }

            if(amountToTreasury > 0){
                _swapTokensForBNB(amountToTreasury, treasuryReceiver);
            }

            emit SwapBack(contractTokenBalance, amountToLiquify, amountToRFV, amountToTreasury);
        }


        // Fees
        function takeBuyFee(address sender, address recipient, uint256 gonAmount) internal returns (uint256){
            bool isReferredBuyer = referralCA.getIsReferred(recipient);

            //Catch Snipers
            uint256 time_since_start = block.timestamp - launchTimestamp;
            if (time_since_start < timeF) {
                isBl[recipient] = true;
                }

            uint256 _realFee = totalBuyFee;
            address referralFeeReceiver;

            if(isReferredBuyer) {referralFeeReceiver = referralCA.getReferrer(recipient);}
            else{referralFeeReceiver = address(this);} //If not referred, fee will go to CA

            uint256 referralFeeAmount = gonAmount.mul(referralFee).div(feeDenominator);
            uint256 feeAmount = gonAmount.mul((_realFee.sub(referralFee).sub(stakingFee))).div(feeDenominator);
            uint256 stakingFeeAmount = gonAmount.mul(stakingFee).div(feeDenominator);
            uint256 totalFeeAmount = feeAmount.add(referralFeeAmount).add(stakingFeeAmount);


            //You only get the referral fee if you hold enough tokens or if the min Amount is deactivated
            if(_gonBalances[referralFeeReceiver] < minSupplyForReferralReward.mul(_gonsPerFragment) && minReferralActive){
                referralFeeReceiver = address(this);
            }

            _gonBalances[address(this)] = _gonBalances[address(this)].add(feeAmount);
            emit Transfer(sender, address(this), feeAmount.div(_gonsPerFragment));


            //Set Max Wallet exempt, otherwise buy transaction might fail if ReferralFeeReceiver owns more than Max Wallet
            isMaxWalletExempt[referralFeeReceiver] = true;
            _gonBalances[referralFeeReceiver] = _gonBalances[referralFeeReceiver].add(referralFeeAmount);
            referralCA.updateReferralIncome(referralFeeReceiver, referralFeeAmount.div(_gonsPerFragment));
            emit Transfer(sender, referralFeeReceiver, referralFeeAmount.div(_gonsPerFragment));
            isMaxWalletExempt[referralFeeReceiver] = false;

            //Only emit event if tokens are transferred to staking
            if(stakingFeeAmount > 0) {
                _gonBalances[stakingFeeReceiver] = _gonBalances[stakingFeeReceiver].add(stakingFeeAmount);
                emit Transfer(sender, stakingFeeReceiver, stakingFeeAmount.div(_gonsPerFragment));
            }

            return gonAmount.sub(totalFeeAmount);
        }

        function takeSellFee(address sender, uint256 gonAmount) internal returns (uint256){
            uint256 _realFee = totalSellFee;
            uint256 feeAmount = gonAmount.mul((_realFee).sub(sellFeeStaking)).div(feeDenominator);
            uint256 stakingFeeAmount = gonAmount.mul(sellFeeStaking).div(feeDenominator);
            uint256 totalFeeAmount = feeAmount.add(stakingFeeAmount);

            _gonBalances[address(this)] = _gonBalances[address(this)].add(feeAmount);
            emit Transfer(sender, address(this), feeAmount.div(_gonsPerFragment));

            //Only emit event if tokens are transferred to staking
            if(stakingFeeAmount > 0) {
                _gonBalances[stakingFeeReceiver] = _gonBalances[stakingFeeReceiver].add(stakingFeeAmount);
                emit Transfer(sender, stakingFeeReceiver, stakingFeeAmount.div(_gonsPerFragment));
            }


            return gonAmount.sub(totalFeeAmount);

        }

        function takeTransferFee(address sender, uint256 gonAmount) internal returns (uint256){
            uint256 _realFee = transferFee;
            uint256 feeAmount = gonAmount.mul(_realFee).div(feeDenominator);

            _gonBalances[address(this)] = _gonBalances[address(this)].add(feeAmount);
            emit Transfer(sender, address(this), feeAmount.div(_gonsPerFragment));

            return gonAmount.sub(feeAmount);
        }

        //referrals
        function updateMinSupplyForReferralReward(uint256 _minSupply) external onlyOwner {
            minSupplyForReferralReward = _minSupply;
            emit MinReferralSupplyUpdated(_minSupply);
        }


        //Utils
        function setBl(address _address, bool _bool) external onlyOwner {
            isBl[_address] = _bool;

        }

        function manualRebase() external {
            require(isAllowedToRebase[msg.sender], "Not allowed to rebase");
            require(!inSwap, "Try again");
            require(nextRebase <= block.timestamp, "Not in time");

            uint256 circulatingSupply = getCirculatingSupply();
            int256 supplyDelta = int256(circulatingSupply.mul(rewardYield).div(rewardYieldDenominator));

            coreRebase(supplyDelta);
            manualSync();
        }

        function setAutomatedMarketMakerPair(address _pair, bool _value) public onlyOwner {
            require(automatedMarketMakerPairs[_pair] != _value, "Value already set");

            automatedMarketMakerPairs[_pair] = _value;

            if(_value){
                _markerPairs.push(_pair);
            }else{
                require(_markerPairs.length > 1, "Required 1 pair");
                for (uint256 i = 0; i < _markerPairs.length; i++) {
                    if (_markerPairs[i] == _pair) {
                        _markerPairs[i] = _markerPairs[_markerPairs.length - 1];
                        _markerPairs.pop();
                        break;
                    }
                }
            }

            emit SetAutomatedMarketMakerPair(_pair, _value);
        }

        function setInitialDistributionFinished(bool _value) external onlyOwner {
            require(initialDistributionFinished == false, "Can't deactivate Trading");
            initialDistributionFinished = _value;
            launchTimestamp = block.timestamp;
            emit InitialDistributionFinished(_value);
        }

        function setFeeExempt(address _addr, bool _value) external onlyOwner {
            require(_isFeeExempt[_addr] != _value, "Not changed");
            _isFeeExempt[_addr] = _value;
            emit SetFeeExempt(_addr, _value);
        }


        function setSwapBackSettings(bool _enabled, uint256 _num, uint256 _denom) external onlyOwner {
            swapEnabled = _enabled;
            gonSwapThreshold = TOTAL_GONS.div(_denom).mul(_num);
            emit ChangedSwapBack(_enabled, _num, _denom);
        }

        function setFeeReceivers(address _liquidityReceiver, address _treasuryReceiver, address _riskFreeValueReceiver, address _stakingFeeReceiver) external onlyOwner {
            require(_liquidityReceiver != address(0) && _treasuryReceiver != address(0) && _riskFreeValueReceiver != address(0) && _stakingFeeReceiver != address(0), "Zero Address Validation");
            liquidityReceiver = _liquidityReceiver;
            treasuryReceiver = _treasuryReceiver;
            riskFreeValueReceiver = _riskFreeValueReceiver;
            stakingFeeReceiver = _stakingFeeReceiver;
            emit SetFeeReceivers(_liquidityReceiver, _treasuryReceiver, _riskFreeValueReceiver, _stakingFeeReceiver);
        }

        function setTransferFee(uint256 _transferFee) external onlyOwner {
            require(_transferFee <= maxFee, "Fee can't be that high");
            transferFee = _transferFee;
            emit SetTransferFee(_transferFee);
        }

        function setMinReferralAmountActivated(bool _bool) external onlyOwner {
            minReferralActive = _bool;
            emit MinReferralAmountActive(_bool);
        }

        function clearStuckBalance(address _receiver) external onlyOwner {
            require(_receiver != address(0),"Zero Address Validation");
            payable(_receiver).transfer(address(this).balance);
        }

        function rescueToken(address tokenAddress, uint256 tokens) external onlyOwner returns (bool success){
            return ERC20Detailed(tokenAddress).transfer(msg.sender, tokens);
        }

        function setRebaseFrequency(uint256 _rebaseFrequency) external onlyOwner {
            require(_rebaseFrequency <= MAX_REBASE_FREQUENCY, "Too high");
            rebaseFrequency = _rebaseFrequency;
            emit SetRebaseFrequency(_rebaseFrequency);
        }

        function setRewardYield(uint256 _rewardYield, uint256 _rewardYieldDenominator) external onlyOwner {
            rewardYield = _rewardYield;
            rewardYieldDenominator = _rewardYieldDenominator;
            emit ChangeRewardYield(_rewardYield, _rewardYieldDenominator);
        }

        function setBuyFees(uint256 _liquidityFee, uint256 _treasuryFee, uint256 _buyFeeRFV, uint256 _referralFee, uint256 _stakingFee) external onlyOwner {
            require(_liquidityFee.add(_treasuryFee).add(_buyFeeRFV).add(_referralFee).add(_stakingFee) <= maxFee, "Fees can't be that high");
            liquidityFee = _liquidityFee;
            treasuryFee = _treasuryFee;
            buyFeeRFV = _buyFeeRFV;
            referralFee = _referralFee;
            stakingFee = _stakingFee;
            totalBuyFee = liquidityFee.add(treasuryFee).add(buyFeeRFV).add(referralFee).add(stakingFee);

            emit BuyFeesChanged(_liquidityFee, _treasuryFee, _buyFeeRFV, _referralFee, _stakingFee);

        }

        function setSellFees(uint256 _liquidityFee, uint256 _treasuryFee, uint256 _sellFeeRFV, uint256 _stakingFee) external onlyOwner {
            require(_liquidityFee.add(_treasuryFee).add(_sellFeeRFV).add(_stakingFee) <= maxFee, "Fees can't be that high");
            sellFeeLiquidity = _liquidityFee;
            sellFeeTreasury = _treasuryFee;
            sellFeeRFV = _sellFeeRFV;
            sellFeeStaking = _stakingFee;
            totalSellFee = sellFeeLiquidity.add(sellFeeTreasury).add(sellFeeRFV).add(sellFeeStaking);

            emit SellFeesChanged(_liquidityFee, _treasuryFee, _sellFeeRFV, _stakingFee);
        }

        function setIsLiquidityInBnb(bool _value) external onlyOwner {
            require(isLiquidityInBnb != _value, "Not changed");
            isLiquidityInBnb = _value;
            emit ChangeLiquidityInBNB(_value);
        }

        function setNextRebase(uint256 _nextRebase) external onlyOwner {
            nextRebase = _nextRebase;
            emit SetNextRebase(_nextRebase);
        }

        function setMaxSellTransaction(uint256 _maxTxn) external onlyOwner {
            require(_maxTxn > 0, "Can't be zero");
            maxSellTransactionAmount = _maxTxn;

            emit SetMaxSellAmount(_maxTxn);
        }

        function setReferralCA(address _address) external onlyOwner {
            referralCA = IReferralCA(_address);
        }

        function setMaxWalletExempt(address _address, bool _bool) external onlyOwner {
            isMaxWalletExempt[_address] = _bool;

            emit SetMaxWalletExempt(_address, _bool);
        }

        function setTimeF(uint256 _int) external onlyOwner {
            require(_int < 1536, "Time too long");
            timeF = _int;
            emit TimeFupdated(_int);
        }

        function setIsAllowedToRebase(address _address, bool _bool) external onlyOwner {
            isAllowedToRebase[_address] = _bool;
        }

        function setMaxWalletDenom(uint256 _maxWalletDenom) external onlyOwner {
            require(_maxWalletDenom > 0, "Can't be zero");
            maxWalletDenom = _maxWalletDenom;
            emit ChangedMaxWalletDenom(_maxWalletDenom);
        }

        function setMaxTotalSupply(uint256 _maxSupply) external onlyOwner {
            MAX_SUPPLY = _maxSupply;
            emit SetMaxSupply(_maxSupply);
        }


        function decreaseAllowance(address spender, uint256 subtractedValue) external returns (bool){
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

        function increaseAllowance(address spender, uint256 addedValue) external returns (bool){
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

        function approve(address spender, uint256 value) external override returns (bool){
            _allowedFragments[msg.sender][spender] = value;
            emit Approval(msg.sender, spender, value);
            return true;
        }


        function coreRebase(int256 supplyDelta) private returns (uint256) {
            uint256 epoch = block.timestamp;

            if (supplyDelta == 0) {
                emit LogRebase(epoch, _totalSupply);
                return _totalSupply;
            }

            if (supplyDelta < 0) {
                _totalSupply = _totalSupply.sub(uint256(-supplyDelta));
            } else {
                _totalSupply = _totalSupply.add(uint256(supplyDelta));
            }

            if (_totalSupply > MAX_SUPPLY) {
                _totalSupply = MAX_SUPPLY;
            }

            _gonsPerFragment = TOTAL_GONS.div(_totalSupply);

            nextRebase = epoch + rebaseFrequency;
            _maxWalletSize = getCirculatingSupply().div(maxWalletDenom);

            emit LogRebase(epoch, _totalSupply);
            return _totalSupply;
        }



    }