// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "../interfaces/mux/IMuxLiquidityPool.sol";

interface IChainlink {
    function latestAnswer() external view returns (int256);

    function latestTimestamp() external view returns (uint256);

    function latestRound() external view returns (uint256);

    function getAnswer(uint256 roundId) external view returns (int256);

    function getTimestamp(uint256 roundId) external view returns (uint256);

    event AnswerUpdated(int256 indexed current, uint256 indexed roundId, uint256 updatedAt);
    event NewRound(uint256 indexed roundId, address indexed startedBy, uint256 startedAt);
}

interface IChainlinkV3 {
    function decimals() external view returns (uint8);

    function description() external view returns (string memory);

    function version() external view returns (uint256);

    function getRoundData(
        uint80 _roundId
    )
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );

    function latestRoundData()
        external
        view
        returns (
            uint80 roundId,
            int256 answer,
            uint256 startedAt,
            uint256 updatedAt,
            uint80 answeredInRound
        );
}

interface IChainlinkV2V3 is IChainlink, IChainlinkV3 {}

enum SpreadType {
    Ask,
    Bid
}

enum ReferenceOracleType {
    None,
    Chainlink
}

library LibReferenceOracle {
    uint56 constant ASSET_IS_STRICT_STABLE = 0x01000000000000; // assetPrice is always 1 unless volatility exceeds strictStableDeviation

    // indicate that the asset price is too far away from reference oracle
    event AssetPriceOutOfRange(
        uint8 assetId,
        uint96 price,
        uint96 referencePrice,
        uint32 deviation
    );

    /**
     * @dev Check oracle parameters before set.
     */
    function checkParameters(
        ReferenceOracleType referenceOracleType,
        address referenceOracle,
        uint32 referenceDeviation
    ) internal view {
        require(referenceDeviation <= 1e5, "D>1"); // %deviation > 100%
        if (referenceOracleType == ReferenceOracleType.Chainlink) {
            IChainlinkV2V3 o = IChainlinkV2V3(referenceOracle);
            require(o.decimals() == 8, "!D8"); // we only support decimals = 8
            require(o.latestAnswer() > 0, "P=0"); // oracle Price <= 0
        }
    }

    /**
     * @dev Truncate price if the error is too large.
     */
    function checkPrice(
        IMuxLiquidityPool.Asset memory asset,
        uint96 price,
        uint32 strictStableDeviation
    ) internal view returns (uint96) {
        require(price != 0, "P=0"); // broker price = 0

        // truncate price if the error is too large
        if (ReferenceOracleType(asset.referenceOracleType) == ReferenceOracleType.Chainlink) {
            uint96 ref = _readChainlink(asset.referenceOracle);
            price = _truncatePrice(asset, price, ref);
        }

        // strict stable dampener
        if (isStrictStable(asset)) {
            uint256 delta = price > 1e18 ? price - 1e18 : 1e18 - price;
            uint256 dampener = uint256(strictStableDeviation) * 1e13; // 1e5 => 1e18
            if (delta <= dampener) {
                price = 1e18;
            }
        }

        return price;
    }

    function isStrictStable(IMuxLiquidityPool.Asset memory asset) internal pure returns (bool) {
        return (asset.flags & ASSET_IS_STRICT_STABLE) != 0;
    }

    /**
     * @dev check price and add spread, where spreadType should be:
     *
     *      subAccount.isLong   openPosition   closePosition   addLiquidity   removeLiquidity
     *      long                ask            bid
     *      short               bid            ask
     *      N/A                                                bid            ask
     */
    function checkPriceWithSpread(
        IMuxLiquidityPool.Asset memory asset,
        uint96 price,
        uint32 strictStableDeviation,
        SpreadType spreadType
    ) internal view returns (uint96) {
        price = checkPrice(asset, price, strictStableDeviation);
        price = _addSpread(asset, price, spreadType);
        return price;
    }

    function _readChainlink(address referenceOracle) internal view returns (uint96) {
        int256 ref = IChainlinkV2V3(referenceOracle).latestAnswer();
        require(ref > 0, "P=0"); // oracle Price <= 0
        ref *= 1e10; // decimals 8 => 18
        return safeUint96(uint256(ref));
    }

    function _truncatePrice(
        IMuxLiquidityPool.Asset memory asset,
        uint96 price,
        uint96 ref
    ) private pure returns (uint96) {
        if (asset.referenceDeviation == 0) {
            return ref;
        }
        uint256 deviation = (uint256(ref) * asset.referenceDeviation) / 1e5;
        uint96 bound = safeUint96(uint256(ref) - deviation);
        if (price < bound) {
            price = bound;
        }
        bound = safeUint96(uint256(ref) + deviation);
        if (price > bound) {
            price = bound;
        }
        return price;
    }

    function _addSpread(
        IMuxLiquidityPool.Asset memory asset,
        uint96 price,
        SpreadType spreadType
    ) private pure returns (uint96) {
        if (asset.halfSpread == 0) {
            return price;
        }
        uint96 halfSpread = safeUint96((uint256(price) * asset.halfSpread) / 1e5);
        if (spreadType == SpreadType.Bid) {
            require(price > halfSpread, "P=0"); // Price - halfSpread = 0. impossible
            return price - halfSpread;
        } else {
            return price + halfSpread;
        }
    }

    function safeUint96(uint256 n) internal pure returns (uint96) {
        require(n <= type(uint96).max, "O96"); // uint96 Overflow
        return uint96(n);
    }
}
