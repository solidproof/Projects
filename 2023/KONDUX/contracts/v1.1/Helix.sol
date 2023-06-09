// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

/**
 * @title Helix
 * @dev A custom ERC20 token with access control and whitelisting features. 
 *      The token supports minting and burning, and restricts transfers to only allowed contracts.
 */
contract Helix is ERC20, AccessControl, Pausable {
    // Define the roles
    bytes32 public constant ADMIN_ROLE = keccak256("DEFAULT_ADMIN_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant BURNER_ROLE = keccak256("BURNER_ROLE");
    bytes32 public constant WHITELIST_MANAGER_ROLE = keccak256("WHITELIST_MANAGER_ROLE");

    // Flag to enable or disable unrestricted transfers
    bool public enableUnrestrictedTransfers;

    // Whitelist of allowed contracts
    mapping(address => bool) public allowedContracts;
    address[] public whitelistedContracts;

    // Events for role and whitelist changes
    event RoleChanged(address indexed addr, bytes32 role, bool enabled);
    event WhitelistChanged(address indexed contractAddress, bool allowed);

    /**
     * @dev Constructor that initializes the token and sets up the roles.
     * @param _name The name of the token.
     * @param _ticker The ticker symbol of the token.
     */
    constructor(string memory _name, string memory _ticker) ERC20(_name, _ticker) {
        enableUnrestrictedTransfers = false;
        _setupRole(ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(BURNER_ROLE, msg.sender);
        _setupRole(WHITELIST_MANAGER_ROLE, msg.sender);        
    }

    // Modifiers for checking roles
    modifier onlyAdmin() {
        require(hasRole(ADMIN_ROLE, msg.sender), "HelixToken: only admin");
        _;
    }

    modifier onlyMinter() {
        require(hasRole(MINTER_ROLE, msg.sender), "HelixToken: only minter");
        _;
    }

    modifier onlyBurner() {
        require(hasRole(BURNER_ROLE, msg.sender), "HelixToken: only burner");
        _;
    }

    modifier onlyWhitelistManager() {
        require(hasRole(WHITELIST_MANAGER_ROLE, msg.sender), "HelixToken: only whitelist manager");
        _;
    }

    /**
     * @dev Add or remove a contract from the whitelist.
     * @param contractAddress The address of the contract to be added/removed.
     * @param allowed Flag to indicate if the contract should be added (true) or removed (false).
     */
    function setAllowedContract(address contractAddress, bool allowed) public onlyWhitelistManager  {
        allowedContracts[contractAddress] = allowed;

        if (allowed) {
            whitelistedContracts.push(contractAddress);
        }

        emit WhitelistChanged(contractAddress, allowed);
    }

    /**
     * @dev Check if an address is a contract by examining its code size.
     * @param addr The address to check.
     * @return bool true if the address is a contract, false otherwise.
     */
    function isContract(address addr) internal view returns (bool) {
        uint256 size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }

    /**
     * @dev Check if a contract is whitelisted.
     * @param addr The address of the contract to check.
     * @return bool true if the contract is whitelisted, false otherwise.
     */
    function isWhitelistedContract(address addr) internal view returns (bool) {
        if (!isContract(addr)) {
            return false;
        }
        return allowedContracts[addr];
    }

    /**
     * @dev Override the _beforeTokenTransfer function from the ERC20 contract.
     * @param from The address sending the tokens.
     * @param to The address receiving the tokens.
     * @param amount The amount of tokens to transfer.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount) internal virtual override {
        // Allow minting and burning
        if (from == address(0) || to == address(0)) {
            super._beforeTokenTransfer(from, to, amount);
            return;
        }

        // Allow transfers initiated by whitelisted contracts on behalf of users or when unrestricted transfers are enabled
        if (isWhitelistedContract(msg.sender) || enableUnrestrictedTransfers) {
            super._beforeTokenTransfer(from, to, amount);
            return;
        }

        // Disallow all other transfers
        revert("HelixToken: direct transfers not allowed");
    }

    /**
     * @dev Expose mint and burn functions only to the corresponding roles.
     * @param to The address to mint tokens to.
     * @param amount The amount of tokens to mint.
     */
    function mint(address to, uint256 amount) public onlyMinter {
        _mint(to, amount);
    }

    /**
     * @dev Expose burn function only to the corresponding roles.
     * @param from The address from which tokens will be burned.
     * @param amount The amount of tokens to burn.
     */
    function burn(address from, uint256 amount) public onlyBurner {
        _burn(from, amount);
    }

    /**
     * @dev Toggle the enableUnrestrictedTransfers flag.
     * @param enabled The new state of the enableUnrestrictedTransfers flag.
     */
    function setEnableUnrestrictedTransfers(bool enabled) public onlyAdmin {
        enableUnrestrictedTransfers = enabled;
    }

    /**
     * @dev Add or remove a role from an address.
     * @param role The role identifier (keccak256 hash of the role name).
     * @param addr The address for which the role will be granted or revoked.
     * @param enabled Flag to indicate if the role should be granted (true) or revoked (false).
     */
    function setRole(bytes32 role, address addr, bool enabled) public onlyAdmin {
        if (enabled) {
            _grantRole(role, addr);
        } else {
            _revokeRole(role, addr);
        }
        emit RoleChanged(addr, role, enabled);
    }

    // Get the list of whitelisted contracts
    function getWhitelistedContracts() public view returns (address[] memory) {
        return whitelistedContracts;
    }

    // Override the pause and unpause functions to add the `onlyAdmin` modifier
    function pause() public onlyAdmin {
        _pause();
    }

    function unpause() public onlyAdmin {
        _unpause();
    }
}
/**
    This contract defines a custom ERC20 token named Helix, with additional features such as access control and whitelisting. The token is mintable and burnable, and direct transfers between non-whitelisted addresses are disallowed.

    The contract includes the following functions:

    constructor(): Initializes the token and sets up roles.
    setAllowedContract(): Adds or removes a contract from the whitelist.
    isContract(): Checks if an address is a contract.
    isWhitelistedContract(): Checks if a contract is whitelisted.
    _beforeTokenTransfer(): Overrides the ERC20 _beforeTokenTransfer function to enforce transfer restrictions.
    mint(): Exposes the mint function only to minters.
    burn(): Exposes the burn function only to burners.
    setEnableUnrestrictedTransfers(): Toggles the enableUnrestrictedTransfers flag.
    setRole(): Adds or removes a role from an address.

    The contract makes use of several modifiers to enforce role-based access control:

    onlyAdmin(): Ensures only users with the ADMIN_ROLE can call a function.
    onlyMinter(): Ensures only users with the MINTER_ROLE can call a function.
    onlyBurner(): Ensures only users with the BURNER_ROLE can call a function.
*/