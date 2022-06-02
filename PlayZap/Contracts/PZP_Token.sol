// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";


contract PZToken is ERC20, Ownable {
    using SafeMath for uint256;

    address public _ownerAddress;

    event TokenPurchased(address _from, uint _amount);

    constructor() ERC20("PLAYZAP", "PZP")
    {
        _ownerAddress = msg.sender;
    }

    function setOwnership(address newOwner) public onlyOwner {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
    }


    function mint(address dest_, uint256 amount_) external onlyOwner{
        _mint(dest_, amount_);
    }

    function transferERC20 (IERC20 token,address _to, uint256 amount) external onlyOwner
    {
        uint erc20balance = token.balanceOf(address(this));
        amount *= 10 ** 18;
        require(amount <= erc20balance,"Balance in the contract is not enough");
        emit TokenPurchased(_to,amount);
        token.transfer(_to,amount);
    }


    function burn(uint256 amount_) external {
        _burn(msg.sender, amount_);
    }

    function burnFrom(address from_, uint256 amount_) external {
        require(from_ != address(0), "burn from zero");

        _approve(from_, msg.sender, allowance(from_,msg.sender).sub(amount_));
        _burn(from_, amount_);
    }
}