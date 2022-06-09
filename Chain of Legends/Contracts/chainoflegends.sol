// SPDX-License-Identifier: UNLICENCED
pragma solidity ^0.8.10;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/extensions/ERC20BurnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";


/// @custom:security-contact info@chainoflegends.com
contract ColToken is
    Initializable,
    ERC20Upgradeable,
    ERC20BurnableUpgradeable,
    PausableUpgradeable,
    OwnableUpgradeable,
    UUPSUpgradeable
{
    string public version;

    /// @custom:oz-upgrades-unsafe-allow constructor

    function setVersion(string memory _newVersion) public{
      version = _newVersion;
    }

    function initialize(string memory _tokenName, string memory _tokenSymbol)
        public
        initializer
    {
        __ERC20_init(_tokenName, _tokenSymbol);
        __ERC20Burnable_init();
        __Pausable_init();
        __Ownable_init();
        __UUPSUpgradeable_init();

        _mint(address(this), 1000000000 * 10 ** decimals());
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override whenNotPaused {
        super._beforeTokenTransfer(from, to, amount);
    }

    function _authorizeUpgrade(address newImplementation)
        internal
        override
        onlyOwner
    {}

    function give(address to, uint256 amount) public onlyOwner{
      transferFrom(address(this), to, amount);
    }

    function distribute(address[] memory recepients, uint[] memory values) public onlyOwner{
      require(recepients.length > 0, "No recepient privided");
      require(recepients.length == values.length, "recepients count should be equal to values count");
      for (uint256 i = 0; i < recepients.length; i++) {
        transferFrom(address(this),recepients[i], values[i]);
      }
    }
}