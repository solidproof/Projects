// SPDX-License-Identifier: MIT
pragma solidity =0.8.9;

import "./InitializeData.sol";

abstract contract LootBoxData {
    uint8 public constant totalCharacters = 100;

    /**
     * @dev Data in the "typeChances" is stored the following
     *
     * The format is [20bit][2bit][2bit]
     * The first 20 bits are for the probability
     * The next 2 bits are for BORDER
     * The last 2 bits are for BACKGROUND
     */
    mapping(uint8 => uint24[]) public typeChances;
    /**
     * @dev Data in the "cardCaps" is stored the following
     * mapping KEY — 4 bits used (total 16 variants)
     * The next 2 bits are for BORDER
     * The last 2 bits are for BACKGROUND
     *
     * The value is the actual cap for this card type
     */
    uint32[16] public cardCaps;

    mapping(uint256 => uint32) public typeCaps;

    bool internal initialized;

    error AlreadyInitialized();

    modifier notInitialized() {
        if (initialized) {
            revert AlreadyInitialized();
        }
        _;
    }

    function initialize() internal notInitialized {
        typeCaps[1] = InitializeData.typeCaps1();
        typeCaps[2] = InitializeData.typeCaps2();

        typeChances[1] = InitializeData.initChances1();
        typeChances[2] = InitializeData.initChances2();

        cardCaps = InitializeData.initCaps();

        initialized = true;
    }

    function createToken() virtual internal {}

    function initTypes() private {
        // pre-creating 2 token types.
        createToken();
        createToken();
    }
}
