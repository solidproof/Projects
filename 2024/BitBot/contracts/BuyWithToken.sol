// SPDX-License-Identifier: MIT
pragma solidity ^0.8.17;

import "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract BuyWithToken {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    constructor(address _feeClaimer, address _tokenAddress, address _adminAddress) {
        feeClaimer = _feeClaimer;
        tokenAddress = _tokenAddress;
        adminAddress = _adminAddress;
    }

    event Buy(address token, uint256 payAmount);

    address public immutable feeClaimer;
    address public immutable tokenAddress;
    address public immutable adminAddress;

    mapping(address => uint256) buyRecord;

    struct ClaimRecord {
        address user;
        uint256 amount;
    }

    function recoverRecords(ClaimRecord[] memory records) public {
        require(msg.sender == adminAddress, "Only admin can recover claim records");
        for (uint256 i = 0; i < records.length; i++) {
            buyRecord[records[i].user] = records[i].amount;
        }
    }

    function buyERC20(address erc20, uint256 payAmount) public {
        require(erc20 != address(0), "Invalid token address");
        require(payAmount > 0, "Invalid token amount");
        require(IERC20(erc20).allowance(msg.sender, address(this)) >= payAmount, "Insufficient allowance");
        require(IERC20(erc20).balanceOf(msg.sender) >= payAmount, "Insufficient balance");

        IERC20(erc20).safeTransferFrom(msg.sender, address(this), payAmount);

        emit Buy(erc20, payAmount);
    }

    function buyETH() public payable {
        emit Buy(address(0), msg.value);
    }

    function userClaimToken() public {
        require(buyRecord[msg.sender] > 0, "No token to claim");
        require(address(tokenAddress) != address(0), "Meme address not set");

        uint256 amount = buyRecord[msg.sender];
        IERC20 meme = IERC20(tokenAddress);
        meme.safeApprove(address(this), amount * (10 ** 18));
        meme.safeTransferFrom(address(this), msg.sender, amount * (10 ** 18));
        buyRecord[msg.sender] = 0;
    }

    function getPurchasedToken(address user) public view returns (uint256) {
        return buyRecord[user];
    }

    function adminWithdrawERC20(address[] memory tokenTypes, uint256 ethAmount) public {
        address target = feeClaimer;
        for (uint256 i = 0; i < tokenTypes.length; i++) {
            IERC20 token = IERC20(tokenTypes[i]);
            uint256 withdrawAmount = token.balanceOf(address(this));
            require(token.balanceOf(address(this)) >= withdrawAmount, "Insufficient ERC20 balance");
            token.safeApprove(address(this), withdrawAmount);
            token.safeTransferFrom(address(this), target, withdrawAmount);
        }

        address payable ethTarget = payable(feeClaimer);
        require(address(this).balance >= ethAmount, "Insufficient ETH balance");
        (bool success, ) = ethTarget.call{ value: ethAmount }("");
        require(success, "ETH transfer failed");
    }

    function adminWithdrawETH(uint256 amount) public {}

    receive() external payable {
        // Handle the received Ether
        emit Buy(address(0), msg.value);
    }
}