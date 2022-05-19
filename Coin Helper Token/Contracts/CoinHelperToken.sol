// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/presets/ERC20PresetMinterPauser.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";

contract CoinHelperToken is  Context, ERC20PresetMinterPauser, Ownable, ReentrancyGuard{
    using SafeERC20 for IERC20;

    constructor() ERC20PresetMinterPauser("CoinHelperToken", "CHT") {
        mint(msg.sender, 900000000000000000000000000);
    }

    function recoverERC20(address tokenAddress, uint256 tokenAmount) external onlyOwner nonReentrant {
        IERC20(tokenAddress).safeTransfer(owner(), tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    event Recovered(address token, uint256 amount);

}
