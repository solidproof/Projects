// SPDX-License-Identifier: MIT

pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract BYD is ERC20, Ownable {
    uint8 constant DECIMAL_PLACES = 6;
    uint256 constant TOTAL_SUPPLY = 20000000000000 * (10 ** DECIMAL_PLACES);
    uint256 constant PREMINT = 2000000000000 * (10 ** DECIMAL_PLACES);

    constructor() ERC20 ("Build Your Dream", "BYD") {
        _mint(_msgSender(), PREMINT);
    }
    
    function decimals() public pure override returns (uint8) {
		return DECIMAL_PLACES;
	}

    function mint(address _to, uint256 _amount) external onlyOwner() {
        require(totalSupply() + _amount <= TOTAL_SUPPLY, "Exceeded total supply");

        _mint(_to, _amount);

        emit Mint(_to, _amount);
    }

    event Mint(address _to, uint256 _amount);

}