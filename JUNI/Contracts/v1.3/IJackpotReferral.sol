// SPDX-License-Identifier: MIT

pragma solidity 0.8.16;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IJackpotReferral {
    function refer(
        address sender,
        address recipient,
        uint256 amount
    ) external;

    function claimRewardTicket() external;

    function awardTickets(address wallet, uint256 amount) external;
}
