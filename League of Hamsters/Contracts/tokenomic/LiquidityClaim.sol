// SPDX-License-Identifier: MIT

import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "../interfaces/IERC20MintableBurnable.sol";

pragma solidity ^0.8.6;

contract SeedLiquidityClaimer is ReentrancyGuard, AccessControl {
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");
    bytes32 public constant CLAIMER_ROLE = keccak256("CLAIMER_ROLE");

    address public seedAddress;

    uint256 immutable public supply;
    uint256 public claimed = 0; 

    event Claimed(address to, uint256 amount);

    constructor(address _seedAddress, uint256 _supply, address _claimer) {
        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, _msgSender());
        _setupRole(CLAIMER_ROLE, _claimer);
        _setRoleAdmin(CLAIMER_ROLE, ADMIN_ROLE);

        seedAddress = _seedAddress;
        supply = _supply;
    }

    function getAvaliable() public view returns(uint256 avaliable) {
        avaliable = supply - claimed;
    }

    function claim(uint256 _amount) external onlyRole(CLAIMER_ROLE) {
        require(_amount <= getAvaliable(), "Not enough unlocked tokens");
        claimed += _amount;
        IERC20MintableBurnable(seedAddress).mint(msg.sender, _amount);
        emit Claimed(msg.sender, _amount);
    }

    /// @notice transfer accidentally locked on contract ERC20 tokens
    function transferFromContract20(address _token, address _user, uint256 _amount) public {
        require(hasRole(ADMIN_ROLE, _msgSender()), "Caller is not admin");
        IERC20(_token).transfer(_user, _amount);
    }
}