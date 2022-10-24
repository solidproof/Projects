// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

interface IFeeReceiver {
    /**
     * Callback function on ERC20 receive
     *
     * @param caller address - Calling contract
     * @param token address - Received ERC20 token address
     * @param from address - Sender address
     * @param to address - Receiver address
     * @param amount uint256 - Transaction amount
     */
    function onERC20Received(
        address caller,
        address token,
        address from,
        address to,
        uint256 amount
    ) external;
}
