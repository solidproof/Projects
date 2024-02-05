// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "@openzeppelin/contracts/interfaces/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract DepositCollector {
    using SafeERC20 for IERC20;

    IERC20 public immutable TOKEN;
    address public immutable RECEIVER;

    event DepositReceived(address indexed user, address indexed receiver, uint256 amount);

    constructor(
        address _token,
        address _receiver
    ) {
        TOKEN = IERC20(_token);
        RECEIVER = _receiver;
    }

    function depositTo(uint256 amount, address user) external {
        TOKEN.safeTransferFrom(msg.sender, RECEIVER, amount);

        emit DepositReceived(user, RECEIVER, amount);
    }
}