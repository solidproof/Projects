// SPDX-License-Identifier: MIT

pragma solidity 0.8.1;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Strings.sol";


contract WhiteList is Ownable {
    using Strings for string;
    uint8 public constant WHITELIST_MAX = 7;

    mapping(address => uint) public whiteListQouta;

    function setWhitelist(address[] calldata addresses) external onlyOwner {
        require(addresses.length <= 2000);
        for (uint256 i = 0; i < addresses.length; i++) {
            whiteListQouta[addresses[i]] = WHITELIST_MAX;
        }
    }
    mapping(address => uint) public whiteListSecondQouta;

    function setWhitelistSecond(address[] calldata addresses) external onlyOwner {
        require(addresses.length <= 2000);
        for (uint256 i = 0; i < addresses.length; i++) {
            whiteListSecondQouta[addresses[i]] = WHITELIST_MAX;
        }
    }

    uint8 public constant WHITELIST_FREE_MAX = 1;

    mapping(address => uint) public whiteListFreeQouta;

    function setWhitelistFree(address[] calldata addresses) external onlyOwner {
        require(addresses.length <= 2000);
        for (uint256 i = 0; i < addresses.length; i++) {
            whiteListFreeQouta[addresses[i]] = WHITELIST_FREE_MAX;
        }
    }



    uint8 public constant MAX_PUBLIC_MINT = 7;

    mapping(address => bool)  public hasMinted;
    mapping(address => uint) public publicQouta;

    function initQouta(address _address) internal {
        if(!hasMinted[_address])
        {
            hasMinted[_address] = true;
            publicQouta[_address] = MAX_PUBLIC_MINT;
        }

    }
}