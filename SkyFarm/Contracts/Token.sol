// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./ERC20.sol";
import "./Ownable.sol";

contract Token is ERC20, Ownable {

  mapping(address => bool) private liquidityPool;
  mapping(address => uint256) private lastTrade;

  uint8 private tradeCooldown;
  uint256 private taxAmount;

  address public taxPool;
  address public depositWallet;

  event changeLiquidityPoolStatus(address lpAddress, bool status);
  event changeTaxPool(address taxPool);

  constructor(string memory name, string memory symbol) ERC20(name, symbol) {
    _mint(msg.sender, 200000000 * 1 ether);
    tradeCooldown = 15;
  }

  function deposit(uint256 amount) public returns (bool)  {
    super._transfer(msg.sender, depositWallet, amount);
    emit Deposit(msg.sender, amount);
    return true;
  }

  function setLiquidityPoolStatus(address _lpAddress, bool _status) external onlyOwner {
    liquidityPool[_lpAddress] = _status;
    emit changeLiquidityPoolStatus(_lpAddress, _status);
  }

  function setTaxPool(address _taxPool) external onlyOwner {
    taxPool = _taxPool;
    emit changeTaxPool(_taxPool);
  }

  function updateDepositWallet(address newDepositWallet) external onlyOwner {
    depositWallet = newDepositWallet;
  }

  function _transfer(address sender, address receiver, uint256 amount) internal virtual override {
    if(liquidityPool[sender] == true) {
      //It's an LP Pair and it's a buy
      taxAmount = (amount * 0 ) / 100;
    } else if(liquidityPool[receiver] == true) {
      //It's an LP Pair and it's a sell
      taxAmount = (amount * 3 ) / 100;

      require(lastTrade[sender] < (block.timestamp - tradeCooldown), string("No consecutive sells allowed. Please wait."));
      lastTrade[sender] = block.timestamp;

    }
    if(taxAmount > 0) {
      super._transfer(sender, taxPool, taxAmount);
    }
    super._transfer(sender, receiver, amount - taxAmount);
  }

  function _beforeTokenTransfer(address _from, address _to, uint256 _amount) internal override {
    require(_to != address(this), string("No transfers to contract allowed."));
    super._beforeTokenTransfer(_from, _to, _amount);
  }

}