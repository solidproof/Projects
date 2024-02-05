pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";

abstract contract Adminable is Ownable, AccessControl {

    address public admin;
    constructor(address _admin) {
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);

    }

    modifier onlyOwnerOrAdmin() {
        require(
            owner() == _msgSender() ||
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "Adminable: caller is not the owner or admin"
        );
        _;
    }

    modifier onlyAdmin() {
        require(
            hasRole(DEFAULT_ADMIN_ROLE, _msgSender()),
            "Adminable: caller is not the admin"
        );
        _;
    }

    function updateAdmin(address _admin) external onlyOwnerOrAdmin() {
        require(_admin != address(0), "Adminable: invalid admin address");
        _setupRole(DEFAULT_ADMIN_ROLE, _admin);

    }
}