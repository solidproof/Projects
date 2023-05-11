// SPDX-License-Identifier: MIT

pragma solidity ^0.8.15;

import "../interface/IERC20.sol";
import "../lib/SafeERC20.sol";

/// @title Base V1 Fees contract is used as a 1:1 pair relationship to split out fees,
///        this ensures that the curve does not need to be modified for LP shares
contract PairFees {
    using SafeERC20 for IERC20;

    /// @dev The pair it is bonded to
    address internal immutable pair;
    /// @dev Token0 of pair, saved localy and statically for gas optimization
    address internal immutable token0;
    /// @dev Token1 of pair, saved localy and statically for gas optimization
    address internal immutable token1;

    constructor(address _token0, address _token1) {
        pair = msg.sender;
        token0 = _token0;
        token1 = _token1;
    }

    // Allow the pair to transfer fees to users
    function claimFeesFor(
        address recipient,
        uint256 amount0,
        uint256 amount1
    ) external {
        require(msg.sender == pair, "Not pair");
        if (amount0 > 0) {
            IERC20(token0).safeTransfer(recipient, amount0);
        }
        if (amount1 > 0) {
            IERC20(token1).safeTransfer(recipient, amount1);
        }
    }
}
