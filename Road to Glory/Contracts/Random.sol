// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

library Random {
    function newSeed(uint256 seed) internal view returns (uint256) {
        return uint256(keccak256(abi.encodePacked(block.timestamp, blockhash(block.number - 1), block.difficulty, seed, seed % 10)));
    }

    function rand(uint256 seed, uint256 max) internal view returns (uint256 nSeed, uint256 result) {
        nSeed = newSeed(seed);
        result = nSeed % max;
    }

    function randRangeExclusive(uint256 seed, uint256 low, uint256 max) internal view returns (uint256 nSeed, uint256 result) {
        require(low < max, "Low < max");
        (nSeed, result) = rand(seed, max - low);
        result += low;
    }

    function randRange(uint256 seed, uint256 low, uint256 max) internal view returns(uint256 nSeed, uint256 result) {
        (nSeed, result) = randRangeExclusive(seed, low, max);
    }

    function randWeighted(uint256 seed, uint256[] memory weights) internal view returns (uint256 nSeed, uint256 index) {
        require(weights.length > 0, "Empty weights");
        uint256 total;
        for (uint256 i = 0; i < weights.length; ++i) {
            total += weights[i];
        }
        uint256 result;
        (nSeed, result) = randRange(seed, 0, total);
        uint256 accumulator;
        for (uint256 i = 0; i < weights.length; ++i) {
            accumulator += weights[i];
            if (result <= accumulator) {
                return (nSeed, i);
            }
        }
        return (nSeed, 0);
    }
}