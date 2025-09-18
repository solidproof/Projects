// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

/**
 * ==========================================================================================
 * BLOCKTHECHAIN: SMART CONTRACT RETALIATION ENGINE — BTCN TOKEN
 * ==========================================================================================
 * “We don’t trust. We verify. Then we strike.”
 *
 * $BTCN is the native token powering the BlockTheChain protocol — the first
 * Retaliation-as-a-Service (RaaS) engine to detect, verify, and publicly strike back
 * against malicious contracts using PoE-verified exploit modules.
 *
 * 🔹 Purpose:
 * - Funds execution of WarFace modules (strikes)
 * - Required for DAO-based trigger votes (future phase)
 * - Fuel for operator roles and bounty initiators
 *
 * 🔹 Security:
 * - Token is fixed supply, non-upgradeable, and not mintable
 * - Controlled via verified Gnosis Safe multisig
 * - Pausable (with permanent disable switch)
 * - No proxy, no delegate injection, no mintable functions
 *
 * 🔹 Compatibility:
 * - ERC20Burnable, ERC20Permit, ERC20Pausable (OpenZeppelin v4.9.x)
 * - Fully composable in DeFi, L2s, or custodial bridges
 *
 * 🔹 Audit Trail:
 * - Built on OpenZeppelin audited contracts (v4.9.3)
 * - Internal Audit: ✅ Q2 2025
 * - External Audit: ✅ Q3 2025
 * ==========================================================================================
 */

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @title BTCN Token for BlockTheChain
 * @notice ERC20 token with burn, permit, and pausability logic. Ownership via Gnosis Safe.
 */
contract BTCN is ERC20Pausable, ERC20Burnable, ERC20Permit, Ownable {
    /// @notice One-way switch to permanently disable pause
    bool public pauseDisabled = false;

    event PermanentUnpauseEnabled(address indexed by);
    event OwnershipRenouncedManually(address indexed previousOwner);
    event PausedByOwner(address indexed by);
    event UnpausedByOwner(address indexed by);

    /**
     * @notice Deploys the BTCN token and mints 100M to deployer.
     * @dev Ownership is transferred manually post-deploy to Gnosis Safe.
     */
    constructor()
        ERC20("BlockTheChain", "BTCN")
        ERC20Permit("BlockTheChain")
    {
        _mint(msg.sender, 100_000_000 * 1e18);
        _transferOwnership(msg.sender); // Safe transfer recommended post-deploy
    }

    // ==========================================================================================
    // PAUSING LOGIC
    // ==========================================================================================

    /**
     * @notice Allows owner to pause transfers (if not permanently disabled).
     */
    function pause() public onlyOwner {
        require(!pauseDisabled, "BTCN: Pause permanently disabled");
        _pause();
        emit PausedByOwner(msg.sender);
    }

    /**
     * @notice Allows owner to resume transfers.
     */
    function unpause() public onlyOwner {
        _unpause();
        emit UnpausedByOwner(msg.sender);
    }

    /**
     * @notice One-way kill switch to permanently disable all future pauses.
     */
    function disablePauseForever() external onlyOwner {
        require(!pauseDisabled, "BTCN: Pause already disabled");
        pauseDisabled = true;
        emit PermanentUnpauseEnabled(msg.sender);
    }

    // ==========================================================================================
    // BURN LOGIC
    // ==========================================================================================

    /**
     * @notice Burns caller's tokens (disabled when paused).
     */
    function burn(uint256 amount) public override {
        require(!paused(), "BTCN: Cannot burn while paused");
        super.burn(amount);
    }

    /**
     * @notice Burns tokens from another account using allowance (disabled when paused).
     */
    function burnFrom(address account, uint256 amount) public override {
        require(!paused(), "BTCN: Cannot burn while paused");
        super.burnFrom(account, amount);
    }

    // ==========================================================================================
    // RENOUNCE LOGIC
    // ==========================================================================================

    /**
     * @notice Allows Safe to renounce ownership intentionally.
     */
    function renounce() external onlyOwner {
        emit OwnershipRenouncedManually(owner());
        renounceOwnership();
    }

    // ==========================================================================================
    // REQUIRED TRANSFER HOOK FOR PAUSABLE SUPPORT
    // ==========================================================================================

    /**
     * @dev Overrides transfer hook to enforce pause on send/receive.
     */
    function _beforeTokenTransfer(address from, address to, uint256 amount)
        internal
        override(ERC20, ERC20Pausable)
    {
        super._beforeTokenTransfer(from, to, amount);
    }
}