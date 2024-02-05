// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

/**
 * @dev The ERC20 `burn` extension function.
 */
interface IERC20Burn {
    /**
     * @notice Burn tokens.
     *
     * @dev [ERC20 extension] Burn tokens. Destroys `amount` tokens from caller's account forever,
     * reducing the total supply. Use with caution, as this cannot be reverted, and you should ensure
     * that some other smart contract guarantees you some benefit for burning tokens before you burn
     * them.
     *
     * By convention, burning is logged as a transfer to the zero address.
     *
     * @param amount The amount to burn.
     */
    function burn(uint256 amount) external;
}

