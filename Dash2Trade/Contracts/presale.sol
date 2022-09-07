// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Counters.sol";

contract D2TPresale is Ownable{

    using SafeMath for uint256;
    using Counters for Counters.Counter;

    IERC20 public D2TToken;
    IERC20 public USDTToken;
    IpD2T public p2DT;
    IUniswapV2Router02 public router;

    address private constant USDT_ADDRESS = 0xdAC17F958D2ee523a2206206994597C13D831ec7;
    //For test, USDT on rinkeby
    // address private constant USDT_ADDRESS = 0xD9BA894E0097f8cC2BBc9D24D308b98e36dc6D02;
    uint256 public constant PERCENT_PRECISION = 1000;

    uint256 public BNB20TokenPrice = 0.01 ether;
    uint256 public presalePeriod = 90 days;
    uint256 public immutable vestingEndTime;
    uint256 public totalSoldTokens;
    uint256 public presaleStartTime;
    uint256 public presaleEndTime;
    bool public isPresaleEnded = false;
    
    /**
    * @dev Variables for wallets where to be funded
    */
    struct FundWallet {
        address wallet;
        uint256 percent;
    }
    uint256 public fundIndex = 0;
    mapping(uint256 => FundWallet) public fundList;
    
    /**
    * @dev Variables for Vesting
    */
    uint256 public vestedPercent = 0;
    address public vestAdminAddress;
    Counters.Counter private _tokenIdCounter;

    mapping(uint256 => uint256) public tokenBalance;
    mapping(uint256 => uint256) public vestedTokenBalance;

    constructor(address _BNB20Token, address _router, address _p2DTNFTAddress, uint256 _duration) {
        D2TToken = IERC20(_BNB20Token);
        router = IUniswapV2Router02(_router);
        USDTToken = IERC20(USDT_ADDRESS);
        p2DT = IpD2T(_p2DTNFTAddress);

        presaleStartTime = block.timestamp;
        presaleEndTime = block.timestamp.add(presalePeriod);
        vestingEndTime = block.timestamp.add(_duration.mul(1 days));
    }

    function deposit(uint256 amount) public onlyOwner {
        D2TToken.transferFrom(msg.sender, address(this), amount);
    }

    function updatePresaleEndStatus(bool _status) public onlyOwner {
        isPresaleEnded = _status;
        presaleEndTime = block.timestamp;
    }

    function setFundList(
        address[] calldata addressList,
        uint256[] calldata percentList
    ) external onlyOwner {
        require(
            addressList.length == percentList.length,
            "Address length should be same percent list length"
        );
        uint256 all_percent = 0;
        for (uint256 i = 0; i < percentList.length; i++) {
            all_percent += percentList[i];
        }

        require(
            all_percent <= 100,
            "total fund percent should be less than 100%"
        );

        fundIndex = 0;
        for (uint256 i = 0; i < addressList.length; i++) {
            fundList[fundIndex] = FundWallet(addressList[i], percentList[i]);
            fundIndex++;
        }
    }

    function setPresalePeriod(uint256 _presalePeriod)
        public
        onlyOwner
    {
        presalePeriod = _presalePeriod.mul(1 days);
        presaleEndTime = presaleStartTime.add(presalePeriod);
    }
    
    function withdrawD2Token(uint256 amount) public onlyOwner{
        require(block.timestamp > presaleEndTime, "Presale is in progress");
        uint256 balance = D2TToken.balanceOf(address(this));
        require(balance.sub(amount) > totalSoldTokens, "Can't withdraw that much");
        D2TToken.transfer(msg.sender, amount);
    }

    function confirm(uint256 _tokenId) public {
        require(block.timestamp > presaleEndTime, "Presale is in progress");

        address sender = getOwnerOfNFT(_tokenId);
        require(sender == msg.sender, "Caller is not owner of the NFT");

        uint256 availableTokenAmount = getAvailableTokenAmountForVesting(_tokenId);
        
        if(availableTokenAmount == 0)   return;

        D2TToken.transfer(sender, availableTokenAmount);
        vestedTokenBalance[_tokenId] += availableTokenAmount;
    }

    function getAvailableTokenAmountForVesting(uint256 _tokenId) view public returns(uint256) {
        if(block.timestamp > vestingEndTime || vestedPercent > PERCENT_PRECISION) return tokenBalance[_tokenId]; //All tokens are available after the vesting hard-stop
        else return tokenBalance[_tokenId].mul(vestedPercent).div(PERCENT_PRECISION).sub(vestedTokenBalance[_tokenId]);
    }

    function setPrice(uint256 _setPrice) public onlyOwner {
        BNB20TokenPrice = _setPrice;
    }

    function buyD2TTokenWithBNB(uint256 tokenCount) public payable {
        require(!isPresaleEnded, "Presale is ended");
        require(block.timestamp <= presaleEndTime, "Presale is ended");
        require(
            msg.value >= BNB20TokenPrice.mul(tokenCount),
            "Insufficient amount."
        );
        require(
            totalSoldTokens + tokenCount.mul(10**D2TToken.decimals()) <=
                D2TToken.balanceOf(address(this)),
            "Insufficient token amount."
        );

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();

        mintNFT(msg.sender, tokenId);
        tokenBalance[tokenId] = tokenCount.mul(10**D2TToken.decimals());
        totalSoldTokens += tokenCount.mul(10**D2TToken.decimals());
    }

    function buyD2TTokenWithUSDT(uint256 tokenCount) public {
        require(!isPresaleEnded, "Presale is ended");
        require(block.timestamp <= presaleEndTime, "Presale is ended");
        require(
            totalSoldTokens + tokenCount.mul(10**D2TToken.decimals()) <=
                D2TToken.balanceOf(address(this)),
            "Insufficient token amount."
        );

        uint256 USDTAmount = getUSDTAmount(tokenCount);
        //Should allow before buy with USDT
        USDTToken.transferFrom(msg.sender, address(this), USDTAmount);

        uint256 tokenId = _tokenIdCounter.current();
        _tokenIdCounter.increment();
        mintNFT(msg.sender, tokenId);
        tokenBalance[tokenId] = tokenCount.mul(10**D2TToken.decimals());
        totalSoldTokens += tokenCount.mul(10**D2TToken.decimals());
    }

    function getUSDTAmount(uint256 _tokenAmount)  view internal returns(uint256){
        uint256 _BNBAmount = BNB20TokenPrice.mul(_tokenAmount);

        address[] memory path = new address[](2);
        path[0] = USDT_ADDRESS;
        path[1] = router.WETH();

        uint256[] memory result;
        result  =  router.getAmountsIn(_BNBAmount, path);

        return result[0];
    } 

    function availableTokenForPresale() public view returns (uint256) {
        return D2TToken.balanceOf(address(this));
    }

    function balanceOf() public view returns (uint256[2] memory) {
        return [address(this).balance, USDTToken.balanceOf(address(this))];
    }

    function withdrawUSDT() public onlyOwner {
        //onlyOwner
        require(fundIndex >= 1, "Fund Wallet should be set");
        swapBNBforUSDT();

        uint256 totalBalance = USDTToken.balanceOf(address(this));
        for (uint256 i = 0; i < fundIndex; i++) {
            FundWallet memory fundWallet = fundList[i];
            USDTToken.transfer(fundWallet.wallet, totalBalance.mul(fundWallet.percent).div(100));
        }
    }

    function getOwnerOfNFT(uint256 tokenId) view internal returns(address){
        return p2DT.ownerOf(tokenId);
    }

    function mintNFT(address _address, uint256 tokenId) internal {
        p2DT.safeMint(_address, tokenId);
    }

    function setVestedAdminAddress(address _addr) external onlyOwner {
        vestAdminAddress = _addr;
    }

    function setVestedPercent(uint _percent) external {
        require(vestAdminAddress == msg.sender, "Only Admin can set");
        require(_percent > 0 && _percent <= PERCENT_PRECISION, "Invalid percent");
        require(_percent >= vestedPercent, "Should bigger than current vested percent");
        
        vestedPercent = _percent;
    }

    function swapBNBforUSDT() private {

        uint256 BNBBalance = address(this).balance;
        if (BNBBalance == 0) return;

        address[] memory path = new address[](2);
        path[0] = router.WETH();
        path[1] = USDT_ADDRESS;

        router.swapExactETHForTokensSupportingFeeOnTransferTokens{value: BNBBalance}(
            0, // accept any amount of USDT
            path,
            address(this),
            block.timestamp
        );
    }
}

interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the token decimals.
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Returns the token symbol.
     */
    function symbol() external view returns (string memory);

    /**
     * @dev Returns the token name.
     */
    function name() external view returns (string memory);

    /**
     * @dev Returns the bep token owner.
     */
    function getOwner() external view returns (address);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address _owner, address spender)
        external
        view
        returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

interface IpD2T {
    function safeMint(address _to, uint tokenId) external;
    function ownerOf(uint256 tokenId) external view returns (address owner);
}

interface IUniswapV2Router01 {
    function factory() external pure returns (address);
    function WETH() external pure returns (address);

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
}

interface IUniswapV2Router02 is IUniswapV2Router01 {
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
