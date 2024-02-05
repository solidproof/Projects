// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract TokenTest is ERC20 {
    constructor() ERC20("USDT", "USDT") {}

    function decimals() public view override returns (uint8) {
        return 6;
    }

    function mint(address _to, uint256 _amount) external {
        _mint(_to, _amount);
    }
}
