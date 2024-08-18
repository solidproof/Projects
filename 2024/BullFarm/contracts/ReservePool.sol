// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/ReentrancyGuard.sol";

interface ISwapPool {
    function swapUSDTForNative(uint256 usdtAmount, address recipient) external returns (uint256);
}

contract ReservePool is Ownable, ReentrancyGuard {

    using SafeERC20 for IERC20;
    uint256 public rewardPoolRate;
    address public usdtAddress;
    address public rewardAddress;
    address public swapPoolAddress;

    event TokensConverted(address indexed buyer, string referral, uint256 usdtAmount, uint256 coinAmount, uint8 farmType, uint8 level);
    event Withdrawal(address indexed owner, uint256 amount, address indexed to);
    event PayoutAddressChanged(address indexed oldAddress, address indexed newAddress);

    constructor(address _usdtAdress, address _rewardAddress, address _swapPoolAddress) Ownable(msg.sender){
        rewardPoolRate = 20;
        usdtAddress = _usdtAdress;
        rewardAddress = _rewardAddress;
        swapPoolAddress = _swapPoolAddress;
    }


    function stakeByUSDT(uint256 usdtAmount, string calldata referral, uint8 farmType, uint8 level) external {
        require(usdtAmount > 0, "Invalid amount");
        IERC20 usdtToken = IERC20(usdtAddress);
        // Transfer USDT from the sender to this contract
        require(usdtToken.transferFrom(msg.sender, address(this), usdtAmount), "USDT transfer failed");

        // Approve the SwapPool contract to spend the USDT
        require(usdtToken.approve(swapPoolAddress, usdtAmount), "USDT approve failed");

        ISwapPool swapPoolContract = ISwapPool(swapPoolAddress);

        uint256 coinAmount = swapPoolContract.swapUSDTForNative(usdtAmount, address(this));

        uint coinAmountToTransfer = coinAmount * rewardPoolRate / 100;
        (bool success,) = rewardAddress.call{value : coinAmountToTransfer}("");
        require(success, "Transfer failed");
        emit TokensConverted(msg.sender, referral, usdtAmount, coinAmount, farmType, level);
    }

    function withdrawUSDTTokens(address _recipient, uint256 _amount) external onlyOwner {
        IERC20 usdtToken = IERC20(usdtAddress);
        usdtToken.safeTransfer(_recipient, _amount);
    }

    function withdrawTo(uint256 amount, address to) external onlyOwner {
        require(amount > 0, "Amount must be greater than zero");
        require(to != address(0), "Invalid address");
        uint256 balance = address(this).balance;
        require(amount <= balance, "Insufficient balance");

        (bool success,) = to.call{value : amount}("");
        require(success, "Withdrawal failed");

        emit Withdrawal(msg.sender, amount, to);
    }

    function setRewardAddress(address _rewardAddress) external onlyOwner {
        require(_rewardAddress != address(0), "Invalid address");
        address oldAddress = rewardAddress;
        rewardAddress = _rewardAddress;
        emit PayoutAddressChanged(oldAddress, rewardAddress);
    }

    function setUsdtAddress(address _usdtAddress) external onlyOwner {
        require(_usdtAddress != address(0), "Invalid address");
        usdtAddress = _usdtAddress;

    }

    function setRewardPoolRate(uint256 _rewardPoolRate) external onlyOwner {
        require(_rewardPoolRate > 0 && _rewardPoolRate <= 100, "Invalid rate");
        rewardPoolRate = _rewardPoolRate;

    }

    receive() external payable {}
}