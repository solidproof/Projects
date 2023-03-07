// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract CryptowalkersBoredBoxJetpack is ERC1155, Ownable, ERC1155Supply {
    uint256 constant MAX_SUPPLY = 1000;

    string public name = "Cryptowalkers Bored Box Jetpack";
    string public symbol = "CWBBJ";

    constructor() ERC1155("https://example.com/") {}

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function mint(
        address _to,
        uint256 _amt,
        bytes memory _data
    ) public onlyOwner {
        uint256 newSupply = _amt + totalSupply(1);
        require(
            newSupply <= MAX_SUPPLY,
            "The entire colleciton has been minted."
        );
        _mint(_to, 1, _amt, _data);
    }

    function _beforeTokenTransfer(
        address operator,
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) internal override(ERC1155, ERC1155Supply) {
        super._beforeTokenTransfer(operator, from, to, ids, amounts, data);
    }
}
