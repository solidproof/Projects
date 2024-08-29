// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";

interface ITokenRecipient {
    function receiveApproval(address _from, uint256 _value, address _token, bytes calldata _extraData) external;
}

contract GenericToken is ERC20, ERC20Burnable, Ownable, Pausable {
    mapping(address => bool) public frozenAccount;
    mapping(address => uint256) public 
    ;

    event FreezeAccount(address indexed account, bool frozen);
    event LockAccount(address indexed account, uint256 unlockTime);

    constructor(string memory name, string memory symbol, uint256 initialSupply) ERC20(name, symbol) {
        _mint(msg.sender, initialSupply);
    }

    function setFrozenAccount(address account, bool freeze) public onlyOwner {
        frozenAccount[account] = freeze;
        emit FreezeAccount(account, freeze);
    }

    function lockAccount(address account, uint256 unlockTime) public onlyOwner {
        require(unlockTime > block.timestamp, "Unlock time must be in the future");
        lockedAccount[account] = unlockTime;
        emit LockAccount(account, unlockTime);
    }

    function unlockAccount(address account) public onlyOwner {
        lockedAccount[account] = 0;
        emit LockAccount(account, 0);
    }

    function _beforeTokenTransfer(address from, address to, uint256 amount) internal override(ERC20) whenNotPaused {
        require(!frozenAccount[from], "Account is frozen");
        require(!frozenAccount[to], "Account is frozen");
        require(!isAccountLocked(from), "Account is locked");

        super._beforeTokenTransfer(from, to, amount);
    }

    function isAccountLocked(address account) public view returns (bool) {
        return lockedAccount[account] > block.timestamp;
    }
}