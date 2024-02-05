// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

import {BinHelper} from "./libraries/BinHelper.sol";
import {Constants} from "./libraries/Constants.sol";
import {Encoded} from "./libraries/math/Encoded.sol";
import {FeeHelper} from "./libraries/FeeHelper.sol";
import {JoeLibrary} from "./libraries/JoeLibrary.sol";
import {LiquidityConfigurations} from "./libraries/math/LiquidityConfigurations.sol";
import {PackedUint128Math} from "./libraries/math/PackedUint128Math.sol";
import {TokenHelper} from "./libraries/TokenHelper.sol";
import {Uint256x256Math} from "./libraries/math/Uint256x256Math.sol";

import {IJoePair} from "./interfaces/IJoePair.sol";
import {ILBPair} from "./interfaces/ILBPair.sol";
import {ILBLegacyPair} from "./interfaces/ILBLegacyPair.sol";
import {ILBToken} from "./interfaces/ILBToken.sol";
import {ILBRouter} from "./interfaces/ILBRouter.sol";
import {ILBLegacyRouter} from "./interfaces/ILBLegacyRouter.sol";
import {IJoeFactory} from "./interfaces/IJoeFactory.sol";
import {ILBLegacyFactory} from "./interfaces/ILBLegacyFactory.sol";
import {ILBFactory} from "./interfaces/ILBFactory.sol";
import {IWNATIVE} from "./interfaces/IWNATIVE.sol";

/**
 * @title Liquidity Book Router
 * @author Trader Joe
 * @notice Main contract to interact with to swap and manage liquidity on Joe V2 exchange.
 */
