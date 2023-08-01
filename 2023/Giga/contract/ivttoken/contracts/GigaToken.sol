// SPDX-License-Identifier: AGPLv3
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Snapshot.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-ERC20Permit.sol";

/**
 * @dev This is a custom token contract for the "GigaToken". It includes functionalities such as
 * burnable tokens, token snapshots, access control, pausability and permit features.
 * The token also adds the ability to increase and decrease unlocked tokens for a specific address.
 * The increase and decrease of unlocked tokens is controlled by an account with the minter role.
 * Transfers are only allowed when the contract is not paused and if the sender has enough unlocked tokens.
 */
contract GigaToken is ERC20, ERC20Burnable, ERC20Snapshot, AccessControl, Pausable, ERC20Permit {
    bytes32 public constant SNAPSHOT_ROLE = keccak256("SNAPSHOT_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");

    address public constant ZERO_ADDRESS = address(0);
    address public owner;

    // Mapping of addresses to their unlocked token amount
    mapping (address => uint) public unlockedTokens;

    /**
     * @dev Sets the values for `name` and `symbol`, initializes the `decimals` with a default value of 18.
     * Grants the minter, pauser and snapshot roles to the deployer and sets them as owner.
     */
    constructor() ERC20("GigaToken", "GIGA") ERC20Permit("GigaToken") {
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(SNAPSHOT_ROLE, msg.sender);
        _grantRole(PAUSER_ROLE, msg.sender);
        _grantRole(MINTER_ROLE, msg.sender);
        owner = msg.sender;
    }

    /**
     * @dev Increase the amount of unlocked tokens for a given address.
     * Can only be called by an account with the minter role.
     * @param _recipient The address to increase the unlocked tokens for.
     * @param _amount The amount of tokens to unlock.
     */
    function increaseUnlockedTokens(address _recipient, uint _amount) public onlyRole(MINTER_ROLE) {
        return _increaseUnlockedTokens(_recipient, _amount);
    }

    /**
     * @dev Decrease the amount of unlocked tokens for a given address.
     * Can only be called by an account with the minter role.
     * @param _recipient The address to decrease the unlocked tokens for.
     * @param _amount The amount of tokens to lock.
     */
    function decreaseUnlockedTokens(address _recipient, uint _amount) public onlyRole(MINTER_ROLE) {
        return _decreaseUnlockedTokens(_recipient, _amount);
    }

    /**
     * @dev Increase the amount of unlocked tokens for a given address.
     * This is an internal function that is only callable from within this contract.
     * @param _from The address to increase the unlocked tokens for.
     * @param _amount The amount of tokens to unlock.
     */
    function _increaseUnlockedTokens(address _from, uint _amount) internal {
        require(_amount >= 0, "Amount must be greater than zero");
        require(_from != ZERO_ADDRESS, "From must be an valid address");
        unlockedTokens[_from] += _amount;
    }  

    /**
     * @dev Decrease the amount of unlocked tokens for a given address.
     * This is an internal function that is only callable from within this contract.
     * @param _from The address to decrease the unlocked tokens for.
     * @param _amount The amount of tokens to lock.
     */
    function _decreaseUnlockedTokens(address _from, uint _amount) internal {
        require(_amount > 0, "Amount must be greater than zero");
        require(_amount <= unlockedTokens[_from], "Amount must be less or equal than unlocked tokens");
        require(_from != ZERO_ADDRESS, "From must be an valid address");
        unlockedTokens[_from] -= _amount;
    }

    /**
     * @dev Hooks into the token transfer mechanism.
     * It decreases the sender's unlocked token amount if the transfer is not for minting or burning.
     * Also checks if the sender has enough unlocked tokens.
     * The transfer is also paused if the contract is in paused state.
     * @param _from Address sending the tokens.
     * @param _to Address receiving the tokens.
     * @param _amount Amount of tokens being transferred.
     */
    function _beforeTokenTransfer(address _from, address _to, uint256 _amount) internal whenNotPaused override(ERC20, ERC20Snapshot) {
        if (_from != ZERO_ADDRESS && _to != ZERO_ADDRESS) {
            require(_doesAddressHasEnoughUnlockedTokensToTransfer(_from, _amount), "Not enough unlocked tokens");
            _decreaseUnlockedTokens(_from, _amount);
        }
        super._beforeTokenTransfer(_from, _to, _amount);
    } 

    /**
     * @dev Creates a new snapshot ID.
     * Can only be called by an account with the snapshot role.
     */
    function snapshot() public onlyRole(SNAPSHOT_ROLE) {
        _snapshot();
    }

    /**
     * @dev Pauses all token transfers.
     * Can only be called by an account with the pauser role.
     */
    function pause() public onlyRole(PAUSER_ROLE) {
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     * Can only be called by an account with the pauser role.
     */
    function unpause() public onlyRole(PAUSER_ROLE) {
        _unpause();
    }

    /**
     * @dev Creates `amount` new tokens and assigns them to `account`, increasing
     * the total supply.
     * Can only be called by an account with the minter role.
     * @param _to Address to mint the tokens to.
     * @param _amount Amount of tokens to mint.
     */
    function mint(address _to, uint256 _amount) public onlyRole(MINTER_ROLE) {
        _mint(_to, _amount);
    }

    /**
     * @dev Checks if an address has enough unlocked tokens for a transfer.
     * @param _from Address to check the unlocked token amount from.
     * @param _amount Amount of tokens the address wants to transfer.
     * @return A boolean indicating if the address has enough unlocked tokens for a transfer.
     */
    function _doesAddressHasEnoughUnlockedTokensToTransfer(address _from, uint256 _amount) internal view returns (bool) {
        return _amount <= unlockedTokens[_from];
    }

    /**
     * @dev Returns the amount of unlocked tokens for a specific address.
     * @param _from The address to check the unlocked tokens for.
     * @return The amount of unlocked tokens.
     */
    function getUnlockedTokens(address _from) public view returns (uint) {
        return unlockedTokens[_from];
    }

}
