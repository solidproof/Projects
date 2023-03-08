// SPDX-License-Identifier: UNLICENSED
// © Copyright AutoDCA. All Rights Reserved
pragma solidity ^0.8.9;

// import "hardhat/console.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "./IFeeCollector.sol";

contract FeeCollector is
    IFeeCollector,
    Initializable,
    UUPSUpgradeable,
    OwnableUpgradeable
{
    struct UserWeight {
        address addr;
        uint256 weight;
    }

    /* sum of user weights */
    uint256 public totalWeight;

    /* user address to his weight map*/
    mapping(address => uint256) public userWeights;

    /* token address to user to claimed amount map*/
    mapping(address => mapping(address => uint256)) public tokensClaimedMap;

    /* token address to amount received*/
    mapping(address => uint256) public tokensReceivedMap;

    bool public isClaimingPaused;

    function _authorizeUpgrade(address) internal override onlyOwner {}

    function initialize(
        UserWeight[] memory users,
        address owner
    ) public initializer {
        uint256 sumaricWeight = 0;
        for (uint256 i = 0; i < users.length; i++) {
            sumaricWeight += users[i].weight;
            userWeights[users[i].addr] = users[i].weight;
        }
        totalWeight = sumaricWeight;
        require(totalWeight > 0, "Invalid user weights");

        isClaimingPaused = false;
        __Ownable_init();
        __UUPSUpgradeable_init();
        transferOwnership(owner);
    }

    function receiveNative() external payable {
        tokensReceivedMap[address(0)] += msg.value;
    }

    function receiveToken(address tokenAddress, uint256 amount) external {
        require(amount > 0, "No tokens to receive");
        ERC20(tokenAddress).transferFrom(msg.sender, address(this), amount);
        tokensReceivedMap[tokenAddress] += amount;
    }

    function claimNative() external {
        require(isClaimingPaused == false, "Claiming is currently paused");
        uint256 toClaim = getClaimableAmount(msg.sender, address(0));
        require(toClaim > 0, "Nothing to claim");
        tokensClaimedMap[address(0)][msg.sender] += toClaim;

        address payable to = payable(msg.sender);
        to.transfer(toClaim);
    }

    function claimToken(address tokenAddress) external {
        require(isClaimingPaused == false, "Claiming is currently paused");
        uint256 toClaim = getClaimableAmount(msg.sender, tokenAddress);
        require(toClaim > 0, "Nothing to claim");
        tokensClaimedMap[tokenAddress][msg.sender] += toClaim;

        ERC20(tokenAddress).transfer(msg.sender, toClaim);
    }

    function emergencyNativeWithdraw() external onlyOwner {
        uint256 amountToWithdraw = address(this).balance;
        require(amountToWithdraw > 0, "No tokens to withdraw");
        isClaimingPaused = true;
        address payable to = payable(msg.sender);
        to.transfer(amountToWithdraw);
    }

    function emergencyTokenWithdraw(address tokenAddress) external onlyOwner {
        uint256 amountToWithdraw = ERC20(tokenAddress).balanceOf(address(this));
        require(amountToWithdraw > 0, "No tokens to withdraw");
        isClaimingPaused = true;
        ERC20(tokenAddress).transfer(msg.sender, amountToWithdraw);
    }

    function setClaimingPaused(bool _paused) external onlyOwner {
        isClaimingPaused = _paused;
    }

    function getClaimableAmount(
        address accountToCheck,
        address tokenAddress
    ) public view returns (uint256) {
        uint256 userWeight = userWeights[accountToCheck];
        uint256 userAllowedAmount = (tokensReceivedMap[tokenAddress] *
            userWeight) / totalWeight;
        uint256 userClaimedAmount = tokensClaimedMap[tokenAddress][
            accountToCheck
        ];

        uint256 toClaim = userAllowedAmount - userClaimedAmount;
        return toClaim;
    }
}
