// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import '@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol';
import '@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol';
import '@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol';
import '@openzeppelin/contracts/utils/Strings.sol';
import '../interfaces/periphery/INonfungibleTokenPositionDescriptor.sol';

contract TokenPositionDescriptor is
INonfungibleTokenPositionDescriptor,
Initializable,
UUPSUpgradeable,
OwnableUpgradeable
{
    string private baseURI;

    function initialize() public initializer {
        __Ownable_init();
    }

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function setBaseURI(string memory _baseURI) external onlyOwner {
        baseURI = _baseURI;
    }

    function tokenURI(IBasePositionManager, uint256 tokenId)
    external
    view
    override
    returns (string memory)
    {
        return
        bytes(baseURI).length > 0
        ? string(abi.encodePacked(baseURI, Strings.toString(tokenId)))
        : '';
    }
}
