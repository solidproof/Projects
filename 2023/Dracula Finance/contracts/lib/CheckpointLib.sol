// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

library CheckpointLib {
    /// @notice A checkpoint for uint value
    struct Checkpoint {
        uint256 timestamp;
        uint256 value;
    }

    function findLowerIndex(
        mapping(uint256 => Checkpoint) storage checkpoints,
        uint256 size,
        uint256 timestamp
    ) internal view returns (uint256) {
        require(size != 0, "Empty checkpoints");

        // First check most recent value
        if (checkpoints[size - 1].timestamp <= timestamp) {
            return (size - 1);
        }

        // Next check implicit zero value
        if (checkpoints[0].timestamp > timestamp) {
            return 0;
        }

        uint256 lower = 0;
        uint256 upper = size - 1;
        while (upper > lower) {
            // ceil, avoiding overflow
            uint256 center = upper - (upper - lower) / 2;
            Checkpoint memory cp = checkpoints[center];
            if (cp.timestamp == timestamp) {
                return center;
            } else if (cp.timestamp < timestamp) {
                lower = center;
            } else {
                upper = center - 1;
            }
        }
        return lower;
    }
}
