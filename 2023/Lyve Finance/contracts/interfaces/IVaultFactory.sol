// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IVaultFactory {

    error VaultAlreadyExists();

    error ZeroAddress();

    event VaultCreated(address indexed token, address indexed vault, uint256);

    /// @notice returns the number of vaults created from this factory
    function allVaultsLength() external view returns (uint256);

    /// @notice Is a valid vault created by this factory.
    /// @param .
    function isVault(address vault) external view returns (bool);

    /// @notice Return address of vault created by this factory
    /// @param token .
    function getVault(address token) external view returns (address);
 
    /// @param token .
    function createVault(address token,address _lsdRateOracle) external returns (address vault);

     /// setGauge .
    function setGauge(address vault,address gauge) external ;

   
}
