// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IERC20MintableBurnable.sol";

pragma solidity ^0.8.6;

contract SeedTeamClaimer is ReentrancyGuard, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant CLAIMER_ROLE = keccak256("CLAIMER_ROLE");

    address public seedAddress;

    uint256 public startDate;
    uint256 immutable public supplyTeam;
    uint256 immutable public supplyAdvisors;
    uint256 constant public vestingPeriod = 365 days;
    uint256 public claimedAdvisors = 0;
    uint256 public claimedTeam = 0;

    event ClaimedForAdvisors(address to, uint256 amount);
    event ClaimedForTeam(address to, uint256 amount);

    constructor(address _seedAddress, uint256 _startDate, uint256 _supplyTeam, uint256 _supplyAdvisors, address _claimer) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, _msgSender());
        _setupRole(CLAIMER_ROLE, _claimer);
        _setRoleAdmin(CLAIMER_ROLE, ADMIN_ROLE);

        seedAddress = _seedAddress;
        startDate = _startDate;
        supplyTeam = _supplyTeam;
        supplyAdvisors = _supplyAdvisors;
    }

    function getAvailableAdvisors() public view returns(uint256 avaliable) {
        if (block.timestamp < startDate) return 0;
        uint256 elapsed = block.timestamp - startDate;
        if (elapsed>=vestingPeriod) {
            avaliable = supplyAdvisors - claimedAdvisors;
        } else {
            avaliable = supplyAdvisors * elapsed / vestingPeriod - claimedAdvisors;
        }
    }

    function claimForAdvisors(uint256 _amount) external onlyRole(CLAIMER_ROLE) {
        require(_amount <= getAvailableAdvisors(), "Not enough unlocked tokens");
        claimedAdvisors += _amount;
        IERC20MintableBurnable(seedAddress).mint(msg.sender, _amount);
        emit ClaimedForAdvisors(msg.sender, _amount);
    }

    function getAvailableTeam() public view returns(uint256 avaliable) {
        if (block.timestamp <= startDate) return 0;
        uint256 elapsed = block.timestamp - startDate;
        if (elapsed>=vestingPeriod) {
            avaliable = supplyTeam - claimedTeam;
        } else {
            avaliable = supplyTeam * elapsed / vestingPeriod - claimedTeam;
        }
    }

    function claimForTeam(uint256 _amount) external onlyRole(CLAIMER_ROLE) {
        require(_amount <= getAvailableTeam(), "Not enough unlocked tokens");
        claimedTeam += _amount;
        IERC20MintableBurnable(seedAddress).mint(msg.sender, _amount);
        emit ClaimedForTeam(msg.sender, _amount);
    }
    
    /// @notice transfer accidentally locked on contract ERC20 tokens
    function transferFromContract20(address _token, address _user, uint256 _amount) public {
        require(hasRole(ADMIN_ROLE, _msgSender()), "Caller is not admin");
        IERC20(_token).transfer(_user, _amount);
    }
}