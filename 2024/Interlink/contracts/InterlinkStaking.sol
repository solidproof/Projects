//SPDX-License-Identifier: MIT
pragma solidity 0.8.20;


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

interface IUniswapV2Factory {
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

/**
 * @title Owner
 * @dev Set & change owner
 */
contract Ownable {

    address private owner;
    
    // event for EVM logging
    event OwnerSet(address indexed oldOwner, address indexed newOwner);
    
    // modifier to check if caller is owner
    modifier onlyOwner() {
        // If the first argument of 'require' evaluates to 'false', execution terminates and all
        // changes to the state and to Ether balances are reverted.
        // This used to consume all gas in old EVM versions, but not anymore.
        // It is often a good idea to use 'require' to check if functions are called correctly.
        // As a second argument, you can also provide an explanation about what went wrong.
        require(msg.sender == owner, "Caller is not owner");
        _;
    }
    
    /**
     * @dev Set contract deployer as owner
     */
    constructor() {
        owner = msg.sender; // 'msg.sender' is sender of current call, contract deployer for a constructor
        emit OwnerSet(address(0), owner);
    }

    /**
     * @dev Change owner
     * @param newOwner address of new owner
     */
    function changeOwner(address newOwner) public onlyOwner {
        emit OwnerSet(owner, newOwner);
        owner = newOwner;
    }

    /**
     * @dev Return owner address 
     * @return address of owner
     */
    function getOwner() external view returns (address) {
        return owner;
    }
}

interface IERC20 {

    function totalSupply() external view returns (uint256);
    
    function symbol() external view returns(string memory);
    
    function name() external view returns(string memory);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);
    
    /**
     * @dev Returns the number of decimal places
     */
    function decimals() external view returns (uint8);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

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
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

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
    event Approval(address indexed owner, address indexed spender, uint256 value);
}

abstract contract ReentrancyGuard {
    uint256 internal constant _NOT_ENTERED = 1;
    uint256 internal constant _ENTERED = 2;
    uint256 internal _status;
    constructor () {
        _status = _NOT_ENTERED;
    }

    modifier nonReentrant() {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }
}

