// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {IERC20} from "openzeppelin/token/ERC20/IERC20.sol";

import {Constants} from "./libraries/Constants.sol";
import {JoeLibrary} from "./libraries/JoeLibrary.sol";
import {PriceHelper} from "./libraries/PriceHelper.sol";
import {Uint256x256Math} from "./libraries/math/Uint256x256Math.sol";
import {SafeCast} from "./libraries/math/SafeCast.sol";

import {IJoeFactory} from "./interfaces/IJoeFactory.sol";
import {ILBFactory} from "./interfaces/ILBFactory.sol";
import {ILBLegacyFactory} from "./interfaces/ILBLegacyFactory.sol";
import {ILBLegacyRouter} from "./interfaces/ILBLegacyRouter.sol";
import {IJoePair} from "./interfaces/IJoePair.sol";
import {ILBLegacyPair} from "./interfaces/ILBLegacyPair.sol";
import {ILBPair} from "./interfaces/ILBPair.sol";
import {ILBRouter} from "./interfaces/ILBRouter.sol";

/**
 * @title Liquidity Book Quoter
 * @author Trader Joe
 * @notice Helper contract to determine best path through multiple markets
 */
contract LBQuoter {
    using Uint256x256Math for uint256;
    using SafeCast for uint256;

    error LBQuoter_InvalidLength();

    address private immutable _factoryV1;
    address private immutable _legacyFactoryV2;
    address private immutable _factoryV2;
    address private immutable _legacyRouterV2;
    address private immutable _routerV2;

    /**
     * @dev The quote struct returned by the quoter
     * - route: address array of the token to go through
     * - pairs: address array of the pairs to go through
     * - binSteps: The bin step to use for each pair
     * - versions: The version to use for each pair
     * - amounts: The amounts of every step of the swap
     * - virtualAmountsWithoutSlippage: The virtual amounts of every step of the swap without slippage
     * - fees: The fees to pay for every step of the swap
     */
    struct Quote {
        address[] route;
        address[] pairs;
        uint256[] binSteps;
        ILBRouter.Version[] versions;
        uint128[] amounts;
        uint128[] virtualAmountsWithoutSlippage;
        uint128[] fees;
    }

    /**
     * @notice Constructor
     * @param factoryV1 Dex V1 factory address
     * @param legacyFactoryV2 Dex V2 factory address
     * @param factoryV2 Dex V2.1 factory address
     * @param legacyRouterV2 Dex V2 router address
     * @param routerV2 Dex V2 router address
     */
    constructor(
        address factoryV1,
        address legacyFactoryV2,
        address factoryV2,
        address legacyRouterV2,
        address routerV2
    ) {
        _factoryV1 = factoryV1;
        _legacyFactoryV2 = legacyFactoryV2;
        _factoryV2 = factoryV2;
        _routerV2 = routerV2;
        _legacyRouterV2 = legacyRouterV2;
    }

    /**
     * @notice Returns the Dex V1 factory address
     * @return factoryV1 Dex V1 factory address
     */
    function getFactoryV1() public view returns (address factoryV1) {
        factoryV1 = _factoryV1;
    }

    /**
     * @notice Returns the Dex V2 factory address
     * @return legacyFactoryV2 Dex V2 factory address
     */
    function getLegacyFactoryV2() public view returns (address legacyFactoryV2) {
        legacyFactoryV2 = _legacyFactoryV2;
    }

    /**
     * @notice Returns the Dex V2.1 factory address
     * @return factoryV2 Dex V2.1 factory address
     */
    function getFactoryV2() public view returns (address factoryV2) {
        factoryV2 = _factoryV2;
    }

    /**
     * @notice Returns the Dex V2 router address
     * @return legacyRouterV2 Dex V2 router address
     */
    function getLegacyRouterV2() public view returns (address legacyRouterV2) {
        legacyRouterV2 = _legacyRouterV2;
    }

    /**
     * @notice Returns the Dex V2 router address
     * @return routerV2 Dex V2 router address
     */
    function getRouterV2() public view returns (address routerV2) {
        routerV2 = _routerV2;
    }

    /**
     * @notice Finds the best path given a list of tokens and the input amount wanted from the swap
     * @param route List of the tokens to go through
     * @param amountIn Swap amount in
     * @return quote The Quote structure containing the necessary element to perform the swap
     */
    function findBestPathFromAmountIn(address[] calldata route, uint128 amountIn)
        public
        view
        returns (Quote memory quote)
    {
        if (route.length < 2) {
            revert LBQuoter_InvalidLength();
        }

        quote.route = route;

        uint256 swapLength = route.length - 1;
        quote.pairs = new address[](swapLength);
        quote.binSteps = new uint256[](swapLength);
        quote.versions = new ILBRouter.Version[](swapLength);
        quote.fees = new uint128[](swapLength);
        quote.amounts = new uint128[](route.length);
        quote.virtualAmountsWithoutSlippage = new uint128[](route.length);

        quote.amounts[0] = amountIn;
        quote.virtualAmountsWithoutSlippage[0] = amountIn;

        for (uint256 i; i < swapLength; i++) {
            // Fetch swap for V1
            quote.pairs[i] = IJoeFactory(_factoryV1).getPair(route[i], route[i + 1]);

            if (quote.pairs[i] != address(0) && quote.amounts[i] > 0) {
                (uint256 reserveIn, uint256 reserveOut) = _getReserves(quote.pairs[i], route[i], route[i + 1]);

                if (reserveIn > 0 && reserveOut > 0) {
                    quote.amounts[i + 1] = JoeLibrary.getAmountOut(quote.amounts[i], reserveIn, reserveOut).safe128();
                    quote.virtualAmountsWithoutSlippage[i + 1] = JoeLibrary.quote(
                        quote.virtualAmountsWithoutSlippage[i] * 997, reserveIn * 1000, reserveOut
                    ).safe128();
                    quote.fees[i] = 0.003e18; // 0.3%
                    quote.versions[i] = ILBRouter.Version.V1;
                }
            }

            // Fetch swap for V2
            ILBLegacyFactory.LBPairInformation[] memory legacyLBPairsAvailable =
                ILBLegacyFactory(_legacyFactoryV2).getAllLBPairs(IERC20(route[i]), IERC20(route[i + 1]));

            if (legacyLBPairsAvailable.length > 0 && quote.amounts[i] > 0) {
                for (uint256 j; j < legacyLBPairsAvailable.length; j++) {
                    if (!legacyLBPairsAvailable[j].ignoredForRouting) {
                        bool swapForY = address(legacyLBPairsAvailable[j].LBPair.tokenY()) == route[i + 1];
                        try ILBLegacyRouter(_legacyRouterV2).getSwapOut(
                            legacyLBPairsAvailable[j].LBPair, quote.amounts[i], swapForY
                        ) returns (uint256 swapAmountOut, uint256 fees) {
                            if (swapAmountOut > quote.amounts[i + 1]) {
                                quote.amounts[i + 1] = swapAmountOut.safe128();
                                quote.pairs[i] = address(legacyLBPairsAvailable[j].LBPair);
                                quote.binSteps[i] = legacyLBPairsAvailable[j].binStep;
                                quote.versions[i] = ILBRouter.Version.V2;

                                // Getting current price
                                (,, uint256 activeId) = legacyLBPairsAvailable[j].LBPair.getReservesAndId();
                                quote.virtualAmountsWithoutSlippage[i + 1] = _getV2Quote(
                                    quote.virtualAmountsWithoutSlippage[i] - fees,
                                    (activeId).safe24(),
                                    quote.binSteps[i],
                                    swapForY
                                );

                                quote.fees[i] = ((fees * 1e18) / quote.amounts[i]).safe128(); // fee percentage in amountIn
                            }
                        } catch {}
                    }
                }
            }

            // Fetch swaps for V2.1
            ILBFactory.LBPairInformation[] memory LBPairsAvailable =
                ILBFactory(_factoryV2).getAllLBPairs(IERC20(route[i]), IERC20(route[i + 1]));

            if (LBPairsAvailable.length > 0 && quote.amounts[i] > 0) {
                for (uint256 j; j < LBPairsAvailable.length; j++) {
                    if (!LBPairsAvailable[j].ignoredForRouting) {
                        bool swapForY = address(LBPairsAvailable[j].LBPair.getTokenY()) == route[i + 1];

                        try ILBRouter(_routerV2).getSwapOut(LBPairsAvailable[j].LBPair, quote.amounts[i], swapForY)
                        returns (uint128 amountInLeft, uint128 swapAmountOut, uint128 fees) {
                            if (amountInLeft == 0 && swapAmountOut > quote.amounts[i + 1]) {
                                quote.amounts[i + 1] = swapAmountOut;
                                quote.pairs[i] = address(LBPairsAvailable[j].LBPair);
                                quote.binSteps[i] = uint16(LBPairsAvailable[j].binStep);
                                quote.versions[i] = ILBRouter.Version.V2_1;

                                // Getting current price
                                uint24 activeId = LBPairsAvailable[j].LBPair.getActiveId();
                                quote.virtualAmountsWithoutSlippage[i + 1] = _getV2Quote(
                                    quote.virtualAmountsWithoutSlippage[i] - fees, activeId, quote.binSteps[i], swapForY
                                );

                                quote.fees[i] = ((uint256(fees) * 1e18) / quote.amounts[i]).safe128(); // fee percentage in amountIn
                            }
                        } catch {}
                    }
                }
            }
        }
    }

    /**
     * @notice Finds the best path given a list of tokens and the output amount wanted from the swap
     * @param route List of the tokens to go through
     * @param amountOut Swap amount out
     * @return quote The Quote structure containing the necessary element to perform the swap
     */
    function findBestPathFromAmountOut(address[] calldata route, uint128 amountOut)
        public
        view
        returns (Quote memory quote)
    {
        if (route.length < 2) {
            revert LBQuoter_InvalidLength();
        }
        quote.route = route;

        uint256 swapLength = route.length - 1;
        quote.pairs = new address[](swapLength);
        quote.binSteps = new uint256[](swapLength);
        quote.versions = new ILBRouter.Version[](swapLength);
        quote.fees = new uint128[](swapLength);
        quote.amounts = new uint128[](route.length);
        quote.virtualAmountsWithoutSlippage = new uint128[](route.length);

        quote.amounts[swapLength] = amountOut;
        quote.virtualAmountsWithoutSlippage[swapLength] = amountOut;

        for (uint256 i = swapLength; i > 0; i--) {
            // Fetch swap for V1
            quote.pairs[i - 1] = IJoeFactory(_factoryV1).getPair(route[i - 1], route[i]);
            if (quote.pairs[i - 1] != address(0) && quote.amounts[i] > 0) {
                (uint256 reserveIn, uint256 reserveOut) = _getReserves(quote.pairs[i - 1], route[i - 1], route[i]);

                if (reserveIn > 0 && reserveOut > quote.amounts[i]) {
                    quote.amounts[i - 1] = JoeLibrary.getAmountIn(quote.amounts[i], reserveIn, reserveOut).safe128();
                    quote.virtualAmountsWithoutSlippage[i - 1] = (
                        JoeLibrary.quote(quote.virtualAmountsWithoutSlippage[i] * 1000, reserveOut * 997, reserveIn) + 1
                    ).safe128();

                    quote.fees[i - 1] = 0.003e18; // 0.3%
                    quote.versions[i - 1] = ILBRouter.Version.V1;
                }
            }

            // Fetch swaps for V2
            ILBLegacyFactory.LBPairInformation[] memory legacyLBPairsAvailable =
                ILBLegacyFactory(_legacyFactoryV2).getAllLBPairs(IERC20(route[i - 1]), IERC20(route[i]));

            if (legacyLBPairsAvailable.length > 0 && quote.amounts[i] > 0) {
                for (uint256 j; j < legacyLBPairsAvailable.length; j++) {
                    if (!legacyLBPairsAvailable[j].ignoredForRouting) {
                        bool swapForY = address(legacyLBPairsAvailable[j].LBPair.tokenY()) == route[i];
                        try ILBLegacyRouter(_legacyRouterV2).getSwapIn(
                            legacyLBPairsAvailable[j].LBPair, quote.amounts[i], swapForY
                        ) returns (uint256 swapAmountIn, uint256 fees) {
                            if (swapAmountIn != 0 && (swapAmountIn < quote.amounts[i - 1] || quote.amounts[i - 1] == 0))
                            {
                                quote.amounts[i - 1] = (swapAmountIn).safe128();
                                quote.pairs[i - 1] = address(legacyLBPairsAvailable[j].LBPair);
                                quote.binSteps[i - 1] = legacyLBPairsAvailable[j].binStep;
                                quote.versions[i - 1] = ILBRouter.Version.V2;

                                // Getting current price
                                (,, uint256 activeId) = legacyLBPairsAvailable[j].LBPair.getReservesAndId();
                                quote.virtualAmountsWithoutSlippage[i - 1] = _getV2Quote(
                                    quote.virtualAmountsWithoutSlippage[i],
                                    uint24(activeId),
                                    quote.binSteps[i - 1],
                                    !swapForY
                                ) + fees.safe128();

                                quote.fees[i - 1] = ((fees * 1e18) / quote.amounts[i - 1]).safe128(); // fee percentage in amountIn
                            }
                        } catch {}
                    }
                }
            }

            // Fetch swaps for V2.1
            ILBFactory.LBPairInformation[] memory LBPairsAvailable;

            LBPairsAvailable = ILBFactory(_factoryV2).getAllLBPairs(IERC20(route[i - 1]), IERC20(route[i]));

            if (LBPairsAvailable.length > 0 && quote.amounts[i] > 0) {
                for (uint256 j; j < LBPairsAvailable.length; j++) {
                    if (!LBPairsAvailable[j].ignoredForRouting) {
                        bool swapForY = address(LBPairsAvailable[j].LBPair.getTokenY()) == route[i];
                        try ILBRouter(_routerV2).getSwapIn(LBPairsAvailable[j].LBPair, quote.amounts[i], swapForY)
                        returns (uint128 swapAmountIn, uint128 amountOutLeft, uint128 fees) {
                            if (
                                amountOutLeft == 0 && swapAmountIn != 0
                                    && (swapAmountIn < quote.amounts[i - 1] || quote.amounts[i - 1] == 0)
                            ) {
                                quote.amounts[i - 1] = swapAmountIn;
                                quote.pairs[i - 1] = address(LBPairsAvailable[j].LBPair);
                                quote.binSteps[i - 1] = uint16(LBPairsAvailable[j].binStep);
                                quote.versions[i - 1] = ILBRouter.Version.V2_1;

                                // Getting current price
                                uint24 activeId = LBPairsAvailable[j].LBPair.getActiveId();
                                quote.virtualAmountsWithoutSlippage[i - 1] = _getV2Quote(
                                    quote.virtualAmountsWithoutSlippage[i], activeId, quote.binSteps[i - 1], !swapForY
                                ) + fees;

                                quote.fees[i - 1] = ((uint256(fees) * 1e18) / quote.amounts[i - 1]).safe128(); // fee percentage in amountIn
                            }
                        } catch {}
                    }
                }
            }
        }
    }

    /**
     * @dev Forked from JoeLibrary
     * @dev Doesn't rely on the init code hash of the factory
     * @param pair Address of the pair
     * @param tokenA Address of token A
     * @param tokenB Address of token B
     * @return reserveA Reserve of token A in the pair
     * @return reserveB Reserve of token B in the pair
     */
    function _getReserves(address pair, address tokenA, address tokenB)
        internal
        view
        returns (uint256 reserveA, uint256 reserveB)
    {
        (address token0,) = JoeLibrary.sortTokens(tokenA, tokenB);
        (uint256 reserve0, uint256 reserve1,) = IJoePair(pair).getReserves();
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    /**
     * @dev Calculates a quote for a V2 pair
     * @param amount Amount in to consider
     * @param activeId Current active Id of the considred pair
     * @param binStep Bin step of the considered pair
     * @param swapForY Boolean describing if we are swapping from X to Y or the opposite
     * @return quote Amount Out if _amount was swapped with no slippage and no fees
     */
    function _getV2Quote(uint256 amount, uint24 activeId, uint256 binStep, bool swapForY)
        internal
        pure
        returns (uint128 quote)
    {
        if (swapForY) {
            quote = PriceHelper.getPriceFromId(activeId, uint16(binStep)).mulShiftRoundDown(
                amount, Constants.SCALE_OFFSET
            ).safe128();
        } else {
            quote = amount.shiftDivRoundDown(
                Constants.SCALE_OFFSET, PriceHelper.getPriceFromId(activeId, uint16(binStep))
            ).safe128();
        }
    }
}
