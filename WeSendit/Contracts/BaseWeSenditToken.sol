// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

import "./EmergencyGuard.sol";
import "./interfaces/IWeSenditToken.sol";

abstract contract BaseWeSenditToken is
    IWeSenditToken,
    EmergencyGuard,
    AccessControlEnumerable,
    Ownable
{
    // Initial token supply
    uint256 public constant INITIAL_SUPPLY = 37_500_000 ether;

    // Total token supply
    uint256 public constant TOTAL_SUPPLY = 1_500_000_000 ether;

    // Role allowed to do admin operations like adding to fee whitelist, withdraw, etc.
    bytes32 public constant ADMIN = keccak256("ADMIN");

    // Role allowed to bypass pause
    bytes32 public constant BYPASS_PAUSE = keccak256("BYPASS_PAUSE");

    // Indicator, if transactions are paused
    bool private _paused = true;

    // Dynamic Fee Manager instance
    IDynamicFeeManager private _dynamicFeeManager;

    constructor() {
        _setupRole(ADMIN, _msgSender());
        _setRoleAdmin(ADMIN, ADMIN);
        _setRoleAdmin(BYPASS_PAUSE, ADMIN);
    }

    /**
     * Getter & Setter
     */
    function initialSupply() external pure override returns (uint256) {
        return INITIAL_SUPPLY;
    }

    function unpause() external override onlyRole(ADMIN) {
        _paused = false;
        emit Unpaused();
    }

    function setDynamicFeeManager(address value)
        external
        override
        onlyRole(ADMIN)
    {
        _dynamicFeeManager = IDynamicFeeManager(value);
        emit DynamicFeeManagerUpdated(value);
    }

    function emergencyWithdraw(uint256 amount)
        external
        override
        onlyRole(ADMIN)
    {
        super._emergencyWithdraw(amount);
    }

    function emergencyWithdrawToken(address token, uint256 amount)
        external
        override
        onlyRole(ADMIN)
    {
        super._emergencyWithdrawToken(token, amount);
    }

    function paused() public view override returns (bool) {
        return _paused;
    }

    function dynamicFeeManager()
        public
        view
        override
        returns (IDynamicFeeManager manager)
    {
        return _dynamicFeeManager;
    }
}
