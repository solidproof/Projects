//SPDX-License-Identifier: LicenseRef-LICENSE
pragma solidity ^0.8.0;

interface IFundingManager {
    function addForFunding(uint _idoId) external;
    function addForForceFunding(uint _idoId) external;
}
