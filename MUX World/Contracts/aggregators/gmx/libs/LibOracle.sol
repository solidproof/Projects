// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

import "../../../interfaces/IChainLink.sol";

import "./LibUtils.sol";

library LibOracle {
    function readChainlink(address referenceOracle) internal view returns (uint96) {
        int256 ref = IChainlinkV2V3(referenceOracle).latestAnswer();
        require(ref > 0, "P=0"); // oracle Price <= 0
        ref *= 1e10; // decimals 8 => 18
        return LibUtils.toU96(uint256(ref));
    }
}
