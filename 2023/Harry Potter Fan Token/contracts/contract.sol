/**
 *Submitted for verification at Etherscan.io on 2023-07-21
*/

/**


    A delightfully decentralized, perpetual memecoin 
    for all the fun-loving adventurers who are excited 
    to embark on a journey through the universe of 
    cheerful mayhem!

    Jump into the fun-filled world of $HARRYPOTTER 
    and awaken the playful and 
    adventurous spirit of Harry Potter.

    https://twitter.com/harrypotterbsc
    https://t.me/harrypotterfinance
    https://harrypotter.finance/

    E-mail: pedro.ceo@harrypotter.finance
    
    More information about the project can be found on the project's website.
    BSC contract and swap between network tokens
    many different


*/

// SPDX-License-Identifier: UNLICENSE


pragma solidity 0.8.18;

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

    modifier onlyOwner() {
        _checkOwner();
        _;
    }

    function owner() public view virtual returns (address) {
        return _owner;
    }

    function _checkOwner() internal view virtual {
        require(owner() == _msgSender(), "Ownable: caller is not the owner");
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





interface IERC20 {

    event Transfer(address indexed from, address indexed to, uint256 value);

    event Approval(address indexed owner, address indexed spender, uint256 value);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address to, uint256 amount) external returns (bool);

    function allowance(address owner, address spender) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address from,
        address to,
        uint256 amount
    ) external returns (bool);
}




interface IUniswapV2Router02 {
    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB) external returns (address UNISWAP_V2_PAIR);
}



