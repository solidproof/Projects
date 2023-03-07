// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/access/Ownable.sol";
import "erc721a/contracts/ERC721A.sol";

contract Cats is ERC721A, Ownable {
    string private _tokenBaseURI;

    constructor() ERC721A("Cats", "CATS") {
        _tokenBaseURI = "ipfs://QmQ1hiPEsWeboo3juKFWeiPL8suZBUqazoazpHyHezStxt/";
    }

    function mint(uint64 _amt) external onlyOwner {
        _mint(msg.sender, _amt);
    }

    function _baseURI() internal view virtual override returns (string memory) {
        return _tokenBaseURI;
    }

    function _startTokenId() internal pure override returns (uint256) {
        return 1;
    }
}
