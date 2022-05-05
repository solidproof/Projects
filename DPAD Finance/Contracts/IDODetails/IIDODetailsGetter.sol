//SPDX-License-Identifier: LicenseRef-LICENSE
pragma solidity ^0.8.0;

import "./IDODetailsStorage.sol";
import "./../FundingManager/FundingTypes.sol";
import "./../IDOStates.sol";

interface IIDODetailsGetter {
    function idoId() external view returns (uint);

    function preSale() external view returns (address);

    function treasury() external view returns (address);

    function tokenAddress() external view returns (address);

    function ownerAddress() external view returns (address);

    function basicIdoDetails() external view returns (IDODetailsStorage.BasicIdoDetails memory);

    function votingDetails() external view returns (IDODetailsStorage.VotingDetails memory);

    function pcsListingDetails() external view returns (IDODetailsStorage.PCSListingDetails memory);

    function projectInformation() external view returns (IDODetailsStorage.ProjectInformation memory);

    function fundingType() external view returns (FundingTypes.FundingType);

    function state() external view returns (IDOStates.IDOState);

    function inHeadStartTill() external view returns (uint);

    function getTokensToBeSold() external view returns (uint);
}
