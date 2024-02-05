// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.13;

import {IVaultFactory} from "../interfaces/IVaultFactory.sol";
import {IVault} from "../interfaces/IVault.sol";
import {Vault} from "../Vault.sol";

contract VaultFactory is IVaultFactory {

    mapping(address => address) private _getVault;

    address[] public allVaults;

    address owner;

    mapping(address => bool) private _isVault; // simplified check if its a vault, given that `stable` flag might not be available in peripherals
    
    modifier onlyOwner() {
        require(msg.sender == owner ,"onlyOwner");
        _;
    }
    constructor() {
       owner = msg.sender;
    }

    /// @inheritdoc IVaultFactory
    function allVaultsLength() external view returns (uint256) {
        return allVaults.length;
    }
  
    /// @inheritdoc IVaultFactory
    function getVault(address lsdToken) external view returns (address) {
        return _getVault[lsdToken];
    }

    /// @inheritdoc IVaultFactory
    function isVault(address vault) external view returns (bool) {
        return _isVault[vault];
    }

    function setGauge(address vault,address gauge) external onlyOwner {
        IVault(vault).setGauge(gauge);
     }

    /// @inheritdoc IVaultFactory
    function createVault(address lsdToken,address lsdRateOracle) external returns (address vault) {

        if (lsdToken == address(0)) revert ZeroAddress();

        if (_getVault[lsdToken] != address(0)) revert VaultAlreadyExists();

        bytes32 salt = keccak256(abi.encodePacked(lsdToken, lsdRateOracle));  

        vault = address(new Vault{salt:salt}());

        IVault(vault).initialize(lsdToken, lsdRateOracle);

        _getVault[lsdToken] = vault;
        allVaults.push(vault);
        _isVault[vault] =  true;
        emit VaultCreated(lsdToken, vault, allVaults.length);
    }

}
