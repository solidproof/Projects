// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IManager {

    function markets(address _address) external view returns (bool);

    function farmOwners(address _address) external view returns (bool);

    function summoners(address _address) external view returns (bool);

    function battlefields(address _address) external view returns (bool);

    function timesBattle(uint256 level) external view returns (uint256);

    function totalHero(uint256 rare) external view returns (uint256);

    function timeLimitBattle() external view returns (uint256);

    function xBattle() external view returns (uint256);

    function priceSummon() external view returns (uint256);

    function feeSummoning() external view returns (uint256);

    function divPercent() external view returns (uint256);

    function loseRate() external view returns (uint256);

    function feeMarketRate() external view returns (uint256);

    function feeUpgradeGeneration() external view returns (uint256);

    function generation() external view returns (uint256);

    function feeAddress() external view returns (address);
}
