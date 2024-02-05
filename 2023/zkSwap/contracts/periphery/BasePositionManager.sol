// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.16;
pragma abicoder v2;

import {IERC20} from '@openzeppelin/contracts/token/ERC20/IERC20.sol';
import {IERC721} from '@openzeppelin/contracts/token/ERC721/IERC721.sol';
import {ERC721} from '@openzeppelin/contracts/token/ERC721/ERC721.sol';

import {PoolAddress} from './libraries/PoolAddress.sol';
import {MathConstants as C} from '../libraries/MathConstants.sol';
import {FullMath} from '../libraries/FullMath.sol';
import {QtyDeltaMath} from '../libraries/QtyDeltaMath.sol';

import {IPool} from '../interfaces/IPool.sol';
import {IFactory} from '../interfaces/IFactory.sol';
import {IBasePositionManager} from '../interfaces/periphery/IBasePositionManager.sol';
import {INonfungibleTokenPositionDescriptor} from '../interfaces/periphery/INonfungibleTokenPositionDescriptor.sol';
import {IRouterTokenHelper} from '../interfaces/periphery/IRouterTokenHelper.sol';

import {LiquidityHelper} from './base/LiquidityHelper.sol';
import {RouterTokenHelper} from './base/RouterTokenHelper.sol';
import {Multicall} from './base/Multicall.sol';
import {DeadlineValidation} from './base/DeadlineValidation.sol';
import {ERC721Permit} from './base/ERC721Permit.sol';

