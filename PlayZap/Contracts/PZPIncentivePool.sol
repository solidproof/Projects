// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/Context.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract PZIncentivePool is Context, Ownable{

    event TokenTransferred(address _from, uint _amount);

    //transfer tokens to escrow
    function PZTokens (IERC20 token,address _to, uint256 amount) external onlyOwner
    {
        uint erc20balance = token.balanceOf(address(this));
        amount *= 10 ** decimals();
        require(amount <= erc20balance,"Balance in the contract is not enough");
        emit TokenTransferred(_to,amount);
        token.transfer(_to,amount);
    }

    function decimals() public view virtual returns (uint8) {
        return 18;
    }
}