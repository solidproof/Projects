// SPDX-License-Identifier: MIT
pragma solidity ^0.8.4;

import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

import '@uniswap/v2-periphery/contracts/interfaces/IUniswapV2Router02.sol';
import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Factory.sol';

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/structs/EnumerableSet.sol";


import './interfaces/IAntiBotToken.sol';



contract WaveAntiBot is Initializable, PausableUpgradeable, OwnableUpgradeable, UUPSUpgradeable {
   using SafeMath for uint256;
   using EnumerableSet for EnumerableSet.AddressSet;



   struct AntiBotInfo {
       address owner;
       address pairToken;
       address pair;
       address routerExchange;
       address factoryExchange;
       uint256 amountLimitPerTrade;
       uint256 amountAddedPerLock;
       uint256 timeLimitPerTrade;
       uint256 totalLockBlocks;
       bool enabled;
   }

   struct AntiBotStatusInfo {
       bool enabled;
       uint256 balance;
       uint256 amountLimit;
       uint256 timeLimit;
       uint256 leftBlocks;
       uint256 currentBlock;
       bool funded;
   }

   struct TradeLogInfo {
       uint256 listingBlock;
       uint256 listingTime;
       uint256 lastTimeTrade;
   }

   address payable public fundAddress;
   uint256 public fundAmount;
   mapping(address => AntiBotInfo) public antiBotInfos;
   mapping(address => TradeLogInfo) public tradeLogInfos;
   mapping(address => EnumerableSet.AddressSet) private whitelistedUsers;
   mapping(address => EnumerableSet.AddressSet) private blacklistedUsers;
   mapping(address => bool) public antiBotFunds;


   /// @custom:oz-upgrades-unsafe-allow constructor
   constructor() {
       _disableInitializers();
   }

   function initialize(address payable _fundAddress, uint256 _fundAmount) initializer public {
       __Pausable_init();
       __Ownable_init();
       __UUPSUpgradeable_init();
       require(_fundAddress != address(0) && _fundAddress != address(this), 'invalid _fundAddress');
       require(_fundAmount > 0, 'invalid _fundAmount');
       fundAddress = _fundAddress;
       fundAmount = _fundAmount;
   }

   function setFundAddress(address payable _fundAddress) public onlyOwner {
       require(_fundAddress != address(0) && _fundAddress != address(this), 'invalid _fundAddress');
       require(fundAddress != _fundAddress, 'No need to update!');
       fundAddress = _fundAddress;
   }

   function setFundAmount(uint256 _fundAmount) public onlyOwner {
       require(_fundAmount > 0, 'invalid _fundAmount');
       require(fundAmount != _fundAmount, 'No need to update!');
       fundAmount = _fundAmount;
   }

   function setTokenOwner(address owner) external whenNotPaused {
       AntiBotInfo storage antiBotInfo = antiBotInfos[_msgSender()];
       antiBotInfo.owner = owner;
   }

   function configAntiBot(address token, address pairToken, address routerExchange, address factoryExchange, uint256 amountLimitPerTrade, uint256 amountAddedPerLock, uint256 timeLimitPerTrade, uint256 totalLockBlocks) external whenNotPaused {
       AntiBotInfo storage antiBotInfo = antiBotInfos[token];
       require(token != address(0), 'Invalid Token');
       require(antiBotInfo.owner == _msgSender(), 'Only Owner!');
       require(routerExchange != address(0), 'Invalid Router');
       require(factoryExchange != address(0), 'Invalid Factory');
       require(amountLimitPerTrade > 0, 'Invalid amountLimitPerTrade');
       require(amountAddedPerLock > 0, 'Invalid amountAddedPerLock');
       require(timeLimitPerTrade > 0, 'Invalid timeLimitPerTrade');
       require(totalLockBlocks > 0, 'Invalid totalLockBlocks');

       IUniswapV2Router02 routerObj = IUniswapV2Router02(routerExchange);
       IUniswapV2Factory factoryObj = IUniswapV2Factory(factoryExchange);

       address pair;
       if (pairToken == address(0)) {
           pair = factoryObj.getPair(token, routerObj.WETH());
           if (pair == address(0)) {
               pair = factoryObj.createPair(token, routerObj.WETH());
           }
       } else {
           pair = factoryObj.getPair(token, pairToken);
           if (pair == address(0)) {
               pair = factoryObj.createPair(token, pairToken);
           }
       }
       require(pair != address(0), 'Invalid Pair');

       uint256 balance = IERC20(token).balanceOf(pair);
       require(balance == 0, 'Can Not Config Now!');
       antiBotInfo.owner = _msgSender();
       antiBotInfo.pairToken = pairToken;
       antiBotInfo.pair = pair;
       antiBotInfo.routerExchange = routerExchange;
       antiBotInfo.factoryExchange = factoryExchange;
       antiBotInfo.amountLimitPerTrade = amountLimitPerTrade;
       antiBotInfo.amountAddedPerLock = amountAddedPerLock;
       antiBotInfo.timeLimitPerTrade = timeLimitPerTrade;
       antiBotInfo.totalLockBlocks = totalLockBlocks;
   }

   function enableAntiBot(address token, bool enabled) external payable whenNotPaused {
       require(token != address(0), 'Invalid Token');
       AntiBotInfo storage antiBotInfo = antiBotInfos[token];
       require(antiBotInfo.owner == _msgSender(), 'Not Owner!');
       require(antiBotInfo.enabled != enabled, 'Updated');
       require(antiBotInfo.pair != address(0), 'Not Config Yet!');
       if (!antiBotFunds[token]) {
           require(msg.value >= fundAmount, 'Insufficient Fee');
           antiBotFunds[token] = true;
       }
       if (enabled) {
           uint256 balance = IERC20(token).balanceOf(antiBotInfo.pair);
           require(balance == 0, 'Can Not Enable Now!');
       }
       antiBotInfo.enabled = enabled;
       if (msg.value > 0) {
           require(fundAddress != address(0), 'Can not Update Now!');
           payable(fundAddress).transfer(msg.value);
       }
   }


   function calculateMaxTrade(AntiBotInfo memory antiBotInfo, TradeLogInfo memory tradeLogInfo) internal view returns (uint256) {

       if (block.number < tradeLogInfo.listingBlock || tradeLogInfo.listingBlock == 0) {
           return antiBotInfo.amountLimitPerTrade;
       }
       uint256 blocks = block.number.sub(tradeLogInfo.listingBlock);
       uint256 result = antiBotInfo.amountLimitPerTrade.add(blocks.mul(antiBotInfo.amountAddedPerLock));
       return result;
   }

   function onPreTransferCheck(address sender, address recipient, uint256 amount) external whenNotPaused {
       AntiBotInfo memory antiBotInfo = antiBotInfos[_msgSender()];
       TradeLogInfo storage tradeLogInfo = tradeLogInfos[_msgSender()];
       if (!antiBotInfo.enabled) {
           return;
       } else {
           if (sender == antiBotInfo.pair || recipient == antiBotInfo.pair) {
               uint256 balance = 0;
               if (antiBotInfo.pair != address(0)) {
                   balance = IERC20(_msgSender()).balanceOf(antiBotInfo.pair);
               }

               if (tradeLogInfo.listingBlock == 0 && recipient == antiBotInfo.pair && balance == 0) {
                   tradeLogInfo.listingTime = block.timestamp;
                   tradeLogInfo.listingBlock = block.number;
                   tradeLogInfo.lastTimeTrade = block.timestamp;
                   return;
               }

               if (whitelistedUsers[_msgSender()].contains(sender) || whitelistedUsers[_msgSender()].contains(recipient)) {
                   return;
               }

               if (block.number > tradeLogInfo.listingBlock.add(antiBotInfo.totalLockBlocks)) {
                   return;
               }

               if (blacklistedUsers[_msgSender()].contains(sender) || blacklistedUsers[_msgSender()].contains(recipient)) {
                   revert('execute revert!');
               }

               uint256 maxTrade = calculateMaxTrade(antiBotInfo, tradeLogInfo);

               uint256 nextTimeTrade = tradeLogInfo.lastTimeTrade.add(antiBotInfo.timeLimitPerTrade);

               if (amount <= maxTrade && block.timestamp >= nextTimeTrade) {
                   tradeLogInfo.lastTimeTrade = block.timestamp;
                   return;
               } else {
                   revert('execute revert!!');
               }

           }
       }
   }

   function whitelistUsers(address token, bool status, address[] memory users) external whenNotPaused {
       require(users.length > 0, 'Invalid Input');
       require(token != address(0), 'Invalid Token');
       require(antiBotInfos[token].owner == _msgSender(), 'Not Owner');

       for (uint256 i = 0; i < users.length; i++) {
           require(users[i] != address(0), 'Invalid User');
           if (status) {
               whitelistedUsers[token].add(users[i]);
           } else {
               whitelistedUsers[token].remove(users[i]);
           }

       }
   }


   function blacklistUsers(address token, bool status, address[] memory users) external whenNotPaused {
       require(users.length > 0, 'Invalid Input');
       require(token != address(0), 'Invalid Token');
       require(antiBotInfos[token].owner == _msgSender(), 'Not Owner');


       for (uint256 i = 0; i < users.length; i++) {
           require(users[i] != address(0), 'Invalid User');
           if (status) {
               blacklistedUsers[token].add(users[i]);
           } else {
               blacklistedUsers[token].remove(users[i]);
           }

       }
   }

   function getTokenStatus(address token)
   external
   view
   returns (AntiBotStatusInfo memory)
   {
       AntiBotInfo memory antiBotInfo = antiBotInfos[token];
       TradeLogInfo memory tradeLogInfo = tradeLogInfos[token];
       uint256 balance = 0;
       if (antiBotInfo.pair != address(0)) {
           balance = IERC20(token).balanceOf(antiBotInfo.pair);
       }

       uint256 maxTrade = calculateMaxTrade(antiBotInfo, tradeLogInfo);
       uint256 leftBlock = 0;

       if (block.number < tradeLogInfo.listingBlock.add(antiBotInfo.totalLockBlocks) && tradeLogInfo.listingBlock > 0) {
           leftBlock = tradeLogInfo.listingBlock.add(antiBotInfo.totalLockBlocks).sub(block.number);
       }

       AntiBotStatusInfo memory result;
       result.enabled = antiBotInfo.enabled;
       result.balance = balance;
       result.amountLimit = maxTrade;
       result.timeLimit = antiBotInfo.timeLimitPerTrade;
       result.leftBlocks = leftBlock;
       result.currentBlock = block.number;
       result.funded = antiBotFunds[token];
       return result;
   }

   function getWhiteList(address token)
   external
   view
   returns (address[] memory)
   {
       uint256 length = whitelistedUsers[token].length();
       address [] memory result = new address[](length);
       for (uint256 i = 0; i < length; i++) {
           result[i] = whitelistedUsers[token].at(i);
       }
       return result;
   }

   function getBlackList(address token)
   external
   view
   returns (address[] memory)
   {
       uint256 length = blacklistedUsers[token].length();
       address [] memory result = new address[](length);
       for (uint256 i = 0; i < length; i++) {
           result[i] = blacklistedUsers[token].at(i);
       }
       return result;
   }

   //ex: [1,2,3,4] s=1,e=3 => [2,3]
   function getWhiteListPaging(
       address token,
       uint256 start,
       uint256 end
   ) public view returns (address[] memory) {
       uint256 totalUsers = whitelistedUsers[token].length();
       if (totalUsers == 0) {
           return new address[](0);
       }
       if (end > totalUsers) {
           end = totalUsers;
       }
       if (end < start) {
           return new address[](0);
       }

       uint256 length = end - start;
       address [] memory result = new address[](length);
       uint256 currentIndex = 0;
       for (uint256 i = start; i < end; i++) {
           result[currentIndex] = whitelistedUsers[token].at(i);
           currentIndex++;
       }
       return result;
   }

   function getBlackListPaging(
       address token,
       uint256 start,
       uint256 end
   ) public view returns (address[] memory) {
       uint256 totalUsers = blacklistedUsers[token].length();
       if (totalUsers == 0) {
           return new address[](0);
       }
       if (end > totalUsers) {
           end = totalUsers;
       }

       if (end < start) {
           return new address[](0);
       }
       uint256 length = end - start;
       address [] memory result = new address[](length);
       uint256 currentIndex = 0;
       for (uint256 i = start; i < end; i++) {
           result[currentIndex] = blacklistedUsers[token].at(i);
           currentIndex++;
       }
       return result;
   }

   function totalWhiteList(address token)
   external
   view
   returns (uint256)
   {
       return whitelistedUsers[token].length();
   }

   function totalBlackList(address token)
   external
   view
   returns (uint256)
   {
       return blacklistedUsers[token].length();
   }

   function _authorizeUpgrade(address newImplementation)
   internal
   onlyOwner
   override
   {}

   function pause() public onlyOwner {
       _pause();
   }

   function unpause() public onlyOwner {
       _unpause();
   }
}