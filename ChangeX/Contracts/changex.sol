// SPDX-License-Identifier: MIT
pragma solidity 0.5.4;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Detailed.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Pausable.sol";
import "@openzeppelin/contracts/lifecycle/Pausable.sol";
import "@openzeppelin/contracts/ownership/Ownable.sol";

contract ChangeX is ERC20, ERC20Detailed, ERC20Burnable, ERC20Pausable, Ownable {
    address private _bridgeAddress;

    constructor() public ERC20Detailed("ChangeX", "CHANGE", 18)  {
        _mint(msg.sender, 425000000 * 1000000000000000000);
    }

    function mint(address to, uint256 amount) public {
        require (msg.sender == bridgeAddress(), "Caller is not the bridge address");
        require (totalSupply() + amount <= 425000000000000000000000000, "Maximum amount is 250M tokens");
        _mint(to, amount);
    }

    function setBridgeAddress(address newBridgeAddress) public onlyOwner {
        _bridgeAddress = newBridgeAddress;
    }

    function bridgeAddress() public view returns(address) {
        return _bridgeAddress;
    }
}