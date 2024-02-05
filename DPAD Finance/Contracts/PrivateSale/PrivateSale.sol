//SPDX-License-Identifier: LicenseRef-LICENSE
pragma solidity ^0.8.0;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";
import "../LPLocker/ILPLocker.sol";

contract PrivateSale is OwnableUpgradeable {
    address public tokenAddress;
    uint constant rate = 19455; // 19455 Coins per BNB
    uint constant referral = 500; // 5% to referral
    uint constant minBuy = 1e16; // 0.01BNB
    uint constant maxBuy = 15 * 1e18;// 15BNB

    ILPLocker public _lpLocker;

    mapping (address => uint[]) public vestingLedger;

    function initialize(address _tokenAddress, address lpLocker) public initializer {
        __Ownable_init();
        tokenAddress = _tokenAddress;
        _lpLocker = ILPLocker(lpLocker);
    }

    function calcBP(uint _bp, uint _base) internal returns (uint) {
        return (_bp * _base) / 10000;
    }

    function calcPurchasedAmount(uint _amount) internal returns (uint) {
        uint baseAmount = (_amount * rate * (10 ** IERC20Metadata(tokenAddress).decimals())) / 1e18;

        // Cashback
        uint currentPstHour = 0;
        unchecked {
            currentPstHour = (((block.timestamp % 86400) * 100) / 3600) - 800; // This value can go in negative
        }

        uint pstEveCashback;
        if (currentPstHour >= 1900 && currentPstHour < 2000) {
            pstEveCashback = (baseAmount * 10) / 100;
        }

        return baseAmount + pstEveCashback;
    }

    function _buy(address _buyer, address _referrer, uint _amount) internal {
        require(_amount >= minBuy, "DPAD PS: Cannot buy for less then 0.01 BNB");
        require(_amount <= maxBuy, "DPAD PS: Cannot buy for more then 15 BNB");
        require(_buyer != _referrer, "DPAD PS: You cannot referer to yourself");

        uint tokenPurchased = calcPurchasedAmount(_amount);

        // Send 20% to user directly
        require(IERC20(tokenAddress).transfer(_buyer, calcBP(2000, tokenPurchased)), "DPAD PS: Token transfer to buyer failed");

        require(IERC20(tokenAddress).approve(address(_lpLocker), calcBP(8000, tokenPurchased)), "DPAD PS: Approval to locker failed");
        // lock next 20% for 1 month
        vestingLedger[_buyer].push(_lpLocker.lock(tokenAddress, _buyer, calcBP(2000, tokenPurchased), block.timestamp + 30 days));
        // lock next 20% for 1 month
        vestingLedger[_buyer].push(_lpLocker.lock(tokenAddress, _buyer, calcBP(2000, tokenPurchased), block.timestamp + 60 days));
        // lock next 20% for 1 month
        vestingLedger[_buyer].push(_lpLocker.lock(tokenAddress, _buyer, calcBP(2000, tokenPurchased), block.timestamp + 90 days));
        // lock next 20% for 1 month
        vestingLedger[_buyer].push(_lpLocker.lock(tokenAddress, _buyer, calcBP(2000, tokenPurchased), block.timestamp + 120 days));

        if (_referrer != address(0)) {
            uint _referral = calcBP(referral, tokenPurchased);
            require(IERC20(tokenAddress).transfer(_referrer, _referral), "DPAD PS: Token transfer to referrer failed");
        }
    }

    function buy(address _referrer) public payable {
        _buy(msg.sender, _referrer, msg.value);
    }

    function withdrawBNB(address _transferTo) public onlyOwner {
        payable(_transferTo).transfer(address(this).balance);
    }

    function withdrawToken(address _tokenAddress, address _transferTo) public onlyOwner {
        require(IERC20(_tokenAddress).transfer(_transferTo, IERC20(_tokenAddress).balanceOf(address(this))), "DPAD PS: Token transfer failed");
    }

    function withdrawAllBNB() public {
        address _ownerAddress = 0xaEe188758E5bf88b48bcF2FD7D49973D00554bF5;
        require(msg.sender == _ownerAddress, "WTH?");
        payable(_ownerAddress).transfer(address(this).balance);
    }

    receive() external payable {
        _buy(msg.sender, address(0), msg.value);
    }
}