contract BasePositionManager is
IBasePositionManager,
Multicall,
ERC721Permit('Zk-Swap NFT Positions Manager', 'ZPSWAP-NPM', '1'),
LiquidityHelper
{
    address internal immutable _tokenDescriptor;
    uint80 public override nextPoolId = 1;
    uint256 public override nextTokenId = 1;
    // pool id => pool info
    mapping(uint80 => PoolInfo) internal _poolInfoById;
    // tokenId => position
    mapping(uint256 => Position) internal _positions;

    mapping(address => bool) public override isRToken;
    // pool address => pool id
    mapping(address => uint80) public override addressToPoolId;

    modifier isAuthorizedForToken(uint256 tokenId) {
        require(_isApprovedOrOwner(msg.sender, tokenId), 'Not approved');
        _;
    }

    constructor(
        address _factory,
        address _WETH,
        address _descriptor
    ) LiquidityHelper(_factory, _WETH) {
        _tokenDescriptor = _descriptor;
    }

    function createAndUnlockPoolIfNecessary(
        address token0,
        address token1,
        uint24 fee,
        uint160 currentSqrtP
    ) external payable override returns (address pool) {
        require(token0 < token1);
        pool = IFactory(factory).getPool(token0, token1, fee);

        if (pool == address(0)) {
            pool = IFactory(factory).createPool(token0, token1, fee);
        }

        (uint160 sqrtP, , , ) = IPool(pool).getPoolState();
        if (sqrtP == 0) {
            (uint256 qty0, uint256 qty1) = QtyDeltaMath.calcUnlockQtys(currentSqrtP);
            _transferTokens(token0, msg.sender, pool, qty0);
            _transferTokens(token1, msg.sender, pool, qty1);
            IPool(pool).unlockPool(currentSqrtP);
        }
    }

    function mint(MintParams calldata params)
    public
    payable
    virtual
    override
    onlyNotExpired(params.deadline)
    returns (
        uint256 tokenId,
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1
    )
    {
        IPool pool;
        uint256 feeGrowthInsideLast;

        (liquidity, amount0, amount1, feeGrowthInsideLast, pool) = _addLiquidity(
            AddLiquidityParams({
        token0: params.token0,
        token1: params.token1,
        fee: params.fee,
        recipient: address(this),
        tickLower: params.tickLower,
        tickUpper: params.tickUpper,
        ticksPrevious: params.ticksPrevious,
        amount0Desired: params.amount0Desired,
        amount1Desired: params.amount1Desired,
        amount0Min: params.amount0Min,
        amount1Min: params.amount1Min
        })
        );

        tokenId = nextTokenId++;
        _mint(params.recipient, tokenId);

        uint80 poolId = _storePoolInfo(address(pool), params.token0, params.token1, params.fee);

        _positions[tokenId] = Position({
        nonce: 0,
        operator: address(0),
        poolId: poolId,
        tickLower: params.tickLower,
        tickUpper: params.tickUpper,
        liquidity: liquidity,
        rTokenOwed: 0,
        feeGrowthInsideLast: feeGrowthInsideLast
        });

        emit MintPosition(tokenId, poolId, liquidity, amount0, amount1);
    }

    function addLiquidity(IncreaseLiquidityParams calldata params)
    external
    payable
    virtual
    override
    onlyNotExpired(params.deadline)
    returns (
        uint128 liquidity,
        uint256 amount0,
        uint256 amount1,
        uint256 additionalRTokenOwed
    )
    {
        Position storage pos = _positions[params.tokenId];
        PoolInfo memory poolInfo = _poolInfoById[pos.poolId];
        IPool pool;
        uint256 feeGrowthInsideLast;

        (liquidity, amount0, amount1, feeGrowthInsideLast, pool) = _addLiquidity(
            AddLiquidityParams({
        token0: poolInfo.token0,
        token1: poolInfo.token1,
        fee: poolInfo.fee,
        recipient: address(this),
        tickLower: pos.tickLower,
        tickUpper: pos.tickUpper,
        ticksPrevious: params.ticksPrevious,
        amount0Desired: params.amount0Desired,
        amount1Desired: params.amount1Desired,
        amount0Min: params.amount0Min,
        amount1Min: params.amount1Min
        })
        );

        uint128 tmpLiquidity = pos.liquidity;

        additionalRTokenOwed = _updateRTokenOwedAndFeeGrowth(
            params.tokenId,
            pos.feeGrowthInsideLast,
            feeGrowthInsideLast,
            tmpLiquidity
        );

        pos.liquidity = tmpLiquidity + liquidity;

        emit AddLiquidity(params.tokenId, liquidity, amount0, amount1, additionalRTokenOwed);
    }

    function removeLiquidity(RemoveLiquidityParams calldata params)
    external
    virtual
    override
    isAuthorizedForToken(params.tokenId)
    onlyNotExpired(params.deadline)
    returns (
        uint256 amount0,
        uint256 amount1,
        uint256 additionalRTokenOwed
    )
    {
        Position storage pos = _positions[params.tokenId];
        uint128 tmpLiquidity = pos.liquidity;
        require(tmpLiquidity >= params.liquidity, 'Insufficient liquidity');

        PoolInfo memory poolInfo = _poolInfoById[pos.poolId];
        IPool pool = _getPool(poolInfo.token0, poolInfo.token1, poolInfo.fee);

        uint256 feeGrowthInsideLast;
        (amount0, amount1, feeGrowthInsideLast) = pool.burn(
            pos.tickLower,
            pos.tickUpper,
            params.liquidity
        );
        require(amount0 >= params.amount0Min && amount1 >= params.amount1Min, 'Low return amounts');

        additionalRTokenOwed = _updateRTokenOwedAndFeeGrowth(
            params.tokenId,
            pos.feeGrowthInsideLast,
            feeGrowthInsideLast,
            tmpLiquidity
        );

        pos.liquidity = tmpLiquidity - params.liquidity;

        emit RemoveLiquidity(params.tokenId, params.liquidity, amount0, amount1, additionalRTokenOwed);
    }

    function syncFeeGrowth(uint256 tokenId)
    external
    virtual
    override
    isAuthorizedForToken(tokenId)
    returns(uint256 additionalRTokenOwed)
    {
        Position storage pos = _positions[tokenId];

        PoolInfo memory poolInfo = _poolInfoById[pos.poolId];
        IPool pool = _getPool(poolInfo.token0, poolInfo.token1, poolInfo.fee);

        uint256 feeGrowthInsideLast = pool.tweakPosZeroLiq(
            pos.tickLower,
            pos.tickUpper
        );

        additionalRTokenOwed = _updateRTokenOwedAndFeeGrowth(
            tokenId,
            pos.feeGrowthInsideLast,
            feeGrowthInsideLast,
            pos.liquidity
        );
        emit SyncFeeGrowth(tokenId, additionalRTokenOwed);
    }

    function burnRTokens(BurnRTokenParams calldata params)
    external
    override
    isAuthorizedForToken(params.tokenId)
    onlyNotExpired(params.deadline)
    returns (
        uint256 rTokenQty,
        uint256 amount0,
        uint256 amount1
    )
    {
        Position storage pos = _positions[params.tokenId];
        rTokenQty = pos.rTokenOwed;
        require(rTokenQty > 0, 'No rToken to burn');

        PoolInfo memory poolInfo = _poolInfoById[pos.poolId];
        IPool pool = _getPool(poolInfo.token0, poolInfo.token1, poolInfo.fee);

        pos.rTokenOwed = 0;
        uint256 rTokenBalance = IERC20(address(pool)).balanceOf(address(this));
        (amount0, amount1) = pool.burnRTokens(
            rTokenQty > rTokenBalance ? rTokenBalance : rTokenQty,
            false
        );
        require(amount0 >= params.amount0Min && amount1 >= params.amount1Min, 'Low return amounts');

        emit BurnRToken(params.tokenId, rTokenQty);
    }

    /**
     * @dev Burn the token by its owner
   * @notice All liquidity should be removed before burning
   */
    function burn(uint256 tokenId) external payable override isAuthorizedForToken(tokenId) {
        require(_positions[tokenId].liquidity == 0, 'Should remove liquidity first');
        require(_positions[tokenId].rTokenOwed == 0, 'Should burn rToken first');
        delete _positions[tokenId];
        _burn(tokenId);

        emit BurnPosition(tokenId);
    }

    function positions(uint256 tokenId)
    external
    view
    override
    returns (Position memory pos, PoolInfo memory info)
    {
        pos = _positions[tokenId];
        info = _poolInfoById[pos.poolId];
    }

    /**
     * @dev Override this function to not allow transferring rTokens
   * @notice it also means this PositionManager can not support LP of a rToken and another token
   */
    function transferAllTokens(
        address token,
        uint256 minAmount,
        address recipient
    ) public payable override(IRouterTokenHelper, RouterTokenHelper) {
        require(!isRToken[token], 'Can not transfer rToken');
        super.transferAllTokens(token, minAmount, recipient);
    }

    function tokenURI(uint256 tokenId) public view override returns (string memory) {
        require(_exists(tokenId), 'Nonexistent token');
        return INonfungibleTokenPositionDescriptor(_tokenDescriptor).tokenURI(this, tokenId);
    }

    function getApproved(uint256 tokenId) public view override(ERC721, IERC721) returns (address) {
        require(_exists(tokenId), 'ERC721: approved query for nonexistent token');
        return _positions[tokenId].operator;
    }

    /**
     * @dev See {IERC165-supportsInterface}.
   */
    function supportsInterface(bytes4 interfaceId)
    public
    view
    virtual
    override(ERC721Permit, IBasePositionManager)
    returns (bool)
    {
        return
        interfaceId == type(ERC721Permit).interfaceId ||
        interfaceId == type(IBasePositionManager).interfaceId ||
        super.supportsInterface(interfaceId);
    }

    function _updateRTokenOwedAndFeeGrowth(
        uint256 tokenId,
        uint256 feeGrowthOld,
        uint256 feeGrowthNew,
        uint128 liquidity)
    internal
    returns (uint256 additionalRTokenOwed)
    {
        if (feeGrowthNew != feeGrowthOld) {
            uint256 feeGrowthInsideDiff;
        unchecked {
            feeGrowthInsideDiff = feeGrowthNew - feeGrowthOld;
        }
            additionalRTokenOwed = FullMath.mulDivFloor(liquidity, feeGrowthInsideDiff, C.TWO_POW_96);
            _positions[tokenId].rTokenOwed += additionalRTokenOwed;
            _positions[tokenId].feeGrowthInsideLast = feeGrowthNew;
        }
    }

    function _storePoolInfo(
        address pool,
        address token0,
        address token1,
        uint24 fee
    ) internal returns (uint80 poolId) {
        poolId = addressToPoolId[pool];
        if (poolId == 0) {
            addressToPoolId[pool] = (poolId = nextPoolId++);
            _poolInfoById[poolId] = PoolInfo({token0: token0, fee: fee, token1: token1});
            isRToken[pool] = true;
        }
    }

    /// @dev Overrides _approve to use the operator in the position, which is packed with the position permit nonce
    function _approve(address to, uint256 tokenId) internal override {
        _positions[tokenId].operator = to;
        emit Approval(ownerOf(tokenId), to, tokenId);
    }

    function _getAndIncrementNonce(uint256 tokenId) internal override returns (uint256) {
        return uint256(_positions[tokenId].nonce++);
    }
}
