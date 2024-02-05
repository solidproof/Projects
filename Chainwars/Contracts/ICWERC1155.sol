// SPDX-License-Identifier: MIT
pragma solidity =0.8.9;

interface ICWERC1155 {
    function mintCards(
        address account,
        uint8 border,
        uint8 background,
        uint8 character,
        uint256 amount,
        bytes memory data
    ) external;

    function currentTokenID() external view returns (uint256);
}
