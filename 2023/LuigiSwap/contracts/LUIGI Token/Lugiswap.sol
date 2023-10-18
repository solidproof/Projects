// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Luigiswap is ERC20 {
    address public minter;
    uint256 public constant _maxTotalSupply = 100_000_000 * 1e18; // 100,000,000 max LUIGI
    modifier onlyMinter() {
        require(msg.sender == minter, "!minter");
        _;
    }

    constructor() ERC20("Luigiswap", "LUIGI") {
        minter = msg.sender;
        _mint(msg.sender, 10_000_000 * 1e18);
    }

    function mint(address _to, uint256 _amount) public onlyMinter {
        require(
            totalSupply() + _amount <= _maxTotalSupply,
            "ERC20: minting more then MaxTotalSupply"
        );

        _mint(_to, _amount);
    }

    function changeMinterToMasterChef(address _masterChefAddress) external onlyMinter {
        require(_masterChefAddress != address(0), "Luigiswap: ZERO_ADDRESS");
        require(_masterChefAddress != minter, "Luigiswap: ! old minter");
        minter = _masterChefAddress;
    }
}