contract LBRouter is ILBRouter {
    using TokenHelper for IERC20;
    using TokenHelper for IWNATIVE;
    using JoeLibrary for uint256;
    using PackedUint128Math for bytes32;

    ILBFactory private immutable _factory;
    IJoeFactory private immutable _factoryV1;
    ILBLegacyFactory private immutable _legacyFactory;
    ILBLegacyRouter private immutable _legacyRouter;
    IWNATIVE private immutable _wnative;

    modifier onlyFactoryOwner() {
        if (msg.sender != _factory.owner()) revert LBRouter__NotFactoryOwner();
        _;
    }

    modifier ensure(uint256 deadline) {
        if (block.timestamp > deadline) revert LBRouter__DeadlineExceeded(deadline, block.timestamp);
        _;
    }

    modifier verifyPathValidity(Path memory path) {
        if (
            path.pairBinSteps.length == 0 || path.versions.length != path.pairBinSteps.length
                || path.pairBinSteps.length + 1 != path.tokenPath.length
        ) revert LBRouter__LengthsMismatch();
        _;
    }

    /**
     * @notice Constructor
     * @param factory Address of Joe V2.1 factory
     * @param factoryV1 Address of Joe V1 factory
     * @param legacyFactory Address of Joe V2 factory
     * @param legacyRouter Address of Joe V2 router
     * @param wnative Address of WNATIVE
     */
    constructor(
        ILBFactory factory,
        IJoeFactory factoryV1,
        ILBLegacyFactory legacyFactory,
        ILBLegacyRouter legacyRouter,
        IWNATIVE wnative
    ) {
        _factory = factory;
        _factoryV1 = factoryV1;
        _legacyFactory = legacyFactory;
        _legacyRouter = legacyRouter;
        _wnative = wnative;
    }

    /**
     * @dev Receive function that only accept NATIVE from the WNATIVE contract
     */
    receive() external payable {
        if (msg.sender != address(_wnative)) revert LBRouter__SenderIsNotWNATIVE();
    }

    /**
     * View function to get the factory V2.1 address
     * @return lbFactory The address of the factory V2.1
     */
    function getFactory() external view override returns (ILBFactory lbFactory) {
        return _factory;
    }

    /**
     * View function to get the factory V2 address
     * @return legacyLBfactory The address of the factory V2
     */
    function getLegacyFactory() external view override returns (ILBLegacyFactory legacyLBfactory) {
        return _legacyFactory;
    }

    /**
     * View function to get the factory V1 address
     * @return factoryV1 The address of the factory V1
     */
    function getV1Factory() external view override returns (IJoeFactory factoryV1) {
        return _factoryV1;
    }

    /**
     * View function to get the router V2 address
     * @return legacyRouter The address of the router V2
     */
    function getLegacyRouter() external view override returns (ILBLegacyRouter legacyRouter) {
        return _legacyRouter;
    }

    /**
     * View function to get the WNATIVE address
     * @return wnative The address of WNATIVE
     */
    function getWNATIVE() external view override returns (IWNATIVE wnative) {
        return _wnative;
    }

    /**
     * @notice Returns the approximate id corresponding to the inputted price.
     * Warning, the returned id may be inaccurate close to the start price of a bin
     * @param pair The address of the LBPair
     * @param price The price of y per x (multiplied by 1e36)
     * @return The id corresponding to this price
     */
    function getIdFromPrice(ILBPair pair, uint256 price) external view override returns (uint24) {
        return pair.getIdFromPrice(price);
    }

    /**
     * @notice Returns the price corresponding to the inputted id
     * @param pair The address of the LBPair
     * @param id The id
     * @return The price corresponding to this id
     */
    function getPriceFromId(ILBPair pair, uint24 id) external view override returns (uint256) {
        return pair.getPriceFromId(id);
    }

    /**
     * @notice Simulate a swap in
     * @param pair The address of the LBPair
     * @param amountOut The amount of token to receive
     * @param swapForY Whether you swap X for Y (true), or Y for X (false)
     * @return amountIn The amount of token to send in order to receive amountOut token
     * @return amountOutLeft The amount of token Out that can't be returned due to a lack of liquidity
     * @return fee The amount of fees paid in token sent
     */
    function getSwapIn(ILBPair pair, uint128 amountOut, bool swapForY)
        public
        view
        override
        returns (uint128 amountIn, uint128 amountOutLeft, uint128 fee)
    {
        (amountIn, amountOutLeft, fee) = pair.getSwapIn(amountOut, swapForY);
    }

    /**
     * @notice Simulate a swap out
     * @param pair The address of the LBPair
     * @param amountIn The amount of token sent
     * @param swapForY Whether you swap X for Y (true), or Y for X (false)
     * @return amountInLeft The amount of token In that can't be swapped due to a lack of liquidity
     * @return amountOut The amount of token received if amountIn tokenX are sent
     * @return fee The amount of fees paid in token sent
     */
    function getSwapOut(ILBPair pair, uint128 amountIn, bool swapForY)
        external
        view
        override
        returns (uint128 amountInLeft, uint128 amountOut, uint128 fee)
    {
        (amountInLeft, amountOut, fee) = pair.getSwapOut(amountIn, swapForY);
    }

    /**
     * @notice Create a liquidity bin LBPair for tokenX and tokenY using the factory
     * @param tokenX The address of the first token
     * @param tokenY The address of the second token
     * @param activeId The active id of the pair
     * @param binStep The bin step in basis point, used to calculate log(1 + binStep)
     * @return pair The address of the newly created LBPair
     */
    function createLBPair(IERC20 tokenX, IERC20 tokenY, uint24 activeId, uint16 binStep)
        external
        override
        returns (ILBPair pair)
    {
        pair = _factory.createLBPair(tokenX, tokenY, activeId, binStep);
    }

    /**
     * @notice Add liquidity while performing safety checks
     * @dev This function is compliant with fee on transfer tokens
     * @param liquidityParameters The liquidity parameters
     * @return amountXAdded The amount of token X added
     * @return amountYAdded The amount of token Y added
     * @return amountXLeft The amount of token X left (sent back to liquidityParameters.refundTo)
     * @return amountYLeft The amount of token Y left (sent back to liquidityParameters.refundTo)
     * @return depositIds The ids of the deposits
     * @return liquidityMinted The amount of liquidity minted
     */
    function addLiquidity(LiquidityParameters calldata liquidityParameters)
        external
        override
        returns (
            uint256 amountXAdded,
            uint256 amountYAdded,
            uint256 amountXLeft,
            uint256 amountYLeft,
            uint256[] memory depositIds,
            uint256[] memory liquidityMinted
        )
    {
        ILBPair lbPair = ILBPair(
            _getLBPairInformation(
                liquidityParameters.tokenX, liquidityParameters.tokenY, liquidityParameters.binStep, Version.V2_1
            )
        );
        if (liquidityParameters.tokenX != lbPair.getTokenX()) revert LBRouter__WrongTokenOrder();

        liquidityParameters.tokenX.safeTransferFrom(msg.sender, address(lbPair), liquidityParameters.amountX);
        liquidityParameters.tokenY.safeTransferFrom(msg.sender, address(lbPair), liquidityParameters.amountY);

        (amountXAdded, amountYAdded, amountXLeft, amountYLeft, depositIds, liquidityMinted) =
            _addLiquidity(liquidityParameters, lbPair);
    }

    /**
     * @notice Add liquidity with NATIVE while performing safety checks
     * @dev This function is compliant with fee on transfer tokens
     * @param liquidityParameters The liquidity parameters
     * @return amountXAdded The amount of token X added
     * @return amountYAdded The amount of token Y added
     * @return amountXLeft The amount of token X left (sent back to liquidityParameters.refundTo)
     * @return amountYLeft The amount of token Y left (sent back to liquidityParameters.refundTo)
     * @return depositIds The ids of the deposits
     * @return liquidityMinted The amount of liquidity minted
     */
    function addLiquidityNATIVE(LiquidityParameters calldata liquidityParameters)
        external
        payable
        override
        returns (
            uint256 amountXAdded,
            uint256 amountYAdded,
            uint256 amountXLeft,
            uint256 amountYLeft,
            uint256[] memory depositIds,
            uint256[] memory liquidityMinted
        )
    {
        ILBPair _LBPair = ILBPair(
            _getLBPairInformation(
                liquidityParameters.tokenX, liquidityParameters.tokenY, liquidityParameters.binStep, Version.V2_1
            )
        );
        if (liquidityParameters.tokenX != _LBPair.getTokenX()) revert LBRouter__WrongTokenOrder();

        if (liquidityParameters.tokenX == _wnative && liquidityParameters.amountX == msg.value) {
            _wnativeDepositAndTransfer(address(_LBPair), msg.value);
            liquidityParameters.tokenY.safeTransferFrom(msg.sender, address(_LBPair), liquidityParameters.amountY);
        } else if (liquidityParameters.tokenY == _wnative && liquidityParameters.amountY == msg.value) {
            liquidityParameters.tokenX.safeTransferFrom(msg.sender, address(_LBPair), liquidityParameters.amountX);
            _wnativeDepositAndTransfer(address(_LBPair), msg.value);
        } else {
            revert LBRouter__WrongNativeLiquidityParameters(
                address(liquidityParameters.tokenX),
                address(liquidityParameters.tokenY),
                liquidityParameters.amountX,
                liquidityParameters.amountY,
                msg.value
            );
        }

        (amountXAdded, amountYAdded, amountXLeft, amountYLeft, depositIds, liquidityMinted) =
            _addLiquidity(liquidityParameters, _LBPair);
    }

    /**
     * @notice Remove liquidity while performing safety checks
     * @dev This function is compliant with fee on transfer tokens
     * @param tokenX The address of token X
     * @param tokenY The address of token Y
     * @param binStep The bin step of the LBPair
     * @param amountXMin The min amount to receive of token X
     * @param amountYMin The min amount to receive of token Y
     * @param ids The list of ids to burn
     * @param amounts The list of amounts to burn of each id in `_ids`
     * @param to The address of the recipient
     * @param deadline The deadline of the tx
     * @return amountX Amount of token X returned
     * @return amountY Amount of token Y returned
     */
    function removeLiquidity(
        IERC20 tokenX,
        IERC20 tokenY,
        uint16 binStep,
        uint256 amountXMin,
        uint256 amountYMin,
        uint256[] memory ids,
        uint256[] memory amounts,
        address to,
        uint256 deadline
    ) external override ensure(deadline) returns (uint256 amountX, uint256 amountY) {
        ILBPair _LBPair = ILBPair(_getLBPairInformation(tokenX, tokenY, binStep, Version.V2_1));
        bool isWrongOrder = tokenX != _LBPair.getTokenX();

        if (isWrongOrder) (amountXMin, amountYMin) = (amountYMin, amountXMin);

        (amountX, amountY) = _removeLiquidity(_LBPair, amountXMin, amountYMin, ids, amounts, to);

        if (isWrongOrder) (amountX, amountY) = (amountY, amountX);
    }

    /**
     * @notice Remove NATIVE liquidity while performing safety checks
     * @dev This function is **NOT** compliant with fee on transfer tokens.
     * This is wanted as it would make users pays the fee on transfer twice,
     * use the `removeLiquidity` function to remove liquidity with fee on transfer tokens.
     * @param token The address of token
     * @param binStep The bin step of the LBPair
     * @param amountTokenMin The min amount to receive of token
     * @param amountNATIVEMin The min amount to receive of NATIVE
     * @param ids The list of ids to burn
     * @param amounts The list of amounts to burn of each id in `_ids`
     * @param to The address of the recipient
     * @param deadline The deadline of the tx
     * @return amountToken Amount of token returned
     * @return amountNATIVE Amount of NATIVE returned
     */
    function removeLiquidityNATIVE(
        IERC20 token,
        uint16 binStep,
        uint256 amountTokenMin,
        uint256 amountNATIVEMin,
        uint256[] memory ids,
        uint256[] memory amounts,
        address payable to,
        uint256 deadline
    ) external override ensure(deadline) returns (uint256 amountToken, uint256 amountNATIVE) {
        IWNATIVE wnative = _wnative;

        ILBPair lbPair = ILBPair(_getLBPairInformation(token, IERC20(wnative), binStep, Version.V2_1));

        {
            bool isNATIVETokenY = IERC20(wnative) == lbPair.getTokenY();

            if (!isNATIVETokenY) {
                (amountTokenMin, amountNATIVEMin) = (amountNATIVEMin, amountTokenMin);
            }

            (uint256 amountX, uint256 amountY) =
                _removeLiquidity(lbPair, amountTokenMin, amountNATIVEMin, ids, amounts, address(this));

            (amountToken, amountNATIVE) = isNATIVETokenY ? (amountX, amountY) : (amountY, amountX);
        }

        token.safeTransfer(to, amountToken);

        wnative.withdraw(amountNATIVE);
        _safeTransferNATIVE(to, amountNATIVE);
    }

    /**
     * @notice Swaps exact tokens for tokens while performing safety checks
     * @param amountIn The amount of token to send
     * @param amountOutMin The min amount of token to receive
     * @param path The path of the swap
     * @param to The address of the recipient
     * @param deadline The deadline of the tx
     * @return amountOut Output amount of the swap
     */
    function swapExactTokensForTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Path memory path,
        address to,
        uint256 deadline
    ) external override ensure(deadline) verifyPathValidity(path) returns (uint256 amountOut) {
        address[] memory pairs = _getPairs(path.pairBinSteps, path.versions, path.tokenPath);

        path.tokenPath[0].safeTransferFrom(msg.sender, pairs[0], amountIn);

        amountOut = _swapExactTokensForTokens(amountIn, pairs, path.versions, path.tokenPath, to);

        if (amountOutMin > amountOut) revert LBRouter__InsufficientAmountOut(amountOutMin, amountOut);
    }

    /**
     * @notice Swaps exact tokens for NATIVE while performing safety checks
     * @param amountIn The amount of token to send
     * @param amountOutMinNATIVE The min amount of NATIVE to receive
     * @param path The path of the swap
     * @param to The address of the recipient
     * @param deadline The deadline of the tx
     * @return amountOut Output amount of the swap
     */
    function swapExactTokensForNATIVE(
        uint256 amountIn,
        uint256 amountOutMinNATIVE,
        Path memory path,
        address payable to,
        uint256 deadline
    ) external override ensure(deadline) verifyPathValidity(path) returns (uint256 amountOut) {
        if (path.tokenPath[path.pairBinSteps.length] != IERC20(_wnative)) {
            revert LBRouter__InvalidTokenPath(address(path.tokenPath[path.pairBinSteps.length]));
        }

        address[] memory pairs = _getPairs(path.pairBinSteps, path.versions, path.tokenPath);

        path.tokenPath[0].safeTransferFrom(msg.sender, pairs[0], amountIn);

        amountOut = _swapExactTokensForTokens(amountIn, pairs, path.versions, path.tokenPath, address(this));

        if (amountOutMinNATIVE > amountOut) revert LBRouter__InsufficientAmountOut(amountOutMinNATIVE, amountOut);

        _wnative.withdraw(amountOut);
        _safeTransferNATIVE(to, amountOut);
    }

    /**
     * @notice Swaps exact NATIVE for tokens while performing safety checks
     * @param amountOutMin The min amount of token to receive
     * @param path The path of the swap
     * @param to The address of the recipient
     * @param deadline The deadline of the tx
     * @return amountOut Output amount of the swap
     */
    function swapExactNATIVEForTokens(uint256 amountOutMin, Path memory path, address to, uint256 deadline)
        external
        payable
        override
        ensure(deadline)
        verifyPathValidity(path)
        returns (uint256 amountOut)
    {
        if (path.tokenPath[0] != IERC20(_wnative)) revert LBRouter__InvalidTokenPath(address(path.tokenPath[0]));

        address[] memory pairs = _getPairs(path.pairBinSteps, path.versions, path.tokenPath);

        _wnativeDepositAndTransfer(pairs[0], msg.value);

        amountOut = _swapExactTokensForTokens(msg.value, pairs, path.versions, path.tokenPath, to);

        if (amountOutMin > amountOut) revert LBRouter__InsufficientAmountOut(amountOutMin, amountOut);
    }

    /**
     * @notice Swaps tokens for exact tokens while performing safety checks
     * @param amountOut The amount of token to receive
     * @param amountInMax The max amount of token to send
     * @param path The path of the swap
     * @param to The address of the recipient
     * @param deadline The deadline of the tx
     * @return amountsIn Input amounts of the swap
     */
    function swapTokensForExactTokens(
        uint256 amountOut,
        uint256 amountInMax,
        Path memory path,
        address to,
        uint256 deadline
    ) external override ensure(deadline) verifyPathValidity(path) returns (uint256[] memory amountsIn) {
        address[] memory pairs = _getPairs(path.pairBinSteps, path.versions, path.tokenPath);

        {
            amountsIn = _getAmountsIn(path.versions, pairs, path.tokenPath, amountOut);

            if (amountsIn[0] > amountInMax) revert LBRouter__MaxAmountInExceeded(amountInMax, amountsIn[0]);

            path.tokenPath[0].safeTransferFrom(msg.sender, pairs[0], amountsIn[0]);

            uint256 _amountOutReal = _swapTokensForExactTokens(pairs, path.versions, path.tokenPath, amountsIn, to);

            if (_amountOutReal < amountOut) revert LBRouter__InsufficientAmountOut(amountOut, _amountOutReal);
        }
    }

    /**
     * @notice Swaps tokens for exact NATIVE while performing safety checks
     * @param amountNATIVEOut The amount of NATIVE to receive
     * @param amountInMax The max amount of token to send
     * @param path The path of the swap
     * @param to The address of the recipient
     * @param deadline The deadline of the tx
     * @return amountsIn path amounts for every step of the swap
     */
    function swapTokensForExactNATIVE(
        uint256 amountNATIVEOut,
        uint256 amountInMax,
        Path memory path,
        address payable to,
        uint256 deadline
    ) external override ensure(deadline) verifyPathValidity(path) returns (uint256[] memory amountsIn) {
        if (path.tokenPath[path.pairBinSteps.length] != IERC20(_wnative)) {
            revert LBRouter__InvalidTokenPath(address(path.tokenPath[path.pairBinSteps.length]));
        }

        address[] memory pairs = _getPairs(path.pairBinSteps, path.versions, path.tokenPath);
        amountsIn = _getAmountsIn(path.versions, pairs, path.tokenPath, amountNATIVEOut);

        if (amountsIn[0] > amountInMax) revert LBRouter__MaxAmountInExceeded(amountInMax, amountsIn[0]);

        path.tokenPath[0].safeTransferFrom(msg.sender, pairs[0], amountsIn[0]);

        uint256 _amountOutReal =
            _swapTokensForExactTokens(pairs, path.versions, path.tokenPath, amountsIn, address(this));

        if (_amountOutReal < amountNATIVEOut) revert LBRouter__InsufficientAmountOut(amountNATIVEOut, _amountOutReal);

        _wnative.withdraw(_amountOutReal);
        _safeTransferNATIVE(to, _amountOutReal);
    }

    /**
     * @notice Swaps NATIVE for exact tokens while performing safety checks
     * @dev Will refund any NATIVE amount sent in excess to `msg.sender`
     * @param amountOut The amount of tokens to receive
     * @param path The path of the swap
     * @param to The address of the recipient
     * @param deadline The deadline of the tx
     * @return amountsIn path amounts for every step of the swap
     */
    function swapNATIVEForExactTokens(uint256 amountOut, Path memory path, address to, uint256 deadline)
        external
        payable
        override
        ensure(deadline)
        verifyPathValidity(path)
        returns (uint256[] memory amountsIn)
    {
        if (path.tokenPath[0] != IERC20(_wnative)) revert LBRouter__InvalidTokenPath(address(path.tokenPath[0]));

        address[] memory pairs = _getPairs(path.pairBinSteps, path.versions, path.tokenPath);
        amountsIn = _getAmountsIn(path.versions, pairs, path.tokenPath, amountOut);

        if (amountsIn[0] > msg.value) revert LBRouter__MaxAmountInExceeded(msg.value, amountsIn[0]);

        _wnativeDepositAndTransfer(pairs[0], amountsIn[0]);

        uint256 amountOutReal = _swapTokensForExactTokens(pairs, path.versions, path.tokenPath, amountsIn, to);

        if (amountOutReal < amountOut) revert LBRouter__InsufficientAmountOut(amountOut, amountOutReal);

        if (msg.value > amountsIn[0]) _safeTransferNATIVE(msg.sender, msg.value - amountsIn[0]);
    }

    /**
     * @notice Swaps exact tokens for tokens while performing safety checks supporting for fee on transfer tokens
     * @param amountIn The amount of token to send
     * @param amountOutMin The min amount of token to receive
     * @param path The path of the swap
     * @param to The address of the recipient
     * @param deadline The deadline of the tx
     * @return amountOut Output amount of the swap
     */
    function swapExactTokensForTokensSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        Path memory path,
        address to,
        uint256 deadline
    ) external override ensure(deadline) verifyPathValidity(path) returns (uint256 amountOut) {
        address[] memory pairs = _getPairs(path.pairBinSteps, path.versions, path.tokenPath);

        IERC20 targetToken = path.tokenPath[pairs.length];

        uint256 balanceBefore = targetToken.balanceOf(to);

        path.tokenPath[0].safeTransferFrom(msg.sender, pairs[0], amountIn);

        _swapSupportingFeeOnTransferTokens(pairs, path.versions, path.tokenPath, to);

        amountOut = targetToken.balanceOf(to) - balanceBefore;
        if (amountOutMin > amountOut) revert LBRouter__InsufficientAmountOut(amountOutMin, amountOut);
    }

    /**
     * @notice Swaps exact tokens for NATIVE while performing safety checks supporting for fee on transfer tokens
     * @param amountIn The amount of token to send
     * @param amountOutMinNATIVE The min amount of NATIVE to receive
     * @param path The path of the swap
     * @param to The address of the recipient
     * @param deadline The deadline of the tx
     * @return amountOut Output amount of the swap
     */
    function swapExactTokensForNATIVESupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMinNATIVE,
        Path memory path,
        address payable to,
        uint256 deadline
    ) external override ensure(deadline) verifyPathValidity(path) returns (uint256 amountOut) {
        if (path.tokenPath[path.pairBinSteps.length] != IERC20(_wnative)) {
            revert LBRouter__InvalidTokenPath(address(path.tokenPath[path.pairBinSteps.length]));
        }

        address[] memory pairs = _getPairs(path.pairBinSteps, path.versions, path.tokenPath);

        uint256 balanceBefore = _wnative.balanceOf(address(this));

        path.tokenPath[0].safeTransferFrom(msg.sender, pairs[0], amountIn);

        _swapSupportingFeeOnTransferTokens(pairs, path.versions, path.tokenPath, address(this));

        amountOut = _wnative.balanceOf(address(this)) - balanceBefore;
        if (amountOutMinNATIVE > amountOut) revert LBRouter__InsufficientAmountOut(amountOutMinNATIVE, amountOut);

        _wnative.withdraw(amountOut);
        _safeTransferNATIVE(to, amountOut);
    }

    /**
     * @notice Swaps exact NATIVE for tokens while performing safety checks supporting for fee on transfer tokens
     * @param amountOutMin The min amount of token to receive
     * @param path The path of the swap
     * @param to The address of the recipient
     * @param deadline The deadline of the tx
     * @return amountOut Output amount of the swap
     */
    function swapExactNATIVEForTokensSupportingFeeOnTransferTokens(
        uint256 amountOutMin,
        Path memory path,
        address to,
        uint256 deadline
    ) external payable override ensure(deadline) verifyPathValidity(path) returns (uint256 amountOut) {
        if (path.tokenPath[0] != IERC20(_wnative)) revert LBRouter__InvalidTokenPath(address(path.tokenPath[0]));

        address[] memory pairs = _getPairs(path.pairBinSteps, path.versions, path.tokenPath);

        IERC20 targetToken = path.tokenPath[pairs.length];

        uint256 balanceBefore = targetToken.balanceOf(to);

        _wnativeDepositAndTransfer(pairs[0], msg.value);

        _swapSupportingFeeOnTransferTokens(pairs, path.versions, path.tokenPath, to);

        amountOut = targetToken.balanceOf(to) - balanceBefore;
        if (amountOutMin > amountOut) revert LBRouter__InsufficientAmountOut(amountOutMin, amountOut);
    }

    /**
     * @notice Unstuck tokens that are sent to this contract by mistake
     * @dev Only callable by the factory owner
     * @param token The address of the token
     * @param to The address of the user to send back the tokens
     * @param amount The amount to send
     */
    function sweep(IERC20 token, address to, uint256 amount) external override onlyFactoryOwner {
        if (address(token) == address(0)) {
            if (amount == type(uint256).max) amount = address(this).balance;
            _safeTransferNATIVE(to, amount);
        } else {
            if (amount == type(uint256).max) amount = token.balanceOf(address(this));
            token.safeTransfer(to, amount);
        }
    }

    /**
     * @notice Unstuck LBTokens that are sent to this contract by mistake
     * @dev Only callable by the factory owner
     * @param lbToken The address of the LBToken
     * @param to The address of the user to send back the tokens
     * @param ids The list of token ids
     * @param amounts The list of amounts to send
     */
    function sweepLBToken(ILBToken lbToken, address to, uint256[] calldata ids, uint256[] calldata amounts)
        external
        override
        onlyFactoryOwner
    {
        lbToken.batchTransferFrom(address(this), to, ids, amounts);
    }

    /**
     * @notice Helper function to add liquidity
     * @param liq The liquidity parameter
     * @param pair LBPair where liquidity is deposited
     * @return amountXAdded Amount of token X added
     * @return amountYAdded Amount of token Y added
     * @return amountXLeft Amount of token X left
     * @return amountYLeft Amount of token Y left
     * @return depositIds The list of deposit ids
     * @return liquidityMinted The list of liquidity minted
     */
    function _addLiquidity(LiquidityParameters calldata liq, ILBPair pair)
        private
        ensure(liq.deadline)
        returns (
            uint256 amountXAdded,
            uint256 amountYAdded,
            uint256 amountXLeft,
            uint256 amountYLeft,
            uint256[] memory depositIds,
            uint256[] memory liquidityMinted
        )
    {
        unchecked {
            if (liq.deltaIds.length != liq.distributionX.length || liq.deltaIds.length != liq.distributionY.length) {
                revert LBRouter__LengthsMismatch();
            }

            if (liq.activeIdDesired > type(uint24).max || liq.idSlippage > type(uint24).max) {
                revert LBRouter__IdDesiredOverflows(liq.activeIdDesired, liq.idSlippage);
            }

            bytes32[] memory liquidityConfigs = new bytes32[](liq.deltaIds.length);
            depositIds = new uint256[](liq.deltaIds.length);
            {
                uint256 _activeId = pair.getActiveId();
                if (
                    liq.activeIdDesired + liq.idSlippage < _activeId || _activeId + liq.idSlippage < liq.activeIdDesired
                ) {
                    revert LBRouter__IdSlippageCaught(liq.activeIdDesired, liq.idSlippage, _activeId);
                }

                for (uint256 i; i < liquidityConfigs.length; ++i) {
                    int256 _id = int256(_activeId) + liq.deltaIds[i];

                    if (_id < 0 || uint256(_id) > type(uint24).max) revert LBRouter__IdOverflows(_id);
                    depositIds[i] = uint256(_id);
                    liquidityConfigs[i] = LiquidityConfigurations.encodeParams(
                        uint64(liq.distributionX[i]), uint64(liq.distributionY[i]), uint24(uint256(_id))
                    );
                }
            }

            bytes32 amountsReceived;
            bytes32 amountsLeft;
            (amountsReceived, amountsLeft, liquidityMinted) = pair.mint(liq.to, liquidityConfigs, liq.refundTo);

            amountXAdded = amountsReceived.decodeX();
            amountYAdded = amountsReceived.decodeY();

            if (amountXAdded < liq.amountXMin || amountYAdded < liq.amountYMin) {
                revert LBRouter__AmountSlippageCaught(liq.amountXMin, amountXAdded, liq.amountYMin, amountYAdded);
            }

            amountXLeft = amountsLeft.decodeX();
            amountYLeft = amountsLeft.decodeY();
        }
    }

    /**
     * @notice Helper function to return the amounts in
     * @param versions The list of versions (V1, V2 or V2_1)
     * @param pairs The list of pairs
     * @param tokenPath The swap path
     * @param amountOut The amount out
     * @return amountsIn The list of amounts in
     */
    function _getAmountsIn(
        Version[] memory versions,
        address[] memory pairs,
        IERC20[] memory tokenPath,
        uint256 amountOut
    ) private view returns (uint256[] memory amountsIn) {
        amountsIn = new uint256[](tokenPath.length);
        // Avoid doing -1, as `pairs.length == pairBinSteps.length-1`
        amountsIn[pairs.length] = amountOut;

        for (uint256 i = pairs.length; i != 0; i--) {
            IERC20 token = tokenPath[i - 1];
            Version version = versions[i - 1];
            address pair = pairs[i - 1];

            if (version == Version.V1) {
                (uint256 reserveIn, uint256 reserveOut,) = IJoePair(pair).getReserves();
                if (token > tokenPath[i]) {
                    (reserveIn, reserveOut) = (reserveOut, reserveIn);
                }

                uint256 amountOut_ = amountsIn[i];
                amountsIn[i - 1] = uint128(amountOut_.getAmountIn(reserveIn, reserveOut));
            } else if (version == Version.V2) {
                (amountsIn[i - 1],) = _legacyRouter.getSwapIn(
                    ILBLegacyPair(pair), uint128(amountsIn[i]), ILBLegacyPair(pair).tokenX() == token
                );
            } else {
                (amountsIn[i - 1],,) =
                    getSwapIn(ILBPair(pair), uint128(amountsIn[i]), ILBPair(pair).getTokenX() == token);
            }
        }
    }

    /**
     * @notice Helper function to remove liquidity
     * @param pair The address of the LBPair
     * @param amountXMin The min amount to receive of token X
     * @param amountYMin The min amount to receive of token Y
     * @param ids The list of ids to burn
     * @param amounts The list of amounts to burn of each id in `_ids`
     * @param to The address of the recipient
     * @return amountX The amount of token X sent by the pair
     * @return amountY The amount of token Y sent by the pair
     */
    function _removeLiquidity(
        ILBPair pair,
        uint256 amountXMin,
        uint256 amountYMin,
        uint256[] memory ids,
        uint256[] memory amounts,
        address to
    ) private returns (uint256 amountX, uint256 amountY) {
        (bytes32[] memory amountsBurned) = pair.burn(msg.sender, to, ids, amounts);

        for (uint256 i; i < amountsBurned.length; ++i) {
            amountX += amountsBurned[i].decodeX();
            amountY += amountsBurned[i].decodeY();
        }

        if (amountX < amountXMin || amountY < amountYMin) {
            revert LBRouter__AmountSlippageCaught(amountXMin, amountX, amountYMin, amountY);
        }
    }

    /**
     * @notice Helper function to swap exact tokens for tokens
     * @param amountIn The amount of token sent
     * @param pairs The list of pairs
     * @param versions The list of versions (V1, V2 or V2_1)
     * @param tokenPath The swap path using the binSteps following `pairBinSteps`
     * @param to The address of the recipient
     * @return amountOut The amount of token sent to `to`
     */
    function _swapExactTokensForTokens(
        uint256 amountIn,
        address[] memory pairs,
        Version[] memory versions,
        IERC20[] memory tokenPath,
        address to
    ) private returns (uint256 amountOut) {
        IERC20 token;
        Version version;
        address recipient;
        address pair;

        IERC20 tokenNext = tokenPath[0];
        amountOut = amountIn;

        unchecked {
            for (uint256 i; i < pairs.length; ++i) {
                pair = pairs[i];
                version = versions[i];

                token = tokenNext;
                tokenNext = tokenPath[i + 1];

                recipient = i + 1 == pairs.length ? to : pairs[i + 1];

                if (version == Version.V1) {
                    (uint256 reserve0, uint256 reserve1,) = IJoePair(pair).getReserves();

                    if (token < tokenNext) {
                        amountOut = amountOut.getAmountOut(reserve0, reserve1);
                        IJoePair(pair).swap(0, amountOut, recipient, "");
                    } else {
                        amountOut = amountOut.getAmountOut(reserve1, reserve0);
                        IJoePair(pair).swap(amountOut, 0, recipient, "");
                    }
                } else if (version == Version.V2) {
                    bool swapForY = tokenNext == ILBLegacyPair(pair).tokenY();

                    (uint256 amountXOut, uint256 amountYOut) = ILBLegacyPair(pair).swap(swapForY, recipient);

                    if (swapForY) amountOut = amountYOut;
                    else amountOut = amountXOut;
                } else {
                    bool swapForY = tokenNext == ILBPair(pair).getTokenY();

                    (uint256 amountXOut, uint256 amountYOut) = ILBPair(pair).swap(swapForY, recipient).decode();

                    if (swapForY) amountOut = amountYOut;
                    else amountOut = amountXOut;
                }
            }
        }
    }

    /**
     * @notice Helper function to swap tokens for exact tokens
     * @param pairs The array of pairs
     * @param versions The list of versions (V1, V2 or V2_1)
     * @param tokenPath The swap path using the binSteps following `pairBinSteps`
     * @param amountsIn The list of amounts in
     * @param to The address of the recipient
     * @return amountOut The amount of token sent to `to`
     */
    function _swapTokensForExactTokens(
        address[] memory pairs,
        Version[] memory versions,
        IERC20[] memory tokenPath,
        uint256[] memory amountsIn,
        address to
    ) private returns (uint256 amountOut) {
        IERC20 token;
        address recipient;
        address pair;
        Version version;

        IERC20 tokenNext = tokenPath[0];

        unchecked {
            for (uint256 i; i < pairs.length; ++i) {
                pair = pairs[i];
                version = versions[i];

                token = tokenNext;
                tokenNext = tokenPath[i + 1];

                recipient = i + 1 == pairs.length ? to : pairs[i + 1];

                if (version == Version.V1) {
                    amountOut = amountsIn[i + 1];
                    if (token < tokenNext) {
                        IJoePair(pair).swap(0, amountOut, recipient, "");
                    } else {
                        IJoePair(pair).swap(amountOut, 0, recipient, "");
                    }
                } else if (version == Version.V2) {
                    bool swapForY = tokenNext == ILBLegacyPair(pair).tokenY();

                    (uint256 amountXOut, uint256 amountYOut) = ILBLegacyPair(pair).swap(swapForY, recipient);

                    if (swapForY) amountOut = amountYOut;
                    else amountOut = amountXOut;
                } else {
                    bool swapForY = tokenNext == ILBPair(pair).getTokenY();

                    (uint256 amountXOut, uint256 amountYOut) = ILBPair(pair).swap(swapForY, recipient).decode();

                    if (swapForY) amountOut = amountYOut;
                    else amountOut = amountXOut;
                }
            }
        }
    }

    /**
     * @notice Helper function to swap exact tokens supporting for fee on transfer tokens
     * @param pairs The list of pairs
     * @param versions The list of versions (V1, V2 or V2_1)
     * @param tokenPath The swap path using the binSteps following `pairBinSteps`
     * @param to The address of the recipient
     */
    function _swapSupportingFeeOnTransferTokens(
        address[] memory pairs,
        Version[] memory versions,
        IERC20[] memory tokenPath,
        address to
    ) private {
        IERC20 token;
        Version version;
        address recipient;
        address pair;

        IERC20 tokenNext = tokenPath[0];

        unchecked {
            for (uint256 i; i < pairs.length; ++i) {
                pair = pairs[i];
                version = versions[i];

                token = tokenNext;
                tokenNext = tokenPath[i + 1];

                recipient = i + 1 == pairs.length ? to : pairs[i + 1];

                if (version == Version.V1) {
                    (uint256 _reserve0, uint256 _reserve1,) = IJoePair(pair).getReserves();
                    if (token < tokenNext) {
                        uint256 amountIn = token.balanceOf(pair) - _reserve0;
                        uint256 amountOut = amountIn.getAmountOut(_reserve0, _reserve1);

                        IJoePair(pair).swap(0, amountOut, recipient, "");
                    } else {
                        uint256 amountIn = token.balanceOf(pair) - _reserve1;
                        uint256 amountOut = amountIn.getAmountOut(_reserve1, _reserve0);

                        IJoePair(pair).swap(amountOut, 0, recipient, "");
                    }
                } else if (version == Version.V2) {
                    ILBLegacyPair(pair).swap(tokenNext == ILBLegacyPair(pair).tokenY(), recipient);
                } else {
                    ILBPair(pair).swap(tokenNext == ILBPair(pair).getTokenY(), recipient);
                }
            }
        }
    }

    /**
     * @notice Helper function to return the address of the LBPair
     * @dev Revert if the pair is not created yet
     * @param tokenX The address of the tokenX
     * @param tokenY The address of the tokenY
     * @param binStep The bin step of the LBPair
     * @param version The version of the LBPair
     * @return lbPair The address of the LBPair
     */
    function _getLBPairInformation(IERC20 tokenX, IERC20 tokenY, uint256 binStep, Version version)
        private
        view
        returns (address lbPair)
    {
        if (version == Version.V2) {
            lbPair = address(_legacyFactory.getLBPairInformation(tokenX, tokenY, binStep).LBPair);
        } else {
            lbPair = address(_factory.getLBPairInformation(tokenX, tokenY, binStep).LBPair);
        }

        if (lbPair == address(0)) {
            revert LBRouter__PairNotCreated(address(tokenX), address(tokenY), binStep);
        }
    }

    /**
     * @notice Helper function to return the address of the pair (v1 or v2, according to `binStep`)
     * @dev Revert if the pair is not created yet
     * @param tokenX The address of the tokenX
     * @param tokenY The address of the tokenY
     * @param binStep The bin step of the LBPair
     * @param version The version of the LBPair
     * @return pair The address of the pair of binStep `binStep`
     */
    function _getPair(IERC20 tokenX, IERC20 tokenY, uint256 binStep, Version version)
        private
        view
        returns (address pair)
    {
        if (version == Version.V1) {
            pair = _factoryV1.getPair(address(tokenX), address(tokenY));
            if (pair == address(0)) revert LBRouter__PairNotCreated(address(tokenX), address(tokenY), binStep);
        } else {
            pair = address(_getLBPairInformation(tokenX, tokenY, binStep, version));
        }
    }

    /**
     * @notice Helper function to return a list of pairs
     * @param pairBinSteps The list of bin steps
     * @param versions The list of versions (V1, V2 or V2_1)
     * @param tokenPath The swap path using the binSteps following `pairBinSteps`
     * @return pairs The list of pairs
     */
    function _getPairs(uint256[] memory pairBinSteps, Version[] memory versions, IERC20[] memory tokenPath)
        private
        view
        returns (address[] memory pairs)
    {
        pairs = new address[](pairBinSteps.length);

        IERC20 token;
        IERC20 tokenNext = tokenPath[0];
        unchecked {
            for (uint256 i; i < pairs.length; ++i) {
                token = tokenNext;
                tokenNext = tokenPath[i + 1];

                pairs[i] = _getPair(token, tokenNext, pairBinSteps[i], versions[i]);
            }
        }
    }

    /**
     * @notice Helper function to transfer NATIVE
     * @param to The address of the recipient
     * @param amount The NATIVE amount to send
     */
    function _safeTransferNATIVE(address to, uint256 amount) private {
        (bool success,) = to.call{value: amount}("");
        if (!success) revert LBRouter__FailedToSendNATIVE(to, amount);
    }

    /**
     * @notice Helper function to deposit and transfer _wnative
     * @param to The address of the recipient
     * @param amount The NATIVE amount to wrap
     */
    function _wnativeDepositAndTransfer(address to, uint256 amount) private {
        _wnative.deposit{value: amount}();
        _wnative.safeTransfer(to, amount);
    }
}
