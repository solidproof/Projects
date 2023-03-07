// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";

contract Hat is ERC1155, Ownable, ERC1155Supply {
    uint256 constant MAX_SUPPLY = 1000;

    string public name = "Hat";
    string public symbol = "HAT";

    constructor()
        ERC1155("ipfs://QmfTx11cB6T94RPCMPNes98SrySk4GDFSVpC9iJYFQQhYA")
    {}

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function mint(uint256 _amt) public onlyOwner {
        _mint(msg.sender, 1, _amt, "");
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
