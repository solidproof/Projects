// SPDX-License-Identifier: MIT

/**
 *

                                     ,╓╓╓╓╓╓╓╓╓╓╓╓,   ╓╓╓
                                     ]▒▒▒▒▒▒▒▒▒▒▒▒▒   ▒▒▒
                           ]║║║   ║║║║▒▒▒▒▒▒▒▒▒▒▒▒▒║║║
                           ]▒▒▒╓╓╓▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒╓╓╓    ╓╓╓
                           ]▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒    ▒▒▒
                     ║║║║║║║▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒║║║║   ║║║
                     ╝╝╝▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒,,,▒▒▒
                        ▒▒▒▒▒▒▒▒▒▒▒▒▒╟╢╢╢▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒▒
                     ║║║▒▒▒▒▒▒▒▒▒▒▓▓▓▒▒▒▒▓▓▓▒▒▒╟▓▓▓▓▓▓▒▒▒▒▒▒▒▒▒▒
                 ,,,,╝╝╝▒▒▒▒▒▒▒▒▒▒╢╢╢▒▒▒▒╢╢╢▒▒▒╟╢╢╢╢╢╢▒▒▒▒▒▒▒▒▒▒,,,
                 ]▒▒▒   ▒▒▒▒▒▒▒▒▒▒╢╢╢╢╢╢╢╢╢╢▒▒▒╟╢╢╢╢╢╢╢╢╢▒▒▒▒▒▒▒▒▒▒
                     ║║║▒▒▒▒▒▒▒▓▓▓▒▒▒▒▒▒▒╢╢╢▒▒▒╟╢╢╢▒▒▒▒▒▒████▒▒▒   ]║║[
                 ,,,,╝╝╝▒▒▒▒▒▒▒╢╢╢▄▄▄▒▒▒▒╢╢╢▒▒▒╟╬╬╣▄▄▄▒▒▒████▒▒▒,,,╙╝╝╜
                 ]▒▒▒   ▒▒▒╟╢╢╢╢╢╢████▓▓▓╢╢╢╢╢╢▒▒▒▒███▓▓▓████▒▒▒▒▒▒
              @@@║▒▒▒@@@▒▒▒████╢╢╢▒▒▒▒╣╣╣╢╢╢╢╢╢▓▓▓╣▒▒▒╣╣╣████▒▒▒▒▒▒
              ╝╝╝╝╝╝╝▒▒▒▒▒▒████╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢████▒▒▒▒▒▒,
                     ▒▒▒▒▒▒████╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢████▒▒▒▒▒▒▒▒▒▒
                     ▒▒▒▒▒▒████╢╢╢╢╢╢╢╢╢╢╢╢╢███▌╢╢╢╢╢╢╢╢╢████▒▒▒
                     ║║║║║║████╢╢╢╢╢╢╢╢╢╢╢╢╢███▌╢╢╢╢╢╢╢╢╢████║║║
                 ]▒▒▒      ████╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢████   ▒▒▒
                           ████╢╢╢╢╢╢╢╢╢╫██████████╢╢╢╢╢╢████
                           ▐███▒▒▒╢╢╢╢╢╢╫██████████╢╢╢▒▒▒████
                               ███╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢╢███▌
                               ███╢╢╢████╢╢╢╢╢╢╢╢╢╫███▀▀▀
                               ███╢╢╢████▒▒▒▒▒▒▒▒▒▒███
                               ███╢╢╢╢╢╢▓██████████
                               ███╢╢╢╢╢╢╢▒▒▒███▌▀▀`
                               ███╢╢╢╢╢╢╢╢╢╢███▌
                               ███╢╢╢╢╢╢╢╢╢╢███▌
    
 *@title RFDAO Coin - Decentralized meme coin ecosystem redefining the rules with utility.
 *@author rfdaodev
 */

pragma solidity ^0.8.9;

import "@openzeppelin/contracts@4.9.2/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts@4.9.2/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts@4.9.2/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts@4.9.2/access/Ownable.sol";

contract RFDAOCoin is ERC20, ERC20Burnable, ERC20Snapshot, Ownable {
    constructor() ERC20("RFDAO Coin", "RFDAO") {
        _mint(msg.sender, 999800000 * 10 ** decimals());
    }

    function snapshot() public onlyOwner {
        _snapshot();
    }

    // The following functions are overrides required by Solidity.

    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Snapshot)
    {
        super._beforeTokenTransfer(from, to, amount);
    }
}