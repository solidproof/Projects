
// SPDX-License-Identifier: MIT

pragma solidity 0.7.6;

library SafeMathInt {
    int256 private constant MIN_INT256 = int256(1) << 255;

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

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function decimals() external view returns (uint8) {
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

    function owner() external view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(msg.sender == _owner, "Not owner");
        _;
    }

    function renounceOwnership() external onlyOwner {
        emit OwnershipRenounced(_owner);
        _owner = address(0);
    }

    function transferOwnership(address newOwner) external virtual onlyOwner {
     require(newOwner != address(0), "Ownable: new owner is the zero address");
     emit OwnershipTransferred(_owner, newOwner);
     _owner = newOwner;
    }
}


contract EarnyTV is ERC20Detailed, Ownable {

    using SafeMath for uint256;
    using SafeMathInt for int256;

    bool public liquifyAll = false;
    bool public autoRebase = false;

    uint256 private constant DECIMALS = 18;
    uint256 private constant MAX_UINT256 = ~uint256(0);
    uint256 private constant INITIAL_FRAGMENTS_SUPPLY = 5000000 * (10**DECIMALS);
    uint256 private constant TOTAL_GONS = MAX_UINT256 - (MAX_UINT256 % INITIAL_FRAGMENTS_SUPPLY);
    uint256 private constant MAX_SUPPLY = 1000000000 * (10**DECIMALS);
    uint256 private constant MAX_REBASE_FREQUENCY = 21600;

    uint256 public nextRebase = 1662854400;  //September 11th, 00:00 (GMT)  
    uint256 public earnyRebaseDenominator = 1000000;
    uint256 public earnyRebase = 20000; 
    uint256 public maxSellTransactionAmount = 50000 * 10 ** 18;  
    uint256 public rebaseFrequency = 21600; // every 6 hours 
    address public earnyteamReceiver = 0x461dEbda4af8749e31B730A84D8daB9B925f1212;
    address public earnytreasuryreservesReceiver = 0xc86Ac1c74Ee71c8c6A1be78dddA36624fb233Bdc;
    address public earnyliquidityReceiver = 0xa7673C4897AF11C14746BBD133D5AA679F31aA6D;
    address public earnybuybackReceiver = 0x6A41296203F1d462C390b8DafF8235464d970417;

    address public constant BUSD_TOKEN = 0xe9e7CEA3DedcA5984780Bafc599bD69ADd087D56;
    address public constant DEAD_WALLET_ADDRESS = 0x000000000000000000000000000000000000dEaD;
    address public constant ZERO_WALLET_ADDRESS = 0x0000000000000000000000000000000000000000;
    uint256 public constant MAX_FEE_RATE = 25;
    uint256 public constant FEE_DENOMINATOR = 100; 

    uint256 public buyliquidityFee = 0;
    uint256 public buyteamFee = 0;
    uint256 public buytreasuryFee = 1;
    uint256 public buybuybackfee = 0;
    uint256 public sellliquidityFee = 1;
    uint256 public sellteamFee = 0; 
    uint256 public selltreasuryFee = 1; 
    uint256 public sellbuybackfee = 0; 
    uint256 public totalBuyFee = buyliquidityFee.add(buyteamFee).add(buytreasuryFee).add(buybuybackfee);
    uint256 public totalSellFee = sellliquidityFee.add(sellteamFee).add(selltreasuryFee).add(sellbuybackfee);
    uint256 public referee = 0; 
    uint256 public referrer = 1;
    uint256 public totalReferralFee = referee.add(referrer);
    uint256 public iTotalUplines = 0;

    mapping(address => bool) isFeeExempt;
    mapping(address => address) public downlineLookupUpline;
	mapping(address => address[]) public downLines;
    mapping(address => uint256) public referralTotalFeeReceived;
    mapping(address => uint256) public referralCount;
    mapping(uint256 => address) public uplineList;

    function approveReferral(address uplineAddress) external {
        require(downlineLookupUpline[msg.sender] == address(0), "You have already been referred");
        require(msg.sender != uplineAddress, "You cannot refer yourself");
        downlineLookupUpline[msg.sender] = uplineAddress;
		downLines[uplineAddress].push(msg.sender);
        
        if(referralCount[uplineAddress] == 0)
        {
            uplineList[iTotalUplines] = uplineAddress;
            iTotalUplines += 1;
        }

        referralCount[uplineAddress] += 1;
    }

    function getTotalUpline() external view returns (uint256) {
        return iTotalUplines;
    }

    function getUplineAddressByIndex(uint256 iIndex) external view returns (address){
        return uplineList[iIndex];
    } 

    function addMember(address uplineAddress, address downlineAddress) external onlyOwner{
        downlineLookupUpline[downlineAddress] = uplineAddress;
    }
    
    function getUpline(address sender) public view returns (address){
        return downlineLookupUpline[sender];
    }

    function getdownLines(address sender) external view returns (address  [] memory){
        return downLines[sender];
    }
	
    function addReferralFee(address receiver, uint256 amount) private {
        referralTotalFeeReceived[receiver] += amount;
    }

    function getReferralTotalFee(address receiver) external view returns (uint256){
        return referralTotalFeeReceived[receiver];
    }
 
    bool public isLiquidityInBnb = true;
    address[] public markerPairs;
    mapping (address => bool) public automatedMarketMakerPairs;
    uint256 targetLiquidity = 50;
    uint256 targetLiquidityDenominator = 100;
    IDEXRouter public router;
    address public pair;
    bool inSwap; 

    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }

    struct User {
        uint256 firstBuy;
        uint256 lastTradeTime;
        uint256 tradeAmount;
    } 

    mapping(address => User) public tradeData;
    
    modifier validRecipient(address to) {
        require(to != address(0x0));
        _;
    }



    uint256 private _totalSupply;
    uint256 private _gonsPerFragment;
    uint256 private constant GON_SWAP_THRESHOLD = TOTAL_GONS / 10000;

    mapping(address => uint256) private _gonBalances;
    mapping(address => mapping(address => uint256)) private _allowedFragments;

    constructor() ERC20Detailed("EarnyTV", "$EARNY", uint8(DECIMALS)) {
        router = IDEXRouter(0x10ED43C718714eb63d5aA57B78B54704E256024E);
        pair = IDEXFactory(router.factory()).createPair(address(this), router.WETH());
        address pairBusd = IDEXFactory(router.factory()).createPair(address(this), BUSD_TOKEN);

        _allowedFragments[address(this)][address(router)] = uint256(-1);
        _allowedFragments[address(this)][pair] = uint256(-1);
        _allowedFragments[address(this)][address(this)] = uint256(-1);
        _allowedFragments[address(this)][pairBusd] = uint256(-1);

        setAutomatedMarketMakerPair(pair, true);
        setAutomatedMarketMakerPair(pairBusd, true);

        _totalSupply = INITIAL_FRAGMENTS_SUPPLY;
        _gonBalances[msg.sender] = TOTAL_GONS;
        _gonsPerFragment = TOTAL_GONS.div(_totalSupply);

        isFeeExempt[earnyteamReceiver] = true;
        isFeeExempt[earnytreasuryreservesReceiver] = true;
        isFeeExempt[address(this)] = true;
        isFeeExempt[msg.sender] = true;

        IERC20(BUSD_TOKEN).approve(address(router), uint256(-1));
        IERC20(BUSD_TOKEN).approve(address(pairBusd), uint256(-1));
        IERC20(BUSD_TOKEN).approve(address(this), uint256(-1));

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

    function checkFeeExempt(address exemptAddress) external view returns (bool) {
        return isFeeExempt[exemptAddress];
    }

    function shouldRebase() internal view returns (bool) {
        return nextRebase <= block.timestamp;
    }

    function checkSwapThreshold() external view returns (uint256) {
        return GON_SWAP_THRESHOLD.div(_gonsPerFragment);
    }

    function shouldSwapBack() internal view returns (bool) {
        return
        !automatedMarketMakerPairs[msg.sender] &&
        !inSwap && 
        totalBuyFee.add(totalSellFee) > 0 &&
        _gonBalances[address(this)] >= GON_SWAP_THRESHOLD;
    }

    function shouldTakeFee(address from, address to) internal view returns (bool) {
        if(isFeeExempt[from] || isFeeExempt[to]){
            return false; 
        }else{
            return (automatedMarketMakerPairs[from] || automatedMarketMakerPairs[to]);
        }
    }

    function getCirculatingSupply() public view returns (uint256) {
        return (TOTAL_GONS.sub(_gonBalances[DEAD_WALLET_ADDRESS]).sub(_gonBalances[ZERO_WALLET_ADDRESS])).div(_gonsPerFragment);
    }

    function getLiquidityBacking(uint256 accuracy) public view returns (uint256){
        uint256 liquidityBalance = 0;
        for(uint i = 0; i < markerPairs.length; i++){
            liquidityBalance.add(balanceOf(markerPairs[i]).div(10 ** 9));
        }
        return accuracy.mul(liquidityBalance.mul(2)).div(getCirculatingSupply().div(10 ** 9));
    }

    function isOverLiquified(uint256 target, uint256 accuracy) public view returns (bool){
        return getLiquidityBacking(accuracy) > target;
    }

    function manualSync() public {
        for(uint i = 0; i < markerPairs.length; i++){
            InterfaceLP(markerPairs[i]).sync();
        }
    }

    function transfer(address to, uint256 value) external override validRecipient(to) returns (bool){
        _transferFrom(msg.sender, to, value);
        return true;
    }

    function _basicTransfer(address from, address to, uint256 amount) internal returns (bool) {
        uint256 gonAmount = amount.mul(_gonsPerFragment);
        _gonBalances[from] = _gonBalances[from].sub(gonAmount);
        _gonBalances[to] = _gonBalances[to].add(gonAmount);

        emit Transfer(from, to, amount);

        return true;
    }

    function _transferFrom(address sender, address recipient, uint256 amount) internal returns (bool) {
        bool excludedAccount = isFeeExempt[sender] || isFeeExempt[recipient];
        if (
            automatedMarketMakerPairs[recipient] &&
            !excludedAccount
        ) {
            require(amount <= maxSellTransactionAmount, "Error: amount must be above max sell amount");
        }

        if (inSwap) {
            return _basicTransfer(sender, recipient, amount);
        }

        uint256 gonAmount = amount.mul(_gonsPerFragment);

        if (shouldSwapBack()) {
            swapBack();
        }

        _gonBalances[sender] = _gonBalances[sender].sub(gonAmount);

        uint256 gonAmountReceived = shouldTakeFee(sender, recipient) ? takeFee(sender, recipient, gonAmount) : gonAmount;
        _gonBalances[recipient] = _gonBalances[recipient].add(gonAmountReceived);

        emit Transfer(
            sender,
            recipient,
            gonAmountReceived.div(_gonsPerFragment)
        );

        
        if (automatedMarketMakerPairs[recipient]) {    
        if(shouldRebase() && autoRebase) {
            _rebase();

            if(!automatedMarketMakerPairs[sender] && !automatedMarketMakerPairs[recipient]){
                manualSync();
            }
        }
        }

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

    function _swapAndLiquify(uint256 contractTokenBalance) private {
        uint256 half = contractTokenBalance.div(2);
        uint256 otherHalf = contractTokenBalance.sub(half);

        if(isLiquidityInBnb){
            uint256 initialBalance = address(this).balance;

            _swapTokensForBNB(half, address(this));

            uint256 newBalance = address(this).balance.sub(initialBalance);

            _addLiquidity(otherHalf, newBalance);

            emit SwapAndLiquify(half, newBalance, otherHalf);
        }else{
            uint256 initialBalance = IERC20(BUSD_TOKEN).balanceOf(address(this));

            _swapTokensForBusd(half, address(this));

            uint256 newBalance = IERC20(BUSD_TOKEN).balanceOf(address(this)).sub(initialBalance);

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
            earnyliquidityReceiver,
            block.timestamp
        );
    }

    function _addLiquidityBusd(uint256 tokenAmount, uint256 busdAmount) private {
        router.addLiquidity(
            address(this),
            BUSD_TOKEN,
            tokenAmount,
            busdAmount,
            0,
            0,
            earnyliquidityReceiver,
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
        path[2] = BUSD_TOKEN;

        router.swapExactTokensForTokensSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            receiver,
            block.timestamp
        );
    }

    function swapBack() internal swapping {
        uint256 realTotalFee = totalBuyFee.add(totalSellFee);
        uint256 dynamicLiquidityFee = isOverLiquified(targetLiquidity, targetLiquidityDenominator) ? 0 : buyliquidityFee;

        uint256 amountToLiquify = _gonBalances[address(this)].mul(dynamicLiquidityFee.mul(2)).div(realTotalFee).div(_gonsPerFragment);
        uint256 amountToTeaM = _gonBalances[address(this)].mul(buyteamFee.add(sellteamFee)).div(realTotalFee).div(_gonsPerFragment);
        uint256 amountToBuyback = _gonBalances[address(this)].mul(buybuybackfee.add(sellbuybackfee)).div(realTotalFee).div(_gonsPerFragment);
        uint256 amountToTreasury = _gonBalances[address(this)].sub(amountToLiquify).sub(amountToTeaM).sub(amountToBuyback).div(_gonsPerFragment);
        uint256 contractTokenBalance = _gonBalances[address(this)].div(_gonsPerFragment);

        if(!liquifyAll && contractTokenBalance > GON_SWAP_THRESHOLD.div(_gonsPerFragment)){
        	contractTokenBalance = GON_SWAP_THRESHOLD.div(_gonsPerFragment);
        }
    
        if(amountToLiquify > 0){
            _swapAndLiquify(amountToLiquify);
        }

        if(amountToTeaM > 0){
            _swapTokensForBusd(amountToTeaM, earnytreasuryreservesReceiver);
        }

        if(amountToTreasury > 0){
            _swapTokensForBNB(amountToTreasury, earnyteamReceiver);
        }

         if(amountToBuyback > 0){
            _swapTokensForBNB(amountToBuyback, earnybuybackReceiver);
        }

        emit SwapBack(contractTokenBalance, amountToLiquify, amountToTeaM, amountToTreasury, amountToBuyback);
    }

    function takeFee(address sender, address recipient, uint256 gonAmount) internal returns (uint256){
        uint256 setrealFee = totalBuyFee;

        if(automatedMarketMakerPairs[recipient]) setrealFee = totalSellFee;

        uint256 feeAmount = gonAmount.mul(setrealFee).div(FEE_DENOMINATOR);
 
        if (automatedMarketMakerPairs[sender]) {
            address UplineAddressBuyer = getUpline(recipient);
            if (UplineAddressBuyer != address(0))
            {
                uint256 _uplineBuyerReward = gonAmount.mul(referrer).div(FEE_DENOMINATOR);
                feeAmount = gonAmount.mul(setrealFee - referee).div(FEE_DENOMINATOR);
                _gonBalances[UplineAddressBuyer] = _gonBalances[UplineAddressBuyer].add(
                _uplineBuyerReward
                );
                addReferralFee(UplineAddressBuyer, _uplineBuyerReward.div(_gonsPerFragment) );  
            }      
        }
        else if (automatedMarketMakerPairs[recipient]) {
            address UplineAddress = getUpline(sender);

            if (UplineAddress != address(0))
            {
                uint256 _uplineReward = gonAmount.mul(referrer).div(FEE_DENOMINATOR);
                feeAmount = gonAmount.mul(setrealFee - referee).div(FEE_DENOMINATOR);
                _gonBalances[UplineAddress] = _gonBalances[UplineAddress].add(
                    _uplineReward
                );
                addReferralFee(UplineAddress, _uplineReward.div(_gonsPerFragment) );
            }    
        }

        _gonBalances[address(this)] = _gonBalances[address(this)].add(feeAmount);
        emit Transfer(sender, address(this), feeAmount.div(_gonsPerFragment));

        return gonAmount.sub(feeAmount);
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

    function _rebase() private {
        if(!inSwap) {
            uint256 circulatingSupply = getCirculatingSupply();
            int256 supplyDelta = int256(circulatingSupply.mul(earnyRebase).div(earnyRebaseDenominator));
            coreRebase(supplyDelta);
        }
    }

    function coreRebase(int256 supplyDelta) private returns (uint256) {
        uint256 epoch = block.timestamp;
        if (supplyDelta == 0) {
            emit LogRebase(epoch, _totalSupply);
            return _totalSupply;
        } else {
            if ((_totalSupply.add(uint256(supplyDelta))) >= MAX_SUPPLY) { 
            autoRebase = false;
            emit LogRebase(epoch, _totalSupply);
            return _totalSupply;
        } else {
            _totalSupply = _totalSupply.add(uint256(supplyDelta));
         }
        }
        _gonsPerFragment = TOTAL_GONS.div(_totalSupply);
        nextRebase = epoch + rebaseFrequency;
        emit LogRebase(epoch, _totalSupply);
        return _totalSupply;
    }

    function manualRebase() external onlyOwner{
        require(!inSwap, "Try again");
        require(nextRebase <= block.timestamp, "Not in time");

        uint256 circulatingSupply = getCirculatingSupply();
        int256 supplyDelta = int256(circulatingSupply.mul(earnyRebase).div(earnyRebaseDenominator));

        coreRebase(supplyDelta);
        manualSync();
    }

    function setAutomatedMarketMakerPair(address enterPair, bool enterValue) public onlyOwner {
        require(automatedMarketMakerPairs[enterPair] != enterValue, "Value already set");

        automatedMarketMakerPairs[enterPair] = enterValue;

        if(enterValue){
            markerPairs.push(enterPair);
        }else{
            require(markerPairs.length > 1, "Required 1 pair");
            for (uint256 i = 0; i < markerPairs.length; i++) {
                if (markerPairs[i] == enterPair) {
                    markerPairs[i] = markerPairs[markerPairs.length - 1];
                    markerPairs.pop();
                    break;
                }
            }
        }

        emit SetAutomatedMarketMakerPair(enterPair, enterValue);
    }
 
    function setFeeExempt(address exemptAddress, bool enterValue) external onlyOwner {
        require(isFeeExempt[exemptAddress] != enterValue, "Not changed");
        isFeeExempt[exemptAddress] = enterValue;
    } 

    function setTargetLiquidity(uint256 target, uint256 accuracy) external onlyOwner {
        targetLiquidity = target;
        targetLiquidityDenominator = accuracy;
        emit SetTargetLiquidity(targetLiquidity, targetLiquidityDenominator);
    }
 

    function setSwapBackSettings(bool isEnabled) external onlyOwner {
        liquifyAll = isEnabled;
    }

 
    function setFeeReceivers(address setearnyliquidityReceiver, address setearnyteamReceiver, address setearnytreasuryreservesReceiver, address setearnybuybackReceiver) external onlyOwner {
        earnyliquidityReceiver = setearnyliquidityReceiver;
        earnyteamReceiver = setearnyteamReceiver;
        earnytreasuryreservesReceiver = setearnytreasuryreservesReceiver;
        earnybuybackReceiver = setearnybuybackReceiver;
    }
 
    function setReferralSettings(uint256 setReferee, uint256 setReferrer) external onlyOwner {
        require(setReferee.add(setReferrer) <= buytreasuryFee, "Error: The total referral fee must be lower or equal to the treasury fee"); 
        require(setReferee.add(setReferrer) <= selltreasuryFee, "Error: The total referral fee must be lower or equal to the treasury fee"); 
        referee = setReferee;
        referrer = setReferrer;
        totalReferralFee = referee.add(referrer);
        emit SetReferralSettings(referee, referrer, totalReferralFee);
    }

 
    function setBuyFees(uint256 setbuyliquidityFee, uint256 setbuyteamFee, uint256 setbuytreasuryFee, uint256 setbuybuybackFee) external onlyOwner {
        require(setbuytreasuryFee >= totalReferralFee);
        buyliquidityFee = setbuyliquidityFee;
        buyteamFee = setbuyteamFee;
        buytreasuryFee = setbuytreasuryFee;
        buybuybackfee = setbuybuybackFee;
        totalBuyFee = buyliquidityFee.add(buytreasuryFee).add(buyteamFee).add(buybuybackfee);
        require(totalBuyFee <= FEE_DENOMINATOR / 4);
        emit SetBuyFees(buyliquidityFee, buyteamFee, buytreasuryFee, buybuybackfee, totalBuyFee);
    }

 
     function setSellFees(uint256 setsellliquidityFee, uint256 setsellteamFee, uint256 setselltreasuryFee, uint256 setsellbuybackFee) external onlyOwner {
        require(setselltreasuryFee >= totalReferralFee);
        sellbuybackfee = setsellbuybackFee;
        sellliquidityFee = setsellliquidityFee;
        sellteamFee = setsellteamFee;
        selltreasuryFee = setselltreasuryFee;
        totalSellFee = sellliquidityFee.add(sellteamFee).add(selltreasuryFee).add(sellbuybackfee);
        require(totalSellFee <= FEE_DENOMINATOR / 4);
        emit SetSellFees(sellbuybackfee, sellliquidityFee, sellteamFee, selltreasuryFee, totalSellFee);
    }

 
    function rescueToken(address tokenAddress, uint256 tokens) external onlyOwner returns (bool success){
        require (tokenAddress != address(this));
		if(tokens == 0){
            tokens = ERC20Detailed(tokenAddress).balanceOf(address(this));
        }
        return ERC20Detailed(tokenAddress).transfer(msg.sender, tokens);
    }

    function setNextRebase(uint256 epochRebase) external onlyOwner {
        nextRebase = epochRebase;
         emit SetNextRebase(nextRebase);
    }

    function setMaxSellTransaction(uint256 maxTxn) external onlyOwner {
        require(maxTxn >= (5000 * (10 ** 18)), "The max sell amount should be above 0.1% of initial supply");
        maxSellTransactionAmount = maxTxn;
        emit SetMaxSellTransaction(maxSellTransactionAmount);
    }
    
    function setAutoRebase(bool onoffRebase) external onlyOwner {
        require(autoRebase != onoffRebase, "ERROR: Not changed");
        autoRebase = onoffRebase;
    }

    function setRebaseFrequency(uint256 enterFrequency) external onlyOwner {
        require(enterFrequency <= MAX_REBASE_FREQUENCY, "ERROR: Rebase frequancy too high");
        rebaseFrequency = enterFrequency;
        
         emit SetRebaseFrequency(rebaseFrequency);
    }

    function setEarnyRebase(uint256 enterRebase, uint256 rebaseDenominator) external onlyOwner {
        require(rebaseDenominator >= 1, "ERROR: Rebase Denominator can't be set to 0");
        earnyRebase = enterRebase;
        earnyRebaseDenominator = rebaseDenominator;
         emit SetEarnyRebase(earnyRebase, earnyRebaseDenominator);
    }
 

    function setIsLiquidityInBnb(bool enterValue) external onlyOwner {
        require(isLiquidityInBnb != enterValue, "ERROR: Not changed");
        isLiquidityInBnb = enterValue;
    }

    event SetBuyFees(uint256 buyliquidityFee, uint256 buyteamFee, uint256 buytreasuryFee, uint256 buybuybackfee, uint256 totalBuyFee);
    event SetSellFees(uint256 sellbuybackfee, uint256 sellliquidityFee, uint256 sellteamFee, uint256 selltreasuryFee, uint256 totalSellFee);
    event SetRebaseFrequency(uint256 rebaseFrequency);
    event SetTargetLiquidity(uint256 targetLiquidity, uint256 targetLiquidityDenominator);
    event SetReferralSettings(uint256 referee, uint256 referrer, uint256 totalReferralFee);
    event SetEarnyRebase(uint256 earnyRebase, uint256 earnyRebaseDenominator);
    event SetNextRebase(uint256 nextRebase);
    event SetMaxSellTransaction(uint256 maxSellTransactionAmount);
    event SwapBack(uint256 contractTokenBalance,uint256 amountToLiquify,uint256 amountToTeaM,uint256 amountToTreasury,uint256 amountToBuyback);
    event SwapAndLiquify(uint256 tokensSwapped, uint256 bnbReceived, uint256 tokensIntoLiqudity);
    event SwapAndLiquifyBusd(uint256 tokensSwapped, uint256 busdReceived, uint256 tokensIntoLiqudity);
    event LogRebase(uint256 indexed epoch, uint256 totalSupply);
    event SetAutomatedMarketMakerPair(address indexed pair, bool indexed value);
}
