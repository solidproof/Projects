// SPDX-License-Identifier: MIT
pragma solidity ^0.8.13;

interface IVault {

    event Deposit(address indexed user, uint256 amount,uint256 eqEth);

    event Withdraw(address indexed user, uint256 amount,uint256 eqLsd);

    event ClaimFees(address indexed user, uint256 amount);
    function initialize(address _lsdToken, address _lsdRateOracle) external;
    function setGauge(address _vaultGauge) external ;
    function lsdToken() external view returns (address );
    function claimFees() external returns (uint256);
    function deposit(uint256 amount) external;
    function withdraw(uint256 amount) external;

}
