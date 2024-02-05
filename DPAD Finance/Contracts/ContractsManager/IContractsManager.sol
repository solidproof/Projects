//SPDX-License-Identifier: LicenseRef-LICENSE
pragma solidity ^0.8.0;

interface IContractsManager {
    function idoFactory() external view returns (address);

    function roleManager() external view returns (address);

    function votingManager() external view returns (address);

    function fundingManager() external view returns (address);

    function stakingManager() external view returns (address);

    function tokenAddress() external view returns (address);

    function developerAddress() external view returns (address);

    function pcsRouter() external view returns (address);

    function lpLocker() external view returns (address);

    function adminContract() external view returns (address);

    function busd() external view returns (address);

    function oneMonthContract() external view returns (address);

    function sixMonthsContract() external view returns (address);
}
