// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.0;

import "./ERC20.sol";
import "./Ownable.sol";

contract Token is ERC20, Ownable {

  mapping(address => bool) private isBlacklist;
  mapping(address => bool) private liquidityPool;
  mapping(address => bool) private whitelistTax;
  mapping(address => uint256) private lastTrade;

  uint8 private buyTax;
  uint8 private sellTax;
  uint8 private tradeCooldown;
  uint8 private transferTax;
  uint256 private limitTxForWallet =1000;
  uint256 private taxAmount;

  address private taxPool;
  address public playToEarnWallet;
  address public depositWallet;

  event changeBlacklist(address _wallet, bool status);
  event changeLiquidityPoolStatus(address lpAddress, bool status);
  event changeTaxPool(address taxPool);
  event changeWhitelistTax(address _address, bool status);

  constructor(string memory name, string memory symbol) ERC20(name, symbol) {
    _mint(msg.sender, 200000000 * 1 ether);
    sellTax = 3;
    buyTax = 0;
    transferTax = 0;
    tradeCooldown = 15;
  }

  function deposit(uint256 amount) public returns (bool)  {
    require(!isBlacklist[msg.sender],"User blacklisted");
    super._transfer(msg.sender, depositWallet, amount);
    emit Deposit(msg.sender, amount);
    return true;
  }

  function setBlacklist(address _wallet, bool _status) external onlyOwner {
    isBlacklist[_wallet]= _status;
    emit changeBlacklist(_wallet, _status);
  }

  function setLiquidityPoolStatus(address _lpAddress, bool _status) external onlyOwner {
    liquidityPool[_lpAddress] = _status;
    emit changeLiquidityPoolStatus(_lpAddress, _status);
  }

  function setTaxPool(address _taxPool) external onlyOwner {
    taxPool = _taxPool;
    emit changeTaxPool(_taxPool);
  }

  function setWhitelist(address _address, bool _status) external onlyOwner {
    whitelistTax[_address] = _status;
    emit changeWhitelistTax(_address, _status);
  }

  function updateDepositWallet(address newDepositWallet) external onlyOwner {
    depositWallet = newDepositWallet;
  }

  function updatePlayToEarnWallet(address newWallet) external onlyOwner {
    playToEarnWallet = newWallet;
  }

  function updatePlayToEarnWalletLimit(uint256 newLimitation) external onlyOwner {
    limitTxForWallet = newLimitation;
  }

  function _transfer(address sender, address receiver, uint256 amount) internal virtual override {
    if(sender==playToEarnWallet){
    require(amount<=limitTxForWallet);
    }

    require(!isBlacklist[sender],"User blacklisted");
    if(liquidityPool[sender] == true) {
      //It's an LP Pair and it's a buy
      taxAmount = (amount * buyTax) / 100;
    } else if(liquidityPool[receiver] == true) {
      //It's an LP Pair and it's a sell
      taxAmount = (amount * sellTax) / 100;

      require(lastTrade[sender] < (block.timestamp - tradeCooldown), string("No consecutive sells allowed. Please wait."));
      lastTrade[sender] = block.timestamp;

    } else if(whitelistTax[sender] || whitelistTax[receiver] || sender == taxPool || receiver == taxPool) {
      taxAmount = 0;
    } else {
      taxAmount = (amount * transferTax) / 100;
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