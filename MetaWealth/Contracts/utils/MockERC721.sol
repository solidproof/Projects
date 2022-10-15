// SPDX-License-Identifier: MIT
pragma solidity ^0.8.7;

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract MockERC721 is ERC721, Ownable {
    constructor() ERC721("MOCK", "M") {}

    uint256 id;

    function mint() external {
        _safeMint(msg.sender, id++);
    }
}
