// SPDX-License-Identifier: MIT
pragma solidity ^0.8.23;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/AccessControl.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract STABLE is ERC20, ERC20Burnable, AccessControl, ERC20Permit {
    bytes32 public constant MINTER_ROLE = keccak256("MINTER_ROLE");
    bytes32 public constant CONTROLLER_ROLE = keccak256("CONTROLLER_ROLE");

    mapping(address => uint256) public freeMintSupplyMinter;
    uint256 public freeMintSupplyTotal;

    event FreeMintSupplyAdded(address indexed _address, uint256 _supply);
    event FreeMintSupplySubtracted(address indexed _address, uint256 _supply);

    constructor(
        address _DEFAULT_ADMIN_ROLE,
        address _MINTER_ROLE,
        address _CONTROLLER_ROLE
    ) ERC20("STABLE", "STABLE") ERC20Permit("STABLE") {
        _grantRole(DEFAULT_ADMIN_ROLE, _DEFAULT_ADMIN_ROLE);
        _grantRole(MINTER_ROLE, _MINTER_ROLE);
        _grantRole(CONTROLLER_ROLE, _CONTROLLER_ROLE);
    }

    function mint(address _to, uint256 _amount) public onlyRole(MINTER_ROLE) {
        require(
            freeMintSupplyTotal >= _amount,
            "ERC20: no more supply (total)"
        );
        require(
            freeMintSupplyMinter[msg.sender] >= _amount,
            "ERC20: no more supply (minter)"
        );

        freeMintSupplyTotal -= _amount;
        freeMintSupplyMinter[msg.sender] -= _amount;

        _mint(_to, _amount);
    }

    function addFreeMintSupply(address _address, uint256 _supply)
        public
        onlyRole(CONTROLLER_ROLE)
    {
        freeMintSupplyTotal += _supply;
        freeMintSupplyMinter[_address] += _supply;
        emit FreeMintSupplyAdded(_address, _supply);
    }

    function subFreeMintSupply(address _address, uint256 _supply)
        public
        onlyRole(CONTROLLER_ROLE)
    {
        require(
            freeMintSupplyTotal >= _supply,
            "ERC20: insufficient total supply"
        );
        require(
            freeMintSupplyMinter[_address] >= _supply,
            "ERC20: insufficient minter supply"
        );

        freeMintSupplyTotal -= _supply;
        freeMintSupplyMinter[_address] -= _supply;
        emit FreeMintSupplySubtracted(_address, _supply);
    }
}