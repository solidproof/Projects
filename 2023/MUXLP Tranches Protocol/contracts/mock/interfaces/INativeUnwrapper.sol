// SPDX-License-Identifier: GPL-2.0-or-later
pragma solidity 0.8.17;

interface INativeUnwrapper {
    function unwrap(address payable to, uint256 rawAmount) external;
}
