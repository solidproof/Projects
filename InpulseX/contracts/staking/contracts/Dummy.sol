// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.8.17;

import "@openzeppelin/contracts/interfaces/IERC1363Receiver.sol";

import "@openzeppelin/contracts/token/ERC721/ERC721.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";

contract Dummy1155 is ERC1155 {
    constructor() ERC1155("https://dummy1155.tld/token/{}") {
        for (uint256 id = 0; id < 100; id++) {
            _mint(msg.sender, id, 100000000, "");
        }
    }
}

contract Dummy721 is ERC721 {
    constructor() ERC721("Dummy721", "DUMMY721") {
        for (uint256 id = 0; id < 100; id++) {
            _mint(msg.sender, id);
        }
    }
}

contract Dummy20 is ERC20 {
    constructor() ERC20("Dummy20", "DUMMY20") {
        _mint(msg.sender, 100000000000000);
    }
}

contract Dummy1363 is ERC20 {
    constructor() ERC20("Dummy1363", "DUMMY1363") {
        _mint(msg.sender, 100000000000000);
    }

    function transferAndCall(
        address recipient,
        uint256 amount,
        bytes memory data
    ) public returns (bool) {
        transfer(recipient, amount);

        bytes4 retval = IERC1363Receiver(recipient).onTransferReceived(
            msg.sender,
            msg.sender,
            amount,
            data
        );
        require(
            retval == IERC1363Receiver(recipient).onTransferReceived.selector,
            "ERC1363: transferAndCall reverts"
        );

        return true;
    }
}
