// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

import "./TRUSTT.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/utils/SafeERC20.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";


contract TokenSwap is Ownable {

    IERC20 public USDT;
    TRUSTT_Token public TRUSTT;
    address public contractAddress;

    constructor(
        address _USDT,
        address _TRUSTT
    ) {
        USDT = IERC20(_USDT);
        TRUSTT = TRUSTT_Token(_TRUSTT);
        contractAddress = (address(this));
    }

    using SafeERC20 for IERC20;

    function getTRUSTT(uint amountUSDT, address user) public {

        USDT.safeTransferFrom(user, contractAddress, amountUSDT);
        TRUSTT.mint(user, amountUSDT);

    }

    function sellTRUSTT(uint amountUSDT, address user) public {

        TRUSTT.approve(user, contractAddress, amountUSDT);
        TRUSTT.transferFrom(user, contractAddress, amountUSDT);
        TRUSTT.burn(contractAddress, amountUSDT);

        USDT.safeTransfer(user, amountUSDT);

    }

}