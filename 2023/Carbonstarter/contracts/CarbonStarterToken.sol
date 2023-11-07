// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract CarbonStarterToken1 is ERC20Burnable, ERC20Permit, Ownable {
    using SafeERC20 for IERC20;
    address internal constant DEAD_ADDRESS =
        0x000000000000000000000000000000000000dEaD;
    mapping(address => bool) public minters;
    /**
     * @notice Total supply of ARBS token
     */
    uint256 internal constant MAX_TOTAL_SUPPLY = 50_000_000 ether;

    /**
     * @notice ARBS token constructor
     * @notice parameter: name and symbol
     */
    constructor() ERC20("Carbon Starter Token", "ARBS") ERC20Permit("ARBS") {
        minters[msg.sender] = true;
    }
    /********************************************/
    /****************** EVENTS ******************/
    /********************************************/

    event Mint(address indexed sender, address receiver, uint256 amount);
    event SetMinter(address indexed sender, address minter);
    event RemoveMinter(address indexed sender, address minter);    

    /**
     * @notice Mint tokens
     * @param to ARBS tokens receive
     * @param amount amount ARBS to mint
     */
    function mint(address to, uint256 amount) external {
        require(minters[msg.sender], "not a minter");
        require(amount + totalSupply() <= MAX_TOTAL_SUPPLY, "max reached");
        emit Mint(msg.sender, to, amount);
        _mint(to, amount);
    }

    /**
     * @notice Set minter
     * @param _minter minters address
     */
    function setMinter(address _minter) external onlyOwner {
        minters[_minter] = true;
        emit SetMinter(msg.sender, _minter);
    }

    /**
     * @notice Remove Minter
     * @param _minter Minters address
     */
    function removeMinter(address _minter) external onlyOwner {
        minters[_minter] = false;
        emit RemoveMinter(msg.sender, _minter);
    }

    /**
     * @notice Burns tokens to dead address
     * @param _amount amount to burn
     */
    function burnToDead(uint256 _amount) external {
        _transfer(msg.sender, DEAD_ADDRESS, _amount);     
    }
}
