// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./token/oft/extension/BasedOFT.sol";

/// @title A LayerZero OmnichainFungibleToken example of BasedOFT
/// @notice Use this contract only on the BASE CHAIN. It locks tokens on source, on outgoing send(), and unlocks tokens when receiving from other chains.
contract AITBasedOFT is BasedOFT {
    constructor(address _layerZeroEndpoint) BasedOFT("AIT Protocol", "AIT", _layerZeroEndpoint) {
        _mint(_msgSender(), 1000000000*1e18);
    }
}
