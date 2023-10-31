// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

interface INFT {
    struct Initialization {
        string name;
        string symbol;
        string baseTokenURI;
        uint256 limitSupply;
        uint256 presaleSupply;
        uint256 presalePrice;
        uint256 publicSalePrice;
        uint256 PRESALE_MAX_MINT;
        uint256 MAX_PER_MINT;
        address royaltyReceiverAddress;
        uint96 royaltyFee;
    }

    function initialize(Initialization calldata initialization) external;
}
