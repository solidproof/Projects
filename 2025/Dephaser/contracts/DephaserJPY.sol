// SPDX-License-Identifier: MIT

pragma solidity 0.8.27;

import { ERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { ERC20Permit } from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import { AccessControl } from "@openzeppelin/contracts/access/AccessControl.sol";
import { AccessControlEnumerable } from "@openzeppelin/contracts/access/extensions/AccessControlEnumerable.sol";

/// @title DephaserJPY
/// @notice This contract implements a custom ERC20 token with minting and burning capabilities
/// @dev Extends ERC20, ERC20Permit, and AccessControlEnumerable
contract DephaserJPY is AccessControlEnumerable, ERC20, ERC20Permit {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");

    /**
     * @notice Initializes the JpytToken contract
     * @dev Sets up the default admin role
     * @param defaultAdmin The address to be granted the default admin role
     */
    constructor(address defaultAdmin) ERC20("Dephaser JPY", "JPYT") ERC20Permit("Dephaser JPY") {
        _grantRole(DEFAULT_ADMIN_ROLE, defaultAdmin);
    }

    /**
     * @notice Returns the number of decimals used to get its user representation
     * @dev Overrides ERC20 default value of 18
     * @return uint8 Number of decimals of the token
     */
    function decimals() public pure override returns (uint8) {
        return 6;
    }

    /**
     * @notice Mints new tokens
     * @dev Can only be called by accounts with the MINTER_ROLE
     * @param to The address that will receive the minted tokens
     * @param amount The amount of tokens to mint
     *
     * @notice Security considerations:
     * - MINTER_ROLE should only be granted to the DepositManager contract
     * - Ensure that the DepositManager contract properly manages minting to maintain the token's economic model
     * - Any change to the MINTER_ROLE assignment should be carefully reviewed and approved
     */
    function mint(address to, uint256 amount) external onlyRole(MINTER_ROLE) {
        _mint(to, amount);
    }

    /**
     * @notice Burns tokens
     * @dev Can only be called by accounts with the BURNER_ROLE
     * @param value The amount of tokens to burn
     *
     * @notice Security considerations:
     * - BURNER_ROLE should only be granted to the DepositManager contract
     * - Ensure that the DepositManager contract properly manages burning to maintain the token's economic model
     * - Any change to the BURNER_ROLE assignment should be carefully reviewed and approved
     */
    function burn(uint256 value) external onlyRole(BURNER_ROLE) {
        _burn(_msgSender(), value);
    }

    /**
     * @notice Burns tokens from a specified account
     * @dev Caller must have BURNER_ROLE and be approved to spend account's tokens
     * @param account The account from which tokens will be burned
     * @param value The amount of tokens to burn
     *
     * @notice Security considerations:
     * - BURNER_ROLE should only be granted to the DepositManager contract
     * - Ensure that the DepositManager contract properly manages burning to maintain the token's economic model
     * - Any change to the BURNER_ROLE assignment should be carefully reviewed and approved
     */
    function burnFrom(address account, uint256 value) external onlyRole(BURNER_ROLE) {
        _spendAllowance(account, _msgSender(), value);
        _burn(account, value);
    }
}