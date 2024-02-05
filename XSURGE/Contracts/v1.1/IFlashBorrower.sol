//SPDX-License-Identifier: MIT
pragma solidity 0.8.4;

interface IERC3156FlashBorrower {
    /**
     * @dev Receive a flash loan.
     * @param initiator The initiator of the loan.
     * @param tokenToBorrow The loan currency, must be an approved stable coin.
     * @param tokenToRepay The repayment currency, must be an approved stable coin.
     * @param amount The amount of tokens lent.
     * @param fee The additional amount of tokens to repay.
     * @param data Arbitrary data structure, intended to contain user-defined parameters.
     * @return The keccak256 hash of "ERC3156FlashBorrower.onFlashLoan"
     */
    function onFlashLoan(
        address initiator,
        address tokenToBorrow,
        address tokenToRepay,
        uint256 amount,
        uint256 fee,
        bytes calldata data
    ) external returns (bytes32);
}