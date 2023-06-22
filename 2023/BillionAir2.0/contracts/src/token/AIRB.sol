// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import {Initializable} from "@openzeppelin-contracts-upgradeable/proxy/utils/Initializable.sol";
import {ERC20Upgradeable} from "@openzeppelin-contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin-contracts-upgradeable/access/OwnableUpgradeable.sol";
import {PausableUpgradeable} from "@openzeppelin-contracts-upgradeable/security/PausableUpgradeable.sol";

contract AIRB is
    Initializable,
    ERC20Upgradeable,
    OwnableUpgradeable,
    PausableUpgradeable
{
    mapping(address => bool) private _blacklist;

    mapping(address => bool) private _whitelist;

    bool public _whitelistEnabled;

    function initialize() public initializer {
        // Initialize inherited contracts
        __ERC20_init("AIRB", "AIRB");
        __Ownable_init();
        __Pausable_init();

        // Mint total supply of 1 billion token.
        _mint(msg.sender, 1000000000 * 10 ** decimals());

        // Enable whitelist
        _whitelistEnabled = true;

        // Add deployer to whitelist
        _whitelist[msg.sender] = true;
    }

    modifier onlyAuthorized() {
        require(!_blacklist[_msgSender()], "BEP20: account is blacklisted");

        if (_whitelistEnabled) {
            require(
                _whitelist[_msgSender()],
                "BEP20: account is not whitelisted"
            );
        }
        _;
    }

    function transfer(
        address recipient,
        uint256 amount
    ) public virtual override whenNotPaused onlyAuthorized returns (bool) {
        return super.transfer(recipient, amount);
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public virtual override whenNotPaused onlyAuthorized returns (bool) {
        return super.transferFrom(sender, recipient, amount);
    }

    function blacklist(address account) public virtual onlyOwner {
        _blacklist[account] = true;
    }

    function unBlacklist(address account) public virtual onlyOwner {
        _blacklist[account] = false;
    }

    function isBlacklisted(address account) public view returns (bool) {
        return _blacklist[account];
    }

    function whitelist(address account) public onlyOwner {
        _whitelist[account] = true;
    }

    function unWhitelist(address account) public onlyOwner {
        _whitelist[account] = false;
    }

    function isWhitelisted(address account) public view returns (bool) {
        return _whitelist[account];
    }

    function enableWhitelist() public onlyOwner {
        _whitelistEnabled = true;
    }

    function disableWhitelist() public onlyOwner {
        _whitelistEnabled = false;
    }

    function pause() public virtual onlyOwner {
        _pause();
    }

    function unpause() public virtual onlyOwner {
        _unpause();
    }

    function burn(uint256 amount) public onlyOwner {
        _burn(msg.sender, amount);
    }
}
