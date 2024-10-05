// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BAMBOO is ERC20, Ownable {
    uint8 constant DECIMAL_PLACES = 6;

    constructor(
        string memory _name,
        string memory _symbol
    ) ERC20 (_name, _symbol) {

    }

    function decimals() public pure override returns (uint8) {
		return DECIMAL_PLACES;
	}

    function mint(address _to, uint256 _amount) external onlyOwner(){
        _mint(_to, _amount);

        emit Mint(_to, _amount);
    }

    event Mint(address _to, uint256 _amount);
}