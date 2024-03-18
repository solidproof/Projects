// SPDX-License-Identifier: MIT
pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract StableSwapLP is ERC20 {
    address public minter;

    event SetMinter(address newMinter);
    event Mint(address indexed to, uint256 indexed amount);
    event BurnFrom(address indexed to, uint256 indexed amount);

    constructor() ERC20("StableSwap LPs", "Stable-LP") {
        minter = msg.sender;
    }

    /**
     * @notice Checks if the msg.sender is the minter address.
     */
    modifier onlyMinter() {
        require(msg.sender == minter, "Not minter");
        _;
    }

    function setMinter(address newMinter) external onlyMinter {
        require(newMinter != address(0), "setMinter: Illegal address");
        minter = newMinter;
        
        emit SetMinter(newMinter);
    }

    function mint(address to, uint256 amount) external onlyMinter {
        _mint(to, amount);
        emit Mint(to, amount);
    }

    function burnFrom(address to, uint256 amount) external onlyMinter {
        _burn(to, amount);
        emit BurnFrom(to, amount);
    }
}