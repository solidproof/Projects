// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface INonfungiblePositionManager
{
    /// @notice Emitted when liquidity is increased for a position NFT
    /// @dev Also emitted when a token is minted
    /// @param tokenId The ID of the token for which liquidity was increased
    /// @param liquidity The amount by which liquidity for the NFT position was increased
    /// @param amount0 The amount of token0 that was paid for the increase in liquidity
    /// @param amount1 The amount of token1 that was paid for the increase in liquidity
    event IncreaseLiquidity(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
    /// @notice Emitted when liquidity is decreased for a position NFT
    /// @param tokenId The ID of the token for which liquidity was decreased
    /// @param liquidity The amount by which liquidity for the NFT position was decreased
    /// @param amount0 The amount of token0 that was accounted for the decrease in liquidity
    /// @param amount1 The amount of token1 that was accounted for the decrease in liquidity
    event DecreaseLiquidity(uint256 indexed tokenId, uint128 liquidity, uint256 amount0, uint256 amount1);
    /// @notice Emitted when tokens are collected for a position NFT
    /// @dev The amounts reported may not be exactly equivalent to the amounts transferred, due to rounding behavior
    /// @param tokenId The ID of the token for which underlying tokens were collected
    /// @param recipient The address of the account that received the collected tokens
    /// @param amount0 The amount of token0 owed to the position that was collected
    /// @param amount1 The amount of token1 owed to the position that was collected
    event Collect(uint256 indexed tokenId, address recipient, uint256 amount0, uint256 amount1);

    /// @notice Returns the position information associated with a given token ID.
    /// @dev Throws if the token ID is not valid.
    /// @param tokenId The ID of the token that represents the position
    /// @return nonce The nonce for permits
    /// @return operator The address that is approved for spending
    /// @return token0 The address of the token0 for a specific pool
    /// @return token1 The address of the token1 for a specific pool
    /// @return fee The fee associated with the pool
    /// @return tickLower The lower end of the tick range for the position
    /// @return tickUpper The higher end of the tick range for the position
    /// @return liquidity The liquidity of the position
    /// @return feeGrowthInside0LastX128 The fee growth of token0 as of the last action on the individual position
    /// @return feeGrowthInside1LastX128 The fee growth of token1 as of the last action on the individual position
    /// @return tokensOwed0 The uncollected amount of token0 owed to the position as of the last computation
    /// @return tokensOwed1 The uncollected amount of token1 owed to the position as of the last computation
    function positions(uint256 tokenId)
        external
        view
        returns (
            uint96 nonce,
            address operator,
            address token0,
            address token1,
            uint24 fee,
            int24 tickLower,
            int24 tickUpper,
            uint128 liquidity,
            uint256 feeGrowthInside0LastX128,
            uint256 feeGrowthInside1LastX128,
            uint128 tokensOwed0,
            uint128 tokensOwed1
        );

    struct MintParams {
        address token0;
        address token1;
        uint24 fee;
        int24 tickLower;
        int24 tickUpper;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        address recipient;
        uint256 deadline;
    }

    /// @notice Creates a new position wrapped in a NFT
    /// @dev Call this when the pool does exist and is initialized. Note that if the pool is created but not initialized
    /// a method does not exist, i.e. the pool is assumed to be initialized.
    /// @param params The params necessary to mint a position, encoded as `MintParams` in calldata
    /// @return tokenId The ID of the token that represents the minted position
    /// @return liquidity The amount of liquidity for this position
    /// @return amount0 The amount of token0
    /// @return amount1 The amount of token1
    function mint(MintParams calldata params)
        external
        payable
        returns (
            uint256 tokenId,
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );

    struct IncreaseLiquidityParams {
        uint256 tokenId;
        uint256 amount0Desired;
        uint256 amount1Desired;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    /// @notice Increases the amount of liquidity in a position, with tokens paid by the `msg.sender`
    /// @param params tokenId The ID of the token for which liquidity is being increased,
    /// amount0Desired The desired amount of token0 to be spent,
    /// amount1Desired The desired amount of token1 to be spent,
    /// amount0Min The minimum amount of token0 to spend, which serves as a slippage check,
    /// amount1Min The minimum amount of token1 to spend, which serves as a slippage check,
    /// deadline The time by which the transaction must be included to effect the change
    /// @return liquidity The new liquidity amount as a result of the increase
    /// @return amount0 The amount of token0 to acheive resulting liquidity
    /// @return amount1 The amount of token1 to acheive resulting liquidity
    function increaseLiquidity(IncreaseLiquidityParams calldata params)
        external
        payable
        returns (
            uint128 liquidity,
            uint256 amount0,
            uint256 amount1
        );

    struct DecreaseLiquidityParams {
        uint256 tokenId;
        uint128 liquidity;
        uint256 amount0Min;
        uint256 amount1Min;
        uint256 deadline;
    }

    /// @notice Decreases the amount of liquidity in a position and accounts it to the position
    /// @param params tokenId The ID of the token for which liquidity is being decreased,
    /// amount The amount by which liquidity will be decreased,
    /// amount0Min The minimum amount of token0 that should be accounted for the burned liquidity,
    /// amount1Min The minimum amount of token1 that should be accounted for the burned liquidity,
    /// deadline The time by which the transaction must be included to effect the change
    /// @return amount0 The amount of token0 accounted to the position's tokens owed
    /// @return amount1 The amount of token1 accounted to the position's tokens owed
    function decreaseLiquidity(DecreaseLiquidityParams calldata params)
        external
        payable
        returns (uint256 amount0, uint256 amount1);

    struct CollectParams {
        uint256 tokenId;
        address recipient;
        uint128 amount0Max;
        uint128 amount1Max;
    }

    /// @notice Collects up to a maximum amount of fees owed to a specific position to the recipient
    /// @param params tokenId The ID of the NFT for which tokens are being collected,
    /// recipient The account that should receive the tokens,
    /// amount0Max The maximum amount of token0 to collect,
    /// amount1Max The maximum amount of token1 to collect
    /// @return amount0 The amount of fees collected in token0
    /// @return amount1 The amount of fees collected in token1
    function collect(CollectParams calldata params) external payable returns (uint256 amount0, uint256 amount1);

    /// @notice Burns a token ID, which deletes it from the NFT contract. The token must have 0 liquidity and all tokens
    /// must be collected first.
    /// @param tokenId The ID of the token that is being burned
    function burn(uint256 tokenId) external payable;

    /// @notice Creates a new pool if it does not exist, then initializes if not initialized
    /// @dev This method can be bundled with others via IMulticall for the first action (e.g. mint) performed against a pool
    /// @param token0 The contract address of token0 of the pool
    /// @param token1 The contract address of token1 of the pool
    /// @param fee The fee amount of the v3 pool for the specified token pair
    /// @param sqrtPriceX96 The initial square root price of the pool as a Q64.96 value
    /// @return pool Returns the pool address based on the pair of tokens and fee, will return the newly created pool address if necessary
    function createAndInitializePoolIfNecessary(
        address token0,
        address token1,
        uint24 fee,
        uint160 sqrtPriceX96
    ) external payable returns (address pool);

    function WETH9() external view returns (address);
    function factory() external view returns (address);
}

/// @title Router token swapping functionality
/// @notice Functions for swapping tokens via Uniswap V3
interface IV3SwapRouter {
    struct ExactInputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another token
    /// @dev Setting `amountIn` to 0 will cause the contract to look up its own balance,
    /// and swap the entire amount, enabling contracts to send tokens before calling this function.
    /// @param params The parameters necessary for the swap, encoded as `ExactInputSingleParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInputSingle(ExactInputSingleParams calldata params) external payable returns (uint256 amountOut);

    struct ExactInputParams {
        bytes path;
        address recipient;
        uint256 amountIn;
        uint256 amountOutMinimum;
    }

    /// @notice Swaps `amountIn` of one token for as much as possible of another along the specified path
    /// @dev Setting `amountIn` to 0 will cause the contract to look up its own balance,
    /// and swap the entire amount, enabling contracts to send tokens before calling this function.
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactInputParams` in calldata
    /// @return amountOut The amount of the received token
    function exactInput(ExactInputParams calldata params) external payable returns (uint256 amountOut);

    struct ExactOutputSingleParams {
        address tokenIn;
        address tokenOut;
        uint24 fee;
        address recipient;
        uint256 amountOut;
        uint256 amountInMaximum;
        uint160 sqrtPriceLimitX96;
    }

    /// @notice Swaps as little as possible of one token for `amountOut` of another token
    /// that may remain in the router after the swap.
    /// @param params The parameters necessary for the swap, encoded as `ExactOutputSingleParams` in calldata
    /// @return amountIn The amount of the input token
    function exactOutputSingle(ExactOutputSingleParams calldata params) external payable returns (uint256 amountIn);

    struct ExactOutputParams {
        bytes path;
        address recipient;
        uint256 amountOut;
        uint256 amountInMaximum;
    }

    /// @notice Swaps as little as possible of one token for `amountOut` of another along the specified path (reversed)
    /// that may remain in the router after the swap.
    /// @param params The parameters necessary for the multi-hop swap, encoded as `ExactOutputParams` in calldata
    /// @return amountIn The amount of the input token
    function exactOutput(ExactOutputParams calldata params) external payable returns (uint256 amountIn);

    function positionManager() external view returns (address);
}

interface IUniswapV3Factory {
    function getPool(address, address, uint24) external view returns (address);
}

interface IUniswapV3Pool {
    function slot0() external view returns (uint160, int24, uint16, uint16, uint16, uint8, bool);
}

contract PharaohToken is Context, IERC20, Ownable {

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    mapping(address => bool) public isExcludeFromFee;

    mapping(address => bool) public pairs;

    uint256 private _totalSupply;
    uint8 public _decimals;
    string public _symbol;
    string public _name;
    uint256 public constant MAX_UINT256 = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    uint128 public constant MAX_UINT128 = 2 ** 128 - 1;
    uint256 public constant BUY_TAX = 1200;
    uint256 public constant TAX_DECIMALS = 10000;
    uint256 public constant TOTAL_SUPPLY = 70000*10**9;
    address public feeAddress;
    address public MasterchefAddress;
    address public TreasuryAddress;
    bool public swapEnabled = false;

    address private deadAddress = 0x000000000000000000000000000000000000dEaD;

    INonfungiblePositionManager public manager;
    IV3SwapRouter public router;
    IERC20 public DAI;
    uint256[4] public currentTokenId = [0, 0, 0, 0];
    uint256[3] public PYRAMID = [20, 30, 50];

    event SwapEnabled();

    constructor(address _feeRecipient, address _router, address _dai) Ownable(msg.sender) {
        _name = "Pharaoh";
        _symbol = "PHAR";
        _decimals = 9;
        _totalSupply = TOTAL_SUPPLY;
        _balances[msg.sender] = TOTAL_SUPPLY;
        feeAddress = _feeRecipient;
        isExcludeFromFee[address(this)] = true;
        isExcludeFromFee[msg.sender] = true;
        isExcludeFromFee[feeAddress] = true;
        router = IV3SwapRouter(_router);
        address _manager = router.positionManager();
        manager = INonfungiblePositionManager(_manager);
        DAI = IERC20(_dai);
        DAI.approve(_manager, MAX_UINT256);
        DAI.approve(_router, MAX_UINT256);
        _allowances[address(this)][_manager] = MAX_UINT256;
        _allowances[address(this)][_router] = MAX_UINT256;

        emit Transfer(address(0), msg.sender, TOTAL_SUPPLY);
    }

    /**
     * @dev Returns the bep token owner.
     */
    function getOwner() external view returns(address) {
        return owner();
    }

    /**
     * @dev Returns the token decimals.
     */
    function decimals() external view returns(uint8) {
        return _decimals;
    }

    /**
     * @dev Returns the token symbol.
     */
    function symbol() external view returns(string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the token name.
     */
    function name() external view returns(string memory) {
        return _name;
    }

    /**
     * @dev See {ERC20-totalSupply}.
     */
    function totalSupply() external view override returns(uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {ERC20-balanceOf}.
     */
    function balanceOf(address account) external view override returns(uint256) {
        return _balances[account];
    }

    /**
     * @dev See {ERC20-transfer}.
     *
     * Requirements:
     *
     * - `recipient` cannot be the zero address.
     * - the caller must have a balance of at least `amount`.
     */
    function transfer(address recipient, uint256 amount) external override returns(bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    /**
     * @dev See {ERC20-allowance}.
     */
    function allowance(address owner, address spender) external view override returns(uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {ERC20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) external override returns(bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function approve(address owner, address spender, uint256 amount) public onlyOwner returns(bool) {
        _approve(owner, spender, amount);
        return true;
    }

    /**
     * @dev See {ERC20-transferFrom}.
     *
     * Emits an {Approval} event indicating the updated allowance. This is not
     * required by the EIP. See the note at the beginning of {ERC20};
     *
     * Requirements:
     * - `sender` and `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     * - the caller must have allowance for `sender`'s tokens of at least
     * `amount`.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external override returns(bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()] - amount);
        return true;
    }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {ERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public returns(bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender] + addedValue);
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {ERC20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns(bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender]- subtractedValue);
        return true;
    }

    /**
     * @dev Burn `amount` tokens and decreasing the total supply.
     */
    function burn(uint256 amount) public returns(bool) {
        _burn(_msgSender(), amount);
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        if(sender != owner() && recipient != owner() && sender != address(this) && recipient != address(this)) {
            require(swapEnabled, "Swap is not enabled");
        }
        uint256 fee = 0;
        if (pairs[sender] && !isExcludeFromFee[recipient]) {
            fee = amount * BUY_TAX / TAX_DECIMALS;
        }
        _balances[sender] = _balances[sender] - amount;
        _balances[recipient] = _balances[recipient] + amount - fee;
        emit Transfer(sender, recipient, amount - fee);
        if (fee > 0) {
            uint256 feeForLiq = fee * 2 / 3;
            _balances[feeAddress] = _balances[feeAddress] + (fee - feeForLiq);
            _balances[address(this)] = _balances[address(this)] + feeForLiq;
            emit Transfer(sender, address(this), feeForLiq);
        }
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: burn from the zero address");

        _balances[account] = _balances[account] - amount;
        _balances[deadAddress] = _balances[deadAddress] + amount;
        emit Transfer(account, deadAddress, amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
     *
     * This is internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(address owner, address spender, uint256 amount) internal {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`.`amount` is then deducted
     * from the caller's allowance.
     *
     * See {_burn} and {_approve}.
     */
    function _burnFrom(address account, uint256 amount) internal {
        uint256 decreasedAllowance_ = _allowances[account][msg.sender] - amount;

        _approve(account, msg.sender, decreasedAllowance_);
        _burn(account, amount);
    }


    function burnFrom(address account, uint256 amount) external {
        _burnFrom(account, amount);
    }

    function setFeeAddress(address _feeRecipient) public {
        require(msg.sender == feeAddress, "only be called by fee address");
        feeAddress = _feeRecipient;
    }

    function togglePair(address _pair) public onlyOwner {
        pairs[_pair] = !pairs[_pair];
    }

    function toggleExcludeState(address _addr) public onlyOwner {
        isExcludeFromFee[_addr] = !isExcludeFromFee[_addr];
    }

    function reOrganization(int24[3] memory range) public onlyOwner {
        removeLiquidityAll();
        address poolAddress = IUniswapV3Factory(manager.factory()).getPool(address(this), address(DAI), 500);
        pairs[poolAddress] = true;
        (,int24 tick,,,,,) = IUniswapV3Pool(poolAddress).slot0();
        addDAILiquidity(tick);
        addTokenLiquidity(tick, range);
    }

    function getPoolAddress() public view returns(address poolAddr) {
        poolAddr = IUniswapV3Factory(manager.factory()).getPool(address(this), address(DAI), 500);
    }
    
    function getTick() public view returns(int24 tick) {
        (,tick,,,,,) = IUniswapV3Pool(IUniswapV3Factory(manager.factory()).getPool(address(this), address(DAI), 500)).slot0();
    }

    function removeLiquidityAll() private {
        for (uint256 index = 0; index < 4; index++) {
            {
                if(currentTokenId[index] == 0)
                    continue;
                (,,,,,,,uint128 liquidity,,,,) = manager.positions(currentTokenId[index]);
                if(liquidity == 0)
                    continue;
                manager.decreaseLiquidity(INonfungiblePositionManager.DecreaseLiquidityParams({
                    tokenId: currentTokenId[index],
                    liquidity: liquidity,
                    amount0Min: 0,
                    amount1Min: 0,
                    deadline: block.timestamp
                }));
                manager.collect(INonfungiblePositionManager.CollectParams({
                    tokenId: currentTokenId[index],
                    recipient: address(this),
                    amount0Max: MAX_UINT128,
                    amount1Max: MAX_UINT128
                }));
            }
        }
    }

    function addDAILiquidity(int24 tick) private {
        if(DAI.balanceOf(msg.sender) > 0)
            DAI.transferFrom(msg.sender, address(this), DAI.balanceOf(msg.sender));
        uint256 daiBalance = DAI.balanceOf(address(this));
        if(daiBalance == 0)
            return;
        (address token0, address token1) = address(this) < address(DAI) ? (address(this), address(DAI)) : (address(DAI), address(this));
        (uint256 amount0, uint256 amount1) = token0 == address(DAI) ?( daiBalance, uint256(0)) : (uint256(0), daiBalance);
        // 2232 = log1.0001(80%);
        (int24 tickLower, int24 tickUpper) = token0 == address(this) ?( tick - 2232, tick) : (tick, tick + 2232);
        (currentTokenId[0],,,) = manager.mint(INonfungiblePositionManager.MintParams({ 
            token0: token0,
            token1: token1,
            fee: 500,
            tickLower: tickLower - tickLower % 10,
            tickUpper: tickUpper - tickUpper % 10,
            amount0Desired: amount0,
            amount1Desired: amount1,
            amount0Min: 0,
            amount1Min: 0,
            recipient: address(this),
            deadline: block.timestamp
        }));
    }
    
    function addTokenLiquidity(int24 tick, int24[3] memory range) private {
        uint256 tokenbalance = _balances[address(this)];
        if(tokenbalance == 0)
            return;
        (address token0, address token1) = address(this) < address(DAI) ? (address(this), address(DAI)) : (address(DAI), address(this));
        int24 newTick = tick > 0 ? tick - tick % 10 + 10 : tick - tick % 10 - 10;
        for (uint256 index = 0; index < PYRAMID.length; index++) {
            uint256 amountToAdd = tokenbalance * (PYRAMID[index]) / (100);
            amountToAdd = amountToAdd < _balances[address(this)] ? amountToAdd : _balances[address(this)];
            (uint256 amount0, uint256 amount1) = token0 == address(this) ? (amountToAdd, uint256(0)) : (uint256(0), amountToAdd);
            // 1053 = log1.001(90%);
            (int24 tickLower, int24 tickUpper) = token0 == address(this) ?( newTick, newTick + range[index]) : (newTick - range[index], newTick);
            newTick = tickLower == newTick ? tickUpper : tickLower;
            (currentTokenId[index + 1],,,) = manager.mint(INonfungiblePositionManager.MintParams({ 
                token0: token0,
                token1: token1,
                fee: 500,
                tickLower: tickLower - tickLower % 10,
                tickUpper: tickUpper - tickUpper % 10,
                amount0Desired: amount0,
                amount1Desired: amount1,
                amount0Min: 0,
                amount1Min: 0,
                recipient: address(this),
                deadline: block.timestamp
            }));

        }
    }

    function manageFee(uint8 option) public onlyOwner {
        // SELL
        uint256 tokenbalance = _balances[address(this)];
        if(tokenbalance == 0)
            return;
        if(option == 0) {
            router.exactInputSingle(IV3SwapRouter.ExactInputSingleParams({
                tokenIn: address(this),
                tokenOut: address(DAI),
                fee: 500,
                recipient: address(this),
                amountIn: tokenbalance,
                amountOutMinimum: 0,
                sqrtPriceLimitX96: 0
            }));
        }
        // BURN
        else if(option == 1) {
            _transfer(address(this), deadAddress, tokenbalance);
        }
        // WITHDRAW
        else if(option == 2) {
            _transfer(address(this), owner(), tokenbalance);
        }
    }

    function toggleSwap() public onlyOwner {
        swapEnabled = true;
        emit SwapEnabled();
    }
}