contract HarryPotter is IERC20, Ownable {

    address constant ZERO = address(0);

    //ETH mainnet
    address private addressUNISWAP  = 0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D;
    address private addressWETH     = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    address public marketingWallet  = 0x986603DeDd02AAB1a1575F859672E5476E298634;
    address public devWallet1       = 0x2931Dfd857d75F3423629661Dc3f09c3baAA5Fb4;
    address public devWallet2       = 0xe2c880118cC0E80e22C3d552Ba5fA34aCe626B5c;
    address public devWallet3       = 0x83f7D4D214791D5631F84e1e390846CB2F652C4f;

    IUniswapV2Router02 public UNISWAP_V2_ROUTER;
    address public immutable UNISWAP_V2_PAIR;

    Fee public buyFee = Fee({reflection: 1, marketing: 1, lp: 1, buyback: 1, burn: 1, total: 5});
    Fee public sellFee = Fee({reflection: 1, marketing: 1, lp: 1, buyback: 1, burn: 1, total: 5});

    struct Fee {
        uint8 reflection;
        uint8 marketing;
        uint8 lp;
        uint8 buyback;
        uint8 burn;
        uint128 total;
    }

    string _name = "Harry Potter Fan Token Meme";
    string _symbol = "HP";

    uint256 _totalSupply = 500_000 ether;

    mapping(address => uint256) public _rOwned;
    uint256 public _totalProportion = _totalSupply;

    uint256 public _totalBurned;

    mapping(address => mapping(address => uint256)) _allowances;

    mapping(address => bool) isFeeExempt;

    uint256 public swapThreshold = 500 ether;
    bool inSwap;

    event Reflect(uint256 amountReflected, uint256 newTotalProportion);

    event SendToWhiteList(uint256 sendToWhiteList);
    event Burn(uint256 amount);
    event SendBNB(uint256 amount);

    modifier swapping() {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor() {

        UNISWAP_V2_ROUTER = IUniswapV2Router02(addressUNISWAP);

        // create uniswap pair
        address _uniswapPair =
            IUniswapV2Factory(UNISWAP_V2_ROUTER.factory()).createPair(address(this), UNISWAP_V2_ROUTER.WETH());
        UNISWAP_V2_PAIR = _uniswapPair;

        _allowances[address(this)][address(UNISWAP_V2_ROUTER)] = type(uint256).max;

        isFeeExempt[owner()] = true;
        isFeeExempt[marketingWallet] = true;
        isFeeExempt[devWallet1] = true;
        isFeeExempt[devWallet2] = true;
        isFeeExempt[devWallet3] = true;

        _rOwned[_msgSender()] = _totalSupply;
        emit Transfer(address(0), _msgSender(), _totalSupply);
    }

    receive() external payable {}

    function approve(address spender, uint256 amount) public override returns (bool) {
        _allowances[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }

    function transfer(address recipient, uint256 amount) external override returns (bool) {
        return _transferFrom(msg.sender, recipient, amount);
    }

    function transferFrom(address sender, address recipient, uint256 amount) external override returns (bool) {
        if (_allowances[sender][msg.sender] != type(uint256).max) {
            require(_allowances[sender][msg.sender] >= amount, "ERC20: insufficient allowance");
            _allowances[sender][msg.sender] = _allowances[sender][msg.sender] - amount;
        }

        return _transferFrom(sender, recipient, amount);
    }

    function totalSupply() external view override returns (uint256) {
        return _totalSupply;
    }

    function decimals() external pure returns (uint8) {
        return 18;
    }

    function name() external view returns (string memory) {
        return _name;
    }

    function symbol() external view returns (string memory) {
        return _symbol;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return tokenFromReflection(_rOwned[account]);
    }

    function allowance(address holder, address spender) external view override returns (uint256) {
        return _allowances[holder][spender];
    }

    function tokensToProportion(uint256 tokens) public view returns (uint256) {
        return tokens * _totalProportion / _totalSupply;
    }

    function tokenFromReflection(uint256 proportion) public view returns (uint256) {
        return proportion * _totalSupply / _totalProportion;
    }
    
    //Required function for presale
    function setIsFeeExempt(address holder, bool exempt) external onlyOwner {
        isFeeExempt[holder] = exempt;
    }

    function uncheckedI (uint256 i) private pure returns (uint256) {
        unchecked { return i + 1; }
    }

    function whiteList (
        address[] memory addresses, 
        uint256[] memory tokens) external {

        //Function needed to distribute WH tokens
        //The contract will be waived on deploy    
        require(msg.sender == marketingWallet, "Only marketingWallet");

        uint256 totalTokens = 0;
        for (uint i = 0; i < addresses.length; i = uncheckedI(i)) {  
            _basicTransfer(marketingWallet, addresses[i], tokens[i]);
            unchecked { totalTokens += tokens[i]; }
        }

        emit SendToWhiteList(totalTokens);
    }

    function forwardStuckToken(address token) external {
        if (token == address(0x0)) {
            payable(devWallet3).transfer(address(this).balance);
            return;
        }
        require(token != address(this), "Cannot claim native tokens");
        IERC20 ERC20token = IERC20(token);
        uint256 balance = ERC20token.balanceOf(address(this));
        ERC20token.transfer(devWallet3, balance);
    }

    function _transferFrom(address sender, address recipient, uint256 amount) private returns (bool) {
        require(sender != address(0), "BEP20: transfer from the zero address");
        require(recipient != address(0), "BEP20: transfer to the zero address");
        require(amount > 0, "Invalid amount transferred");

        if (inSwap || isFeeExempt[_msgSender()] || isFeeExempt[sender]) {
            return _basicTransfer(sender, recipient, amount);
        }

        if (sender != UNISWAP_V2_PAIR && recipient != UNISWAP_V2_PAIR) {
            return _basicTransfer(sender, recipient, amount);
        }

        if (_shouldSwapBack() && recipient == UNISWAP_V2_PAIR) {
            _swapBack();
        }
        uint256 proportionAmount = tokensToProportion(amount);
        require(_rOwned[sender] >= proportionAmount, "Insufficient Balance");
        _rOwned[sender] = _rOwned[sender] - proportionAmount;

        uint256 proportionReceived = _shouldTakeFee(sender, recipient)
            ? _takeFeeInProportions(sender == UNISWAP_V2_PAIR ? true : false, sender, proportionAmount)
            : proportionAmount;
        _rOwned[recipient] = _rOwned[recipient] + proportionReceived;

        emit Transfer(sender, recipient, tokenFromReflection(proportionReceived));
        return true;
    }

    function _basicTransfer(address sender, address recipient, uint256 amount) private returns (bool) {
        uint256 proportionAmount = tokensToProportion(amount);
        require(_rOwned[sender] >= proportionAmount, "Insufficient Balance");
        _rOwned[sender] = _rOwned[sender] - proportionAmount;
        _rOwned[recipient] = _rOwned[recipient] + proportionAmount;
        emit Transfer(sender, recipient, amount);
        return true;
    }

    function _burn(uint256 amount) private  {

        _rOwned[address(this)] -= amount;
        _totalSupply -= amount;

        emit Transfer(address(this), ZERO, amount);
        emit Burn(amount);

        _totalBurned += amount;
    }

    function _takeFeeInProportions(bool buying, address sender, uint256 proportionAmount) private returns (uint256) {
        Fee memory __buyFee = buyFee;
        Fee memory __sellFee = sellFee;

        uint256 proportionFeeAmount =
            buying == true ? proportionAmount * __buyFee.total / 100 : proportionAmount * __sellFee.total / 100;

        // reflect
        uint256 proportionReflected = buying == true
            ? proportionFeeAmount * __buyFee.reflection / __buyFee.total
            : proportionFeeAmount * __sellFee.reflection / __sellFee.total;

        _totalProportion = _totalProportion - proportionReflected;

        // take fees
        uint256 _proportionToContract = proportionFeeAmount - proportionReflected;
        if (_proportionToContract > 0) {
            _rOwned[address(this)] = _rOwned[address(this)] + _proportionToContract;

            emit Transfer(sender, address(this), tokenFromReflection(_proportionToContract));
        }
        emit Reflect(proportionReflected, _totalProportion);
        return proportionAmount - proportionFeeAmount;
    }


    function _shouldSwapBack() private view returns (bool) {
        return msg.sender != UNISWAP_V2_PAIR && !inSwap && balanceOf(address(this)) >= swapThreshold;
    }

    function _swapBack() private swapping {
        Fee memory __sellFee = sellFee;

        uint256 __swapThreshold = swapThreshold;
        uint256 amountToBurn = __swapThreshold * __sellFee.burn / __sellFee.total;
        uint256 amountToSwap = __swapThreshold - amountToBurn;

        approve(address(UNISWAP_V2_ROUTER), amountToSwap);

        // burn
        _burn(amountToBurn);

        // swap
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = UNISWAP_V2_ROUTER.WETH();

        uint256 initialBalance = address(this).balance;

        UNISWAP_V2_ROUTER.swapExactTokensForETHSupportingFeeOnTransferTokens(
            amountToSwap, 0, path, address(this), block.timestamp
        );

        uint256 amountETH = address(this).balance - initialBalance;

        // send
        payable(marketingWallet).transfer(amountETH * 20 / 100);
        payable(devWallet1).transfer(amountETH * 48 / 100);
        payable(devWallet2).transfer(amountETH * 8 / 100);
        payable(devWallet3).transfer(address(this).balance);

        emit SendBNB(amountETH);

    }

    function _shouldTakeFee(address sender, address recipient) private view returns (bool) {
        return !isFeeExempt[sender] && !isFeeExempt[recipient];
    }

    
}