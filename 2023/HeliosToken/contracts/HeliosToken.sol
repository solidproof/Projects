// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Capped.sol";

contract HeliosToken is
    AccessControlEnumerable,
    ERC20Burnable,
    ERC20Pausable,
    ERC20Capped
{
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant PAUSER_ROLE = keccak256("PAUSER_ROLE");

    constructor(
        string memory name,
        string memory symbol
    ) ERC20(name, symbol) ERC20Capped(1_000_000_000 * 10 ** 18) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(MINTER_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
    }

    /**
     * @dev See {ERC20-_mint}.
     */
    function mint(address to, uint256 amount) public {
        require(
            hasRole(MINTER_ROLE, msg.sender),
            "Token: must have minter role to mint"
        );
        require(amount > 0, "mint: Invalid amount");
        _mint(to, amount);
    }

    /**
     * @dev Pauses all token transfers.
     *
     * See {ERC20Pausable} and {Pausable-_pause}.
     *
     * Requirements:
     *
     * - the caller must have the pauser role.
     */
    function pause() public {
        require(
            hasRole(PAUSER_ROLE, msg.sender),
            "Token: must have pauser role to pause"
        );
        _pause();
    }

    /**
     * @dev Unpauses all token transfers.
     *
     * See {ERC20Pausable} and {Pausable-_unpause}.
     *
     * Requirements:
     *
     * - the caller must have the pauser role.
     */
    function unpause() public {
        require(
            hasRole(PAUSER_ROLE, msg.sender),
            "Token: must have pauser role to unpause"
        );
        _unpause();
    }

    /**
     * @dev See {ERC20-_mint}.
     */
    function _mint(
        address account,
        uint256 amount
    ) internal override(ERC20, ERC20Capped) {
        ERC20Capped._mint(account, amount);
    }

    /**
     * @dev See {ERC20-_beforeTokenTransfer}.
     *
     * Requirements:
     *
     * - the contract must not be paused.
     */
    function _beforeTokenTransfer(
        address from,
        address to,
        uint256 amount
    ) internal override(ERC20, ERC20Pausable) {
        ERC20Pausable._beforeTokenTransfer(from, to, amount);
    }
}