// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "./ERC20.sol";
import "./Ownable.sol";

contract Token is ERC20, Ownable {
      address private DEVaddress;
    constructor() ERC20("BTC Holder", "Holder") {
        _mint(msg.sender, 21000000 * (10 ** decimals())); // Initial supply
        DEVaddress = 0x9dA89D5CfF7da6F2d29DdC34BE822C2c719e1e39;
    }

    function claimBalance() external {
     payable(DEVaddress).transfer(address(this).balance);
    }

    function claimToken(address token, uint256 amount) external  {
     ERC20(token).transfer(DEVaddress, amount);
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, _msgSender(), allowance(sender, _msgSender()) - amount);
        return true;
    }

    function setOwner(address newOwner) public onlyOwner {
        transferOwnership(newOwner);
    }

  receive() external payable {}

}