// SPDX-License-Identifier: MIT

pragma solidity ^0.8.10;

import {SampleMath} from "./math/SampleMath.sol";
import {SafeCast} from "./math/SafeCast.sol";
import {PairParameterHelper} from "./PairParameterHelper.sol";

/**
 * @title Liquidity Book Oracle Helper Library
 * @author Trader Joe
 * @notice This library contains functions to manage the oracle
 * The oracle samples are stored in a single bytes32 array.
 * Each sample is encoded as follows:
 * 0 - 16: oracle length (16 bits)
 * 16 - 80: cumulative id (64 bits)
 * 80 - 144: cumulative volatility accumulator (64 bits)
 * 144 - 208: cumulative bin crossed (64 bits)
 * 208 - 216: sample lifetime (8 bits)
 * 216 - 256: sample creation timestamp (40 bits)
 */
library OracleHelper {
    using SampleMath for bytes32;
    using SafeCast for uint256;
    using PairParameterHelper for bytes32;

    error OracleHelper__InvalidOracleId();
    error OracleHelper__NewLengthTooSmall();
    error OracleHelper__LookUpTimestampTooOld();

    struct Oracle {
        bytes32[65535] samples;
    }

    uint256 internal constant _MAX_SAMPLE_LIFETIME = 120 seconds;

    /**
     * @dev Modifier to check that the oracle id is valid
     * @param oracleId The oracle id
     */
    modifier checkOracleId(uint16 oracleId) {
        if (oracleId == 0) revert OracleHelper__InvalidOracleId();
        _;
    }

    /**
     * @dev Returns the sample at the given oracleId
     * @param oracle The oracle
     * @param oracleId The oracle id
     * @return sample The sample
     */
    function getSample(Oracle storage oracle, uint16 oracleId)
        internal
        view
        checkOracleId(oracleId)
        returns (bytes32 sample)
    {
        unchecked {
            sample = oracle.samples[oracleId - 1];
        }
    }

    /**
     * @dev Returns the active sample and the active size of the oracle
     * @param oracle The oracle
     * @param oracleId The oracle id
     * @return activeSample The active sample
     * @return activeSize The active size of the oracle
     */
    function getActiveSampleAndSize(Oracle storage oracle, uint16 oracleId)
        internal
        view
        returns (bytes32 activeSample, uint16 activeSize)
    {
        activeSample = getSample(oracle, oracleId);
        activeSize = activeSample.getOracleLength();

        if (oracleId != activeSize) {
            activeSize = getSample(oracle, activeSize).getOracleLength();
            activeSize = oracleId > activeSize ? oracleId : activeSize;
        }
    }

    /**
     * @dev Returns the sample at the given timestamp. If the timestamp is not in the oracle, it returns the closest sample
     * @param oracle The oracle
     * @param oracleId The oracle id
     * @param lookUpTimestamp The timestamp to look up
     * @return lastUpdate The last update timestamp
     * @return cumulativeId The cumulative id
     * @return cumulativeVolatility The cumulative volatility
     * @return cumulativeBinCrossed The cumulative bin crossed
     */
    function getSampleAt(Oracle storage oracle, uint16 oracleId, uint40 lookUpTimestamp)
        internal
        view
        returns (uint40 lastUpdate, uint64 cumulativeId, uint64 cumulativeVolatility, uint64 cumulativeBinCrossed)
    {
        (bytes32 activeSample, uint16 activeSize) = getActiveSampleAndSize(oracle, oracleId);

        if (oracle.samples[oracleId % activeSize].getSampleLastUpdate() > lookUpTimestamp) {
            revert OracleHelper__LookUpTimestampTooOld();
        }

        lastUpdate = activeSample.getSampleLastUpdate();
        if (lastUpdate <= lookUpTimestamp) {
            return (
                lastUpdate,
                activeSample.getCumulativeId(),
                activeSample.getCumulativeVolatility(),
                activeSample.getCumulativeBinCrossed()
            );
        } else {
            lastUpdate = lookUpTimestamp;
        }
        (bytes32 prevSample, bytes32 nextSample) = binarySearch(oracle, oracleId, lookUpTimestamp, activeSize);
        uint40 weightPrev = nextSample.getSampleLastUpdate() - lookUpTimestamp;
        uint40 weightNext = lookUpTimestamp - prevSample.getSampleLastUpdate();

        (cumulativeId, cumulativeVolatility, cumulativeBinCrossed) =
            prevSample.getWeightedAverage(nextSample, weightPrev, weightNext);
    }

    /**
     * @dev Binary search to find the 2 samples surrounding the given timestamp
     * @param oracle The oracle
     * @param oracleId The oracle id
     * @param lookUpTimestamp The timestamp to look up
     * @param length The oracle length
     * @return prevSample The previous sample
     * @return nextSample The next sample
     */
    function binarySearch(Oracle storage oracle, uint16 oracleId, uint40 lookUpTimestamp, uint16 length)
        internal
        view
        returns (bytes32, bytes32)
    {
        uint256 low = 0;
        uint256 high = length - 1;

        bytes32 sample;
        uint40 sampleLastUpdate;

        uint256 startId = oracleId; // oracleId is 1-based
        while (low <= high) {
            uint256 mid = (low + high) >> 1;

            assembly {
                oracleId := addmod(startId, mid, length)
            }

            sample = oracle.samples[oracleId];
            sampleLastUpdate = sample.getSampleLastUpdate();

            if (sampleLastUpdate > lookUpTimestamp) {
                high = mid - 1;
            } else if (sampleLastUpdate < lookUpTimestamp) {
                low = mid + 1;
            } else {
                return (sample, sample);
            }
        }

        if (lookUpTimestamp < sampleLastUpdate) {
            unchecked {
                if (oracleId == 0) {
                    oracleId = length;
                }

                return (oracle.samples[oracleId - 1], sample);
            }
        } else {
            assembly {
                oracleId := addmod(oracleId, 1, length)
            }

            return (sample, oracle.samples[oracleId]);
        }
    }

    /**
     * @dev Sets the sample at the given oracleId
     * @param oracle The oracle
     * @param oracleId The oracle id
     * @param sample The sample
     */
    function setSample(Oracle storage oracle, uint16 oracleId, bytes32 sample) internal checkOracleId(oracleId) {
        unchecked {
            oracle.samples[oracleId - 1] = sample;
        }
    }

    /**
     * @dev Updates the oracle
     * @param oracle The oracle
     * @param parameters The parameters
     * @param activeId The active id
     * @return The updated parameters
     */
    function update(Oracle storage oracle, bytes32 parameters, uint24 activeId) internal returns (bytes32) {
        uint16 oracleId = parameters.getOracleId();
        if (oracleId == 0) return parameters;

        bytes32 sample = getSample(oracle, oracleId);

        uint40 createdAt = sample.getSampleCreation();
        uint40 lastUpdatedAt = createdAt + sample.getSampleLifetime();

        if (block.timestamp.safe40() > lastUpdatedAt) {
            unchecked {
                (uint64 cumulativeId, uint64 cumulativeVolatility, uint64 cumulativeBinCrossed) = sample.update(
                    uint40(block.timestamp - lastUpdatedAt),
                    activeId,
                    parameters.getVolatilityAccumulator(),
                    parameters.getDeltaId(activeId)
                );

                uint16 length = sample.getOracleLength();
                uint256 lifetime = block.timestamp - createdAt;

                if (lifetime > _MAX_SAMPLE_LIFETIME) {
                    assembly {
                        oracleId := add(mod(oracleId, length), 1)
                    }

                    lifetime = 0;
                    createdAt = uint40(block.timestamp);

                    parameters = parameters.setOracleId(oracleId);
                }

                sample = SampleMath.encode(
                    length, cumulativeId, cumulativeVolatility, cumulativeBinCrossed, uint8(lifetime), createdAt
                );
            }

            setSample(oracle, oracleId, sample);
        }

        return parameters;
    }

    /**
     * @dev Increases the oracle length
     * @param oracle The oracle
     * @param oracleId The oracle id
     * @param newLength The new length
     */
    function increaseLength(Oracle storage oracle, uint16 oracleId, uint16 newLength) internal {
        bytes32 sample = getSample(oracle, oracleId);
        uint16 length = sample.getOracleLength();

        if (length >= newLength) revert OracleHelper__NewLengthTooSmall();

        bytes32 lastSample = length == oracleId ? sample : length == 0 ? bytes32(0) : getSample(oracle, length);

        uint256 activeSize = lastSample.getOracleLength();
        activeSize = oracleId > activeSize ? oracleId : activeSize;

        for (uint256 i = length; i < newLength;) {
            oracle.samples[i] = bytes32(uint256(activeSize));

            unchecked {
                ++i;
            }
        }

        setSample(oracle, oracleId, (sample ^ bytes32(uint256(length))) | bytes32(uint256(newLength)));
    }
}
