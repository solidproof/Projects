// SPDX-License-Identifier: MIT

/*
───────────────────────────────────────────────────────────────────────────────────────────
─██████████████─████████████───██████████████─██████████████─██████──██████─██████████████─
─██░░░░░░░░░░██─██░░░░░░░░████─██░░░░░░░░░░██─██░░░░░░░░░░██─██░░██──██░░██─██░░░░░░░░░░██─
─██░░██████░░██─██░░████░░░░██─██░░██████░░██─██░░██████████─██░░██──██░░██─██░░██████████─
─██░░██──██░░██─██░░██──██░░██─██░░██──██░░██─██░░██─────────██░░██──██░░██─██░░██─────────
─██░░██████░░██─██░░██──██░░██─██░░██████░░██─██░░██████████─██░░██████░░██─██░░██████████─
─██░░░░░░░░░░██─██░░██──██░░██─██░░░░░░░░░░██─██░░░░░░░░░░██─██░░░░░░░░░░██─██░░░░░░░░░░██─
─██░░██████░░██─██░░██──██░░██─██░░██████░░██─██████████░░██─██░░██████░░██─██░░██████████─
─██░░██──██░░██─██░░██──██░░██─██░░██──██░░██─────────██░░██─██░░██──██░░██─██░░██─────────
─██░░██──██░░██─██░░████░░░░██─██░░██──██░░██─██████████░░██─██░░██──██░░██─██░░██████████─
─██░░██──██░░██─██░░░░░░░░████─██░░██──██░░██─██░░░░░░░░░░██─██░░██──██░░██─██░░░░░░░░░░██─
─██████──██████─████████████───██████──██████─██████████████─██████──██████─██████████████─
───────────────────────────────────────────────────────────────────────────────────────────
*/

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract Vester {
    using SafeERC20 for IERC20;

    struct Beneficiary {
        uint256 allocation;
        uint256 startTime;
        bool claimed;
    }

    mapping(address => Beneficiary) public beneficiaries;

    IERC20 public token;
    address public owner;

    uint256 public startTime;
    uint256 public duration;
    uint256 public noOfBeneficiaries;
    uint256 public vestingDuration = 365 days * 7; // 7 years

    event BeneficiaryAdded(address indexed beneficiary, uint256 allocation);
    event BeneficiaryRemoved(
        address indexed beneficiary,
        uint256 remainingAllocation
    );
    event TokensClaimed(address indexed beneficiary, uint256 amount);

    modifier onlyOwner() {
        require(msg.sender == owner, "Error: Not Owner!");
        _;
    }

    constructor(IERC20 token_, uint startTime_, uint duration_) {
        owner = msg.sender;
        token = token_;
        startTime = startTime_;
        duration = duration_;
    }

    function addBeneficiary(
        address beneficiary,
        uint256 allocation
    ) external onlyOwner {
        require(beneficiary != address(0), "Invalid beneficiary address");
        require(allocation > 0, "Allocation must be greater zero");
        require(
            beneficiaries[beneficiary].allocation == 0,
            "Beneficiary already exists"
        );

        beneficiaries[beneficiary] = Beneficiary({
            allocation: allocation,
            startTime: block.timestamp,
            claimed: false
        });
        noOfBeneficiaries++;

        emit BeneficiaryAdded(beneficiary, allocation);
    }

    function removeBeneficiary(address beneficiary) external onlyOwner {
        require(
            beneficiaries[beneficiary].allocation > 0,
            "Beneficiary does not exist"
        );

        uint256 remainingAllocation = beneficiaries[beneficiary].allocation;
        delete beneficiaries[beneficiary];
        noOfBeneficiaries--;

        emit BeneficiaryRemoved(beneficiary, remainingAllocation);
    }

    function claimTokens() external {
        Beneficiary storage beneficiary = beneficiaries[msg.sender];
        require(beneficiary.allocation > 0, "You are not a beneficiary");

        uint256 currentTime = block.timestamp;
        uint256 elapsedTime = currentTime - beneficiary.startTime;

        require(elapsedTime >= vestingDuration, "Vesting period not over yet");

        uint256 claimableTokens = (beneficiary.allocation * elapsedTime) /
            vestingDuration;

        require(claimableTokens > 0, "No tokens available for claim");

        beneficiary.allocation -= claimableTokens;
        token.transfer(msg.sender, claimableTokens);

        emit TokensClaimed(msg.sender, claimableTokens);
    }
}
