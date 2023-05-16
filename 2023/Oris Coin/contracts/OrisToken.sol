// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract OrisToken is Ownable, ERC20("Oris Token", "ORIS") {
    uint256 constant maxSupply = 80000000 * 10**6;
    uint8 constant _decimals = 6;

    // lockTime used for locking the assets of users for a particular time
    mapping(address => uint32) public lockTime;

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function mint(
        address account,
        uint256 amount,
        uint32 unlockTimestamp
    ) public onlyOwner {
        require(maxSupply >= totalSupply() + amount,"OrisToken: Max Token limit exceeds");
        _mint(account, amount);
        lockTime[account] = unlockTimestamp;
    }

    function _transfer(
        address _sender,
        address _recipient,
        uint256 _amount
    ) internal virtual override {
        require(_amount > 0, "Invalid Amount");
        require(
            block.timestamp > lockTime[_sender],
            "Your assets are locked"
        );
        super._transfer(_sender, _recipient, _amount);
    }
}