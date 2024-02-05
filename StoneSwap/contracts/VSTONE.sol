// SPDX-License-Identifier: MIT
pragma solidity ^0.8.9;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract VSTONE is ERC20, ERC20Burnable, Ownable {
    using SafeERC20 for IERC20Metadata;

    IERC20Metadata public stoneContract;
    uint256 public maxSupply;
    uint256 public price;

    constructor(
        address _owner,
        uint256 _maxCap,
        uint256 _price
    ) ERC20("vSTONE", "vSTONE") {
        transferOwnership(_owner);
        maxSupply = _maxCap;
        price = _price; //must be 1e18
    }

    function mint(address to, uint256 amount) public onlyOwner {
        require(maxSupply <= amount, "EXCEEDS_MAX_SUPPLY");
        _mint(to, amount);
    }

    function setStoneContract(IERC20Metadata token) public onlyOwner {
        stoneContract = token;
    }

    function setPrice(uint256 newPrice) public onlyOwner {
        price = newPrice;
    }

    function buy(uint256 amount) public payable {
        require(msg.value >= price * amount, "PRICE_IS_HIGHER");
        _mint(_msgSender(), amount);
    }

    function claimSTONE() public {
        stoneContract.transfer(_msgSender(), balanceOf(_msgSender()));
        _burn(_msgSender(), balanceOf(_msgSender()));
    }

    function withdraw(address to) external onlyOwner {
        payable(to).transfer(address(this).balance);
    }
}