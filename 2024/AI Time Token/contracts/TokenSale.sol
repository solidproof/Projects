/**
 * @author - <Aureum-Technology.com>
 * SPDX-License-Identifier: Business Source License 1.1
 **/

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface IWhitelist {
    function isWhitelisted(address _address) external view returns (bool);
}

contract TokenSale is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    IERC20 public token;
    IERC20 public usdt;
    IWhitelist public whitelist;

    uint256 public price;
    uint256 public multiplier;
    address public reclaimAddress;
    address public legalAddress;

    mapping(address => uint256) public usdtSpent;
    mapping(address => uint256) public tokensReceived;

    constructor(
        address _initialOwner,
        address _token,
        address _usdt,
        uint256 _multiplier,
        uint256 _price,
        address _whitelist,
        address _reclaimAddress,
        address _legalAddress
    ) Ownable(_initialOwner) {
        token = IERC20(_token);
        usdt = IERC20(_usdt);
        whitelist = IWhitelist(_whitelist);
        multiplier = _multiplier;
        price = _price;
        reclaimAddress = _reclaimAddress;
        legalAddress = _legalAddress;
    }

    function buyTokens(uint256 _amount) public nonReentrant {
        require(
            whitelist.isWhitelisted(msg.sender),
            "Caller is not whitelisted"
        );
        require(_amount >= 1e6, "Amount must be greater");

        uint256 tokenAmount = (_amount * multiplier) / price;

        uint256 balance = token.balanceOf(address(this));
        require(balance >= tokenAmount, "Not enough tokens available");

        usdt.safeTransferFrom(msg.sender, legalAddress, _amount);
        token.safeTransfer(msg.sender, tokenAmount);

        usdtSpent[msg.sender] += _amount;
        tokensReceived[msg.sender] += tokenAmount;
    }

    function setMultiplier(uint256 _multiplier) public onlyOwner {
        require(_multiplier > 0, "Multiplier must be greater than 0");
        multiplier = _multiplier;
    }

    function setPrice(uint256 _newPrice) public onlyOwner {
        require(_newPrice > 0, "Price must be greater than 0");
        price = _newPrice;
    }

    function reclaimRemainingTokens() public onlyOwner {
        uint256 remainingTokens = token.balanceOf(address(this));
        token.safeTransfer(reclaimAddress, remainingTokens);
    }

    function setWhitelist(address _whitelist) public onlyOwner {
        whitelist = IWhitelist(_whitelist);
    }
}