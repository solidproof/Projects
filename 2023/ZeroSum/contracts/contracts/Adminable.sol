// SPDX-License-Identifier: Unlicensed
// ZeroSum Contract

pragma solidity 0.8.7;
import {StorageSlot} from "@openzeppelin/contracts/utils/StorageSlot.sol";


contract Adminable {
// ++++++++++ Ownership ++++++++++
    bytes32 private constant _OWNER_SLOT = 0xa7b53796fd2d99cb1f5ae019b54f9e024446c3d12b483f733ccc62ed04eb126a; // keccak(eip1967.proxy.owner) - 1

    modifier onlyOwner() {
        require(_owner() == msg.sender, "Ownable: caller is not the owner");
        _;
    }

    function _owner() internal view returns(address) {
        return StorageSlot.getAddressSlot(_OWNER_SLOT).value;
    }

    function _setOwner(address newOwner) internal {
        StorageSlot.getAddressSlot(_OWNER_SLOT).value = newOwner;
    }

    function renounceOwnership() public onlyOwner returns(bool) {
        _transferOwnership(address(0));
        return true;
    }

    function transferOwnership(address newOwner) public onlyOwner returns(bool) {
        require(newOwner != address(0), "Ownable: new owner is the zero address");
        _transferOwnership(newOwner);
        return true;
    }

    function _transferOwnership(address newOwner) internal {
        address oldOwner = _owner();
        _setOwner(newOwner);
        emit OwnershipTransferred(oldOwner, newOwner);
    }
// ++++++++++ Admin ++++++++++
    //mapping(address => AdminRole) _roles;
    bytes32 private constant _ROLES_SLOT = 0x6cb779a907037f6acf91ca2da28c998ae8930943bd410a1ed6a1f6f0bf98b65d; // keccak(eip1967.proxy.roles) - 1

    enum AdminRole {
        None,
        Backend,
        Developer,
        Owner
    }

    modifier onlyAdmin(AdminRole requiredRole) {
        require(requiredRole == getRole(msg.sender) || getRole(msg.sender) == AdminRole.Owner, "Adminable: caller is not an admin");
        _;
    }

    modifier onlyAdminHierarchy(AdminRole requiredRole) {
        require(uint256(getRole(msg.sender)) >= uint256(requiredRole), "Adminable: caller is not an admin");
        _;
    }

    function approveAdmin(address admin, AdminRole role) public onlyAdminHierarchy(role) returns(bool){
        require(role != AdminRole.Owner, "Owner role can not be granted to admin");
        _setRole(admin, role);
        emit AdminApproved(msg.sender, admin, role);
        return true;
    }

    function getRole(address sender) public view returns(AdminRole) {
        if(sender == _owner()) return AdminRole.Owner;
        bytes32 dataSlot = keccak256(abi.encodePacked(sender, _ROLES_SLOT));
        return AdminRole(uint8(StorageSlot.getUint256Slot(dataSlot).value));
    }

    function _setRole(address to, AdminRole newRole) internal {
        bytes32 dataSlot = keccak256(abi.encodePacked(to, _ROLES_SLOT));
        StorageSlot.getUint256Slot(dataSlot).value = uint8(newRole);
    }
// ++++++++++ Events ++++++++++
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    event AdminApproved(address approver, address indexed admin, AdminRole role);
}
