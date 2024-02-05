// SPDX-License-Identifier: MIT

pragma solidity ^0.8.13;

import "./ERC20.sol";
import "./ERC20Burnable.sol";
import "./Ownable.sol";

contract Token is ERC20, ERC20Burnable, Ownable {
    uint256 public constant MAX_SUPPLY = 10000000 ether;
    uint256 public totalMinted;

    /**
     * @param   _owner          Owner address
     * @param   _initialSupply  Initial token supply
     */
    constructor(address _owner, uint256 _initialSupply) ERC20("Arbitrum Games", "ARBG") {
        require(_owner != address(0), "Param");
        require(_initialSupply <= MAX_SUPPLY, "Param");
        _transferOwnership(_owner);
        totalMinted += _initialSupply;
        _mint(_owner, _initialSupply);
    }

    /**
     * @notice  Permissioned mint to owner
     * @param   _amount     Amount of token to mint
     */
    function mint(uint256 _amount) external onlyOwner {
        require(totalMinted + _amount <= MAX_SUPPLY, "Max supply reached");
        totalMinted += _amount;
        _mint(owner(), _amount);
    }
}