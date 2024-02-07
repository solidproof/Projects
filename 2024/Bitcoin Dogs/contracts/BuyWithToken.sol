// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract BuyWithToken {
    using SafeERC20 for IERC20;

    constructor(address _feeClaimer) {
        feeClaimer = _feeClaimer;
    }

    event Buy(address token, uint256 payAmount);

    address public immutable feeClaimer;

    function buyWithERC20(address erc20, uint256 payAmount) public {
        require(payAmount > 0, "Invalid token amount");

        IERC20(erc20).safeTransferFrom(msg.sender, address(this), payAmount);

        emit Buy(erc20, payAmount);
    }

    function buyWithETH() public payable {
        emit Buy(address(0), msg.value);
    }

    function withdraw(address[] memory tokenTypes, uint256 ethAmount) public {
        address target = feeClaimer;
        for (uint256 i = 0; i < tokenTypes.length; i++) {
            IERC20 token = IERC20(tokenTypes[i]);
            uint256 withdrawAmount = token.balanceOf(address(this));
            token.safeApprove(address(this), withdrawAmount);
            token.safeTransferFrom(address(this), target, withdrawAmount);
        }

        address payable ethTarget = payable(feeClaimer);
        require(address(this).balance >= ethAmount, "Insufficient funds");
        (bool success, ) = ethTarget.call{ value: ethAmount }("");
        require(success, "failed");
    }

    receive() external payable {
        // Handle the received Ether
        emit Buy(address(0), msg.value);
    }
}