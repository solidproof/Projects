// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

/**
 * @title CDP Token for the Carpe Diem Pension system
 * @author Carpe Diem
 * @notice Basic burnable token with permit
 * @dev Part of a system of three contracts. The other two are called Pension and Auction
 */
contract CDPToken is
    ERC20,
    ERC20Permit
{
    /** @notice Address of the Pension contract */
    address public immutable minterAddress;
    /** @notice Tracks the total amount of destroyed tokens */
    uint256 public totalBurned;

    /**
     * @notice Construct the contract and mint the initial supply
     * @param pensionAddress Address of the Pension contract
     */
    constructor(
        address pensionAddress
    )
        ERC20("Carpe Diem Pension", "CDP")
        ERC20Permit("Carpe Diem Pension")
    {
        minterAddress = pensionAddress;
        _mint(msg.sender, 543391647*1e18);
    }

    /**
     * @notice Create new tokens
     * @param to Address of the recipient
     * @param amount Amount of tokens to create
     * @dev Restriced to the Pension contract
     */
    function mint(
        address to,
        uint256 amount
    ) public {
        require(
            msg.sender == minterAddress,
            "No permission"
        );
        _mint(to, amount);
    }

    /**
     * @notice Destroys tokens from existence
     * @param amount Amount to destroy
     * @dev Keeps track of destroyed tokens 
     */
    function burn(
        uint256 amount
    ) public {
        totalBurned += amount;
        _burn(_msgSender(), amount);
    }

    /**
     * @notice Destroys tokens from existence for someone else, if the caller has sufficient allowance
     * @param account Account to destroy tokens from
     * @param amount Amount to destroy
     * @dev Keeps track of destroyed tokens 
     */
    function burnFrom(
        address account, 
        uint256 amount
    ) public {
        totalBurned += amount;
        _spendAllowance(account, _msgSender(), amount);
        _burn(account, amount);
    }
}