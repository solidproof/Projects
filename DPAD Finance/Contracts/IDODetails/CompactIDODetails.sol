//SPDX-License-Identifier: LicenseRef-LICENSE
pragma solidity ^0.8.0;

// For Frontend or caching backend use only

import "./IDODetailsStorage.sol";
import "./../FundingManager/FundingTypes.sol";
import "./../IDOStates.sol";
import "./IIDODetailsGetter.sol";

contract CompactIDODetails {
    function getIdoDetails(address _IDODetailContractAddress) public view returns (
        uint,
        address,
        address,
        IDODetailsStorage.BasicIdoDetails memory,
        IDODetailsStorage.VotingDetails memory,
        IDODetailsStorage.PCSListingDetails memory,
        IDODetailsStorage.ProjectInformation memory,
        FundingTypes.FundingType,
        IDOStates.IDOState
    ) {

        IIDODetailsGetter idoDetails = IIDODetailsGetter(_IDODetailContractAddress);

        return (
        idoDetails.idoId(),
        idoDetails.tokenAddress(),
        idoDetails.ownerAddress(),
        idoDetails.basicIdoDetails(),
        idoDetails.votingDetails(),
        idoDetails.pcsListingDetails(),
        idoDetails.projectInformation(),
        idoDetails.fundingType(),
        idoDetails.state()
        );
    }
}