contract InterlinkStaking is Ownable, IERC20, ReentrancyGuard {

    // WETH address to designate rewards to native bnb
    address private constant WETH = 0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c;

    // name and symbol for tokenized contract
    string private constant _name = "Staked ILA";
    string private constant _symbol = "SILA";
    uint8 private constant _decimals = 18;

    // lock time in seconds
    uint256 public lockTime = 45 days;

    // fee for leaving staking early
    uint256 public leaveEarlyFee = 15;

    // recipient of fee
    address public feeRecipient;

    // Staking Token
    address public immutable token;

    // User Info
    struct UserInfo {
        uint256 amount;
        uint256 unlockTime;
        uint256 totalExcluded;
        uint256 rewardToken;
    }
    // Address => UserInfo
    mapping ( address => UserInfo ) public userInfo;

    // Reward Token Structure
    struct RewardToken {
        address token;
        address DEX;
        address[] path;
        bool active;
    }

    // Maps a reward token nonce to the reward token
    mapping ( uint256 => RewardToken ) public rewardTokens;

    // Reward Token Nonce
    uint256 public rewardTokenNonce;

    // Tracks Dividends
    uint256 public totalRewards;
    uint256 private totalShares;
    uint256 private dividendsPerShare;
    uint256 private constant precision = 10**18;

    // Events
    event SetLockTime(uint LockTime);
    event SetEarlyFee(uint earlyFee);
    event SetFeeRecipient(address FeeRecipient);

    constructor(address token_, address feeRecipient_){
        require(
            token_ != address(0) &&
            feeRecipient_ != address(0),
            'Zero Address'
        );

        // pair initial data
        token = token_;
        feeRecipient = feeRecipient_;

        // for setting up initial reward tokens
        address router = 0x10ED43C718714eb63d5aA57B78B54704E256024E;

        // add tokens
        _addRewardToken(
            token_, 
            router, 
            getStandardSwapPath(token_)
        );
        _addRewardToken(
            WETH, 
            address(0), 
            new address[](0)
        );
        _addRewardToken(
            0x0BcEFB75933b2bCE5f01515f6250B5c0d66cb7Fb, // rev
            router,
            getStandardSwapPath(0x0BcEFB75933b2bCE5f01515f6250B5c0d66cb7Fb)
        );
        _addRewardToken(
            0x323232382A94DC22642350c7dd4320B28E6E7564, // cryft
            router, 
            getStandardSwapPath(0x323232382A94DC22642350c7dd4320B28E6E7564)
        );
        _addRewardToken(
            0x61Efb60A075479D96Ad3D1C54dd87D71AfFF980f, // prevail
            router, 
            getStandardSwapPath(0x61Efb60A075479D96Ad3D1C54dd87D71AfFF980f)
        );
        _addRewardToken(
            0x988c49d4a1515EE341b3540EC70a1F7A167b3759, // dive wallet
            router, 
            getStandardSwapPath(0x988c49d4a1515EE341b3540EC70a1F7A167b3759)
        );
        _addRewardToken(
            0x136331f3bE5b0F32Fb21a7f19d1D4C47F0671494, // HAAGA
            router, 
            getStandardSwapPath(0x136331f3bE5b0F32Fb21a7f19d1D4C47F0671494)
        );
        _addRewardToken(
            0xa10E3590c4373C3Cc5d871776EF90ca1F1DD12D2, // Master Key Finance
            router, 
            getStandardSwapPath(0xa10E3590c4373C3Cc5d871776EF90ca1F1DD12D2)
        );

        emit Transfer(address(0), msg.sender, 0);
    }

    /** Returns the total number of tokens in existence */
    function totalSupply() external view override returns (uint256) { 
        return totalShares; 
    }

    /** Returns the number of tokens owned by `account` */
    function balanceOf(address account) public view override returns (uint256) { 
        return userInfo[account].amount;
    }

    /** Returns the number of tokens `spender` can transfer from `holder` */
    function allowance(address, address) external pure override returns (uint256) { 
        return 0; 
    }
    
    /** Token Name */
    function name() public pure override returns (string memory) {
        return _name;
    }

    /** Token Ticker Symbol */
    function symbol() public pure override returns (string memory) {
        return _symbol;
    }

    /** Tokens decimals */
    function decimals() public pure override returns (uint8) {
        return _decimals;
    }

    /** Approves `spender` to transfer `amount` tokens from caller */
    function approve(address spender, uint256) public override returns (bool) {
        emit Approval(msg.sender, spender, 0);
        return true;
    }
  
    /** Transfer Function */
    function transfer(address recipient, uint256) external override nonReentrant returns (bool) {
        _claimReward(msg.sender, 1);
        emit Transfer(msg.sender, recipient, 0);
        return true;
    }

    /** Transfer Function */
    function transferFrom(address, address recipient, uint256) external override nonReentrant returns (bool) {
        _claimReward(msg.sender, 1);
        emit Transfer(msg.sender, recipient, 0);
        return true;
    }

    function setLockTime(uint256 newLockTime) external onlyOwner {
        require(
            newLockTime <= 365 days,
            'Lock Time Too Long'
        );
        lockTime = newLockTime;
        emit SetLockTime(newLockTime);
    }

    function setLeaveEarlyFee(uint256 newEarlyFee) external onlyOwner {
        require(
            newEarlyFee <= 75,
            'Early Fee Too High'
        );
        leaveEarlyFee = newEarlyFee;
        emit SetEarlyFee(newEarlyFee);
    }

    function setFeeRecipient(address newFeeRecipient) external onlyOwner {
        require(
            newFeeRecipient != address(0),
            'Zero Address'
        );
        feeRecipient = newFeeRecipient;
        emit SetFeeRecipient(newFeeRecipient);
    }

    function withdrawForeignToken(address token_) external onlyOwner {
        require(
            token != token_,
            'Cannot Withdraw Staked Token'
        );
        require(
            IERC20(token_).transfer(
                msg.sender,
                IERC20(token_).balanceOf(address(this))
            ),
            'Failure On Token Withdraw'
        );
    }

    function addRewardToken(
        address _token,
        address DEX,
        address[] calldata path
    ) external onlyOwner {
        _addRewardToken(_token, DEX, path);
    }

    function editRewardToken(
        uint256 nonce,
        address _token,
        address DEX,
        address[] calldata path
    ) external onlyOwner {
        rewardTokens[nonce] = RewardToken(_token, DEX, path, true);
    }

    function deactivateRewardToken(
        uint256 nonce
    ) external onlyOwner {
        rewardTokens[nonce].active = false;
    }

    function reactivateRewardToken(
        uint256 nonce
    ) external onlyOwner {
        rewardTokens[nonce].active = true;
    }


    function setRewardToken(uint256 index) external nonReentrant {
        require(index < rewardTokenNonce, 'Invalid Reward Token');
        require(rewardTokens[index].active, 'Reward Token Not Active');
        userInfo[msg.sender].rewardToken = index;
    }

    function claimRewards(uint256 minOut) external nonReentrant {
        _claimReward(msg.sender, minOut);
    }

    function withdraw(uint256 amount) external nonReentrant {
        require(
            amount <= userInfo[msg.sender].amount,
            'Insufficient Amount'
        );
        require(
            amount > 0,
            'Zero Amount'
        );
        if (userInfo[msg.sender].amount > 0) {
            _claimReward(msg.sender, 1);
        }

        totalShares -= amount;
        userInfo[msg.sender].amount -= amount;
        userInfo[msg.sender].totalExcluded = getCumulativeDividends(userInfo[msg.sender].amount);

        uint fee = timeUntilUnlock(msg.sender) == 0 ? 0 : ( amount * leaveEarlyFee ) / 100;
        if (fee > 0) {
            require(
                IERC20(token).transfer(feeRecipient, fee),
                'Failure On Token Transfer'
            );
        }

        uint sendAmount = amount - fee;
        require(
            IERC20(token).transfer(msg.sender, sendAmount),
            'Failure On Token Transfer To Sender'
        );

        emit Transfer(msg.sender, address(0), amount);
    }

    function stake(uint256 amount) external nonReentrant {
        if (userInfo[msg.sender].amount > 0) {
            _claimReward(msg.sender, 1);
        }

        // transfer in tokens
        uint received = _transferIn(token, amount);
        
        // update data
        unchecked {
            totalShares += received;
            userInfo[msg.sender].amount += received;
            userInfo[msg.sender].unlockTime = block.timestamp + lockTime;
        }
        userInfo[msg.sender].totalExcluded = getCumulativeDividends(userInfo[msg.sender].amount);

        emit Transfer(address(0), msg.sender, received);
    }

    function depositRewards() external payable nonReentrant {
        if (totalShares == 0) {
            return;
        }
        // update state
        unchecked {
            dividendsPerShare += ( msg.value * precision ) / totalShares;
            totalRewards += msg.value;
        }
    }




    function _claimReward(address user, uint256 minOut) internal {

        // exit if zero value locked
        if (userInfo[user].amount == 0) {
            return;
        }

        // fetch pending rewards
        uint256 amount = pendingRewards(user);
        
        // exit if zero rewards
        if (amount == 0) {
            return;
        }

        // update total excluded
        userInfo[user].totalExcluded = getCumulativeDividends(userInfo[user].amount);

        // get index of reward token
        uint256 rTokenIndex = userInfo[user].rewardToken;

        // ensure reward token is active
        require(rewardTokens[rTokenIndex].active, 'Reward Token Not Active');

        // buy reward token for user, unless reward token is WETH
        if (rewardTokens[rTokenIndex].token == WETH) {
            (bool s,) = payable(user).call{value: amount}("");
            require(s, 'Failure on Claim WETH');
        } else {
            IUniswapV2Router02(rewardTokens[rTokenIndex].DEX).swapExactETHForTokensSupportingFeeOnTransferTokens{value: amount}(
                minOut,
                rewardTokens[rTokenIndex].path,
                user, // have rewards automatically sent to the user to avoid double taxing
                block.timestamp + 100
            );
        }
    }

    function _addRewardToken(
        address _token,
        address DEX,
        address[] memory path
    ) internal {
        rewardTokens[rewardTokenNonce] = RewardToken(_token, DEX, path, true);
        unchecked { 
            ++rewardTokenNonce;
        }
    }

    function _transferIn(address _token, uint256 amount) internal returns (uint256) {
        uint before = IERC20(_token).balanceOf(address(this));
        IERC20(_token).transferFrom(msg.sender, address(this), amount);
        uint After = IERC20(_token).balanceOf(address(this));
        require(
            After > before,
            'Error On TransferIn'
        );
        return After - before;
    }

    function pendingRewardsInRewardToken(address user) external view returns (uint256 amount, uint256 index) {
        if (userInfo[user].amount == 0) { return (0, 0); }
        uint256 pendingBNB = pendingRewards(user);
        uint256 rewardIndex = userInfo[user].rewardToken;
        if (rewardTokens[rewardIndex].token == WETH) {
            return (pendingBNB, rewardIndex);
        }
        uint256[] memory amountsOut = IUniswapV2Router02(rewardTokens[rewardIndex].DEX).getAmountsOut(pendingBNB, rewardTokens[rewardIndex].path);
        return (amountsOut[amountsOut.length - 1], rewardIndex);
    }

    function getUserRewardToken(address user) external view returns (uint256, address) {
        return (userInfo[user].rewardToken, rewardTokens[userInfo[user].rewardToken].token);
    }

    function timeUntilUnlock(address user) public view returns (uint256) {
        return userInfo[user].unlockTime < block.timestamp ? 0 : userInfo[user].unlockTime - block.timestamp;
    }

    function pendingRewards(address shareholder) public view returns (uint256) {
        if(userInfo[shareholder].amount == 0){ return 0; }

        uint256 totalDividends = getCumulativeDividends(userInfo[shareholder].amount);
        uint256 tExcluded = userInfo[shareholder].totalExcluded;

        if(totalDividends <= tExcluded){ return 0; }

        return totalDividends <= tExcluded ? 0 : totalDividends - tExcluded;
    }

    function getCumulativeDividends(uint256 share) internal view returns (uint256) {
        return ( share * dividendsPerShare ) / precision;
    }

    function getAllRewardTokens() external view returns (address[] memory tokens, string[] memory names, uint8[] memory decimalss) {
        tokens = new address[](rewardTokenNonce);
        names = new string[](rewardTokenNonce);
        decimalss = new uint8[](rewardTokenNonce);
        for (uint256 i = 0; i < rewardTokenNonce;) {
            tokens[i] = rewardTokens[i].token;
            names[i] = IERC20(rewardTokens[i].token).name();
            decimalss[i] = IERC20(rewardTokens[i].token).decimals();
            unchecked { ++i; }
        }
        return (tokens, names, decimalss);
    }

    function getAllRewardTokenInfo() external view returns (RewardToken[] memory) {
        RewardToken[] memory tokens = new RewardToken[](rewardTokenNonce);
        for (uint256 i = 0; i < rewardTokenNonce;) {
            tokens[i] = rewardTokens[i];
            unchecked { ++i; }
        }
        return tokens;
    }

    function getStandardSwapPath(address _token) public pure returns (address[] memory) {
        address[] memory path = new address[](2);
        path[0] = WETH;
        path[1] = _token;
        return path;
    }

    receive() external payable {
        require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
        if (totalShares == 0) {
            return;
        }
        // update state
        unchecked {
            dividendsPerShare += ( msg.value * precision ) / totalShares;
            totalRewards += msg.value;
        }
    }